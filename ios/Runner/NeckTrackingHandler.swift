// Seguimiento del cuello para collares en iOS, con MediaPipe Tasks.
//
// Puerto de `android/.../NeckTracker.kt`, con el mismo protocolo de canal
// (`jewelry_ar/neck`): `start`, `process` y `stop`, y la misma respuesta.
// **No se ha probado en un iPhone.** Hasta validarlo, Dart no lo usa
// (`iosNeckTrackerEnabled` en `detection_runner.dart`). Lo que hay que
// verificar está en `docs/IOS_SEGUIMIENTO_CUELLO.md`.
//
// - Face Landmarker en CPU, en cada frame: mentón y ancho de cara.
// - Segmentación multiclase en GPU, a su ritmo: dónde el cuello toca la ropa a
//   cada lado, el centro del escote y el de la columna.
// - En tubería: `process` deja el frame y responde enseguida con el último
//   resultado; una cola procesa siempre el frame más reciente.
//
// Diferencia con Android: aquí el frame llega ya vertical y espejado como la
// vista previa (BGRA), así que no se rota y Dart no lo espeja.

import Flutter
import CoreVideo
import MediaPipeTasksVision

class NeckTrackingHandler: NSObject {
  // Índices de la malla facial: mentón, mejillas, nariz.
  private static let facePoints = [152, 234, 454, 1]
  private static let neckMaxAge: TimeInterval = 1.5
  private static let resultMaxAge: TimeInterval = 0.5

  private struct Frame {
    let pixelBuffer: CVPixelBuffer
  }

  private let faceQueue = DispatchQueue(label: "jewelry_ar.neck.face", qos: .userInitiated)
  private let segQueue = DispatchQueue(label: "jewelry_ar.neck.seg", qos: .utility)

  // Solo en `faceQueue`.
  private var face: FaceLandmarker?
  private var lastTimestamp = 0
  // Solo en `segQueue`.
  private var segmenter: ImageSegmenter?

  // Estado compartido entre colas: siempre bajo `lock`.
  private let lock = NSLock()
  private var active = false
  private var pending: Frame?
  private var faceBusy = false
  private var segBusy = false
  private var latest: [String: Any]?
  private var latestAt: TimeInterval = 0
  private var seq = 0
  private var neck: [String: Any]?
  private var neckAt: TimeInterval = 0
  private var accepted: [Double]?
  private var candidate: [Double]?

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    let channel = FlutterMethodChannel(name: "jewelry_ar/neck", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    // Precarga: el segmentador en GPU tarda en arrancar la primera vez.
    faceQueue.async { [weak self] in _ = self?.ensureFace() }
    segQueue.async { [weak self] in _ = self?.ensureSegmenter() }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      lock.lock()
      active = true
      neck = nil
      latest = nil
      accepted = nil
      candidate = nil
      lock.unlock()
      result(nil)
    case "process":
      guard
        let args = call.arguments as? [String: Any],
        let data = args["bytes"] as? FlutterStandardTypedData,
        let width = args["width"] as? Int,
        let height = args["height"] as? Int,
        let stride = args["stride"] as? Int,
        let pb = Self.makePixelBuffer(data: data.data, width: width, height: height, stride: stride)
      else {
        result(nil)
        return
      }
      lock.lock()
      pending = Frame(pixelBuffer: pb)
      let lanzar = !faceBusy
      if lanzar { faceBusy = true }
      let out = latest
      let fresco = CACurrentMediaTime() - latestAt < Self.resultMaxAge
      lock.unlock()
      if lanzar { faceQueue.async { [weak self] in self?.drain() } }
      result(fresco ? out : nil)
    case "stop":
      // Los modelos se quedan cargados para la próxima entrada.
      lock.lock()
      active = false
      neck = nil
      latest = nil
      pending = nil
      lock.unlock()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Modelos

  private static func modelPath(_ name: String) -> String? {
    let key = FlutterDartProject.lookupKey(forAsset: "assets/mediapipe/\(name)")
    return Bundle.main.path(forResource: key, ofType: nil)
  }

  private func ensureFace() -> FaceLandmarker? {
    if let face = face { return face }
    guard let path = Self.modelPath("face_landmarker.task") else {
      NSLog("NeckTracking: no se encontró face_landmarker.task en el bundle")
      return nil
    }
    let options = FaceLandmarkerOptions()
    options.baseOptions.modelAssetPath = path
    options.baseOptions.delegate = .CPU
    options.runningMode = .video
    options.numFaces = 1
    face = try? FaceLandmarker(options: options)
    if face == nil { NSLog("NeckTracking: no se pudo crear el Face Landmarker") }
    return face
  }

  private func ensureSegmenter() -> ImageSegmenter? {
    if let segmenter = segmenter { return segmenter }
    guard let path = Self.modelPath("selfie_multiclass_256x256.tflite") else {
      NSLog("NeckTracking: no se encontró el modelo de segmentación en el bundle")
      return nil
    }
    for delegate in [Delegate.GPU, Delegate.CPU] {
      let options = ImageSegmenterOptions()
      options.baseOptions.modelAssetPath = path
      options.baseOptions.delegate = delegate
      options.runningMode = .image
      options.shouldOutputCategoryMask = true
      options.shouldOutputConfidenceMasks = false
      if let s = try? ImageSegmenter(options: options) {
        NSLog("NeckTracking: segmentador listo con delegado \(delegate == .GPU ? "GPU" : "CPU")")
        segmenter = s
        return s
      }
    }
    return nil
  }

  // MARK: - Cara (faceQueue)

  private func drain() {
    while true {
      lock.lock()
      let frame = pending
      pending = nil
      if frame == nil { faceBusy = false }
      let sigue = active
      lock.unlock()
      guard let f = frame else { return }
      guard sigue, let out = process(f) else { continue }
      lock.lock()
      if active {
        seq += 1
        var conSeq = out
        conSeq["seq"] = seq
        latest = conSeq
        latestAt = CACurrentMediaTime()
      }
      lock.unlock()
    }
  }

  private func process(_ frame: Frame) -> [String: Any]? {
    guard let landmarker = ensureFace(), let image = try? MPImage(pixelBuffer: frame.pixelBuffer)
    else { return nil }
    var ts = Int(CACurrentMediaTime() * 1000)
    if ts <= lastTimestamp { ts = lastTimestamp + 1 }
    lastTimestamp = ts
    guard
      let result = try? landmarker.detect(videoFrame: image, timestampInMilliseconds: ts),
      let lms = result.faceLandmarks.first, lms.count > 454
    else { return ["face": false] }

    var points: [Double] = []
    for i in Self.facePoints {
      points += [Double(lms[i].x), Double(lms[i].y), Double(lms[i].z)]
    }
    let w = Double(CVPixelBufferGetWidth(frame.pixelBuffer))
    let h = Double(CVPixelBufferGetHeight(frame.pixelBuffer))
    let faceWidth = Self.faceWidth(points, aspect: h / w)

    lock.lock()
    let lanzar = !segBusy
    if lanzar { segBusy = true }
    lock.unlock()
    if lanzar {
      let chinX = points[0], chinY = points[1]
      segQueue.async { [weak self] in
        self?.measureNeck(image: image, chinX: chinX, chinY: chinY, faceWidth: faceWidth)
        self?.lock.lock()
        self?.segBusy = false
        self?.lock.unlock()
      }
    }

    var out: [String: Any] = ["face": true, "points": points, "faceWidth": faceWidth]
    lock.lock()
    if let n = neck, CACurrentMediaTime() - neckAt < Self.neckMaxAge { out["neck"] = n }
    lock.unlock()
    return out
  }

  /// Ancho de mejilla a mejilla en 3D, en fracciones del ancho del frame.
  private static func faceWidth(_ p: [Double], aspect: Double) -> Double {
    let dx = p[6] - p[3], dy = (p[7] - p[4]) * aspect, dz = p[8] - p[5]
    return (dx * dx + dy * dy + dz * dz).squareRoot()
  }

  // MARK: - Cuello (segQueue)

  private func measureNeck(image: MPImage, chinX: Double, chinY: Double, faceWidth: Double) {
    guard
      let seg = ensureSegmenter(),
      let result = try? seg.segment(image: image),
      let mask = result.categoryMask
    else { return }
    let mw = mask.width, mh = mask.height
    let values = Array(UnsafeBufferPointer(start: mask.uint8Data, count: mw * mh))
    guard
      let m = NeckMeasure.measure(
        values, w: mw, h: mh,
        chinX: chinX * Double(mw), chinY: chinY * Double(mh), faceWidth: faceWidth * Double(mw))
    else { return }

    lock.lock()
    defer { lock.unlock() }
    guard active, confirm(m, mw: mw, mh: mh, chinX: chinX, chinY: chinY, faceWidth: faceWidth)
    else { return }
    var n = m.toMap(w: mw, h: mh)
    n["refChinX"] = chinX
    n["refChinY"] = chinY
    n["refFaceWidth"] = faceWidth
    neck = n
    neckAt = CACurrentMediaTime()
  }

  /// Igual que en Android: un salto suelto de la segmentación solo se acepta
  /// si la medida siguiente lo confirma. Se llama con `lock` tomado.
  private func confirm(
    _ m: NeckMeasure.Result, mw: Int, mh: Int, chinX: Double, chinY: Double, faceWidth: Double
  ) -> Bool {
    guard faceWidth > 0 else { return false }
    let aspect = Double(mh) / Double(mw)
    let rel = [
      ((m.leftX + m.rightX) / 2 / Double(mw) - chinX) / faceWidth,
      ((m.leftY + m.rightY) / 2 / Double(mh) - chinY) * aspect / faceWidth,
      (m.rightX - m.leftX) / Double(mw) / faceWidth,
    ]
    func near(_ a: [Double], _ b: [Double]) -> Bool {
      abs(a[0] - b[0]) < 0.15 && abs(a[1] - b[1]) < 0.15 && abs(a[2] - b[2]) < 0.2 * b[2]
    }
    let fresh = CACurrentMediaTime() - neckAt < Self.neckMaxAge
    if accepted == nil || !fresh || near(rel, accepted!) {
      accepted = rel
      candidate = nil
      return true
    }
    if let c = candidate, near(rel, c) {
      accepted = rel
      candidate = nil
      return true
    }
    candidate = rel
    return false
  }

  // MARK: - Imagen

  /// Copia el frame BGRA de la cámara a un `CVPixelBuffer`, fila por fila: el
  /// relleno de cada fila puede no coincidir entre el origen y el destino.
  private static func makePixelBuffer(data: Data, width: Int, height: Int, stride: Int)
    -> CVPixelBuffer?
  {
    var pixelBuffer: CVPixelBuffer?
    let attrs = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ] as CFDictionary
    guard
      CVPixelBufferCreate(
        kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        == kCVReturnSuccess,
      let pb = pixelBuffer
    else { return nil }

    CVPixelBufferLockBaseAddress(pb, [])
    defer { CVPixelBufferUnlockBaseAddress(pb, []) }
    guard let dest = CVPixelBufferGetBaseAddress(pb) else { return nil }
    let destStride = CVPixelBufferGetBytesPerRow(pb)
    let rowBytes = min(width * 4, stride, destStride)
    data.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
      guard let base = src.baseAddress else { return }
      for y in 0..<height where (y + 1) * stride <= data.count {
        memcpy(dest + y * destStride, base + y * stride, rowBytes)
      }
    }
    return pb
  }
}

/// Forma del cuello sobre la máscara de segmentación. Mismo algoritmo que
/// `NeckMeasure` en Android: se baja desde el mentón siguiendo la franja de piel
/// del cuerpo; de cada lado interesa dónde el borde toca la ropa, y la franja
/// acaba en el escote.
enum NeckMeasure {
  // Valores de la máscara medidos en Android (2026-11-05): la clase del modelo
  // menos uno, con el fondo en 255. **Verificar en iOS** (ver el documento).
  static let bodySkin: UInt8 = 1
  static let clothes: UInt8 = 3

  struct Result {
    let leftX: Double, leftY: Double, rightX: Double, rightY: Double
    let hasFront: Bool, frontX: Double, frontY: Double
    let narrow: Double, columnX: Double

    func toMap(w: Int, h: Int) -> [String: Any] {
      let fw = Double(w), fh = Double(h)
      return [
        "leftX": leftX / fw, "leftY": leftY / fh,
        "rightX": rightX / fw, "rightY": rightY / fh,
        "hasFront": hasFront,
        "frontX": frontX / fw, "frontY": frontY / fh,
        "narrow": narrow / fw,
        "columnX": columnX < 0 ? -1.0 : columnX / fw,
      ]
    }
  }

  static func measure(
    _ m: [UInt8], w: Int, h: Int, chinX: Double, chinY: Double, faceWidth: Double
  ) -> Result? {
    guard faceWidth > 2 else { return nil }
    func at(_ x: Int, _ y: Int) -> UInt8 { m[y * w + x] }

    let reach = max(2, Int(0.35 * faceWidth))
    let minRun = 0.2 * faceWidth
    let yStart = min(max(Int(chinY - 0.05 * faceWidth), 0), h - 1)
    let yEnd = min(max(Int(chinY + 1.6 * faceWidth), 0), h - 1)

    var ys: [Int] = [], ls: [Int] = [], rs: [Int] = []
    var leftKind: [Int] = [], rightKind: [Int] = []
    var seed = min(max(Int(chinX), 0), w - 1)
    var started = false
    var endedOnClothes = false

    if yStart <= yEnd {
      for y in yStart...yEnd {
        var x0 = -1
        for d in 0...reach {
          if seed - d >= 0 && at(seed - d, y) == bodySkin { x0 = seed - d; break }
          if seed + d < w && at(seed + d, y) == bodySkin { x0 = seed + d; break }
        }
        if x0 < 0 {
          if !started { continue }
          endedOnClothes = at(seed, y) == clothes
          break
        }
        var l = x0
        while l > 0 && at(l - 1, y) == bodySkin { l -= 1 }
        var r = x0
        while r < w - 1 && at(r + 1, y) == bodySkin { r += 1 }
        if !started && Double(r - l + 1) < minRun { continue }
        started = true
        ys.append(y); ls.append(l); rs.append(r)
        leftKind.append(l > 0 ? Int(at(l - 1, y)) : -1)
        rightKind.append(r < w - 1 ? Int(at(r + 1, y)) : -1)
        seed = (l + r) / 2
      }
    }
    guard ys.count >= 3 else { return nil }

    let flare = 0.12 * faceWidth
    func sideBase(_ kinds: [Int], _ edges: [Int], outward: Int) -> Int {
      if let i = kinds.firstIndex(of: Int(clothes)) { return i }
      let first = Array(edges.prefix(3)).sorted()
      let ref = first[min(1, first.count - 1)]
      for i in edges.indices where Double((edges[i] - ref) * outward) > flare { return i }
      return edges.count - 1
    }
    let il = sideBase(leftKind, ls, outward: -1)
    let ir = sideBase(rightKind, rs, outward: 1)

    let upper = min(il, ir)
    let cleanRows = (0..<upper).filter {
      leftKind[$0] != Int(clothes) && rightKind[$0] != Int(clothes)
    }
    let widths = cleanRows.map { rs[$0] - ls[$0] + 1 }.sorted()
    let narrow = widths.count >= 2 ? Double(widths[widths.count / 2]) : 0
    let centers = cleanRows.map { Double(ls[$0] + rs[$0] + 1) / 2 }.sorted()
    let columnX = centers.count >= 2 ? centers[centers.count / 2] : -1

    let baseWidth = Double(rs[ir] - ls[il] + 1)
    guard baseWidth >= 0.35 * faceWidth, baseWidth <= 1.4 * faceWidth else { return nil }

    let last = ys.count - 1
    return Result(
      leftX: Double(ls[il]), leftY: Double(ys[il]),
      rightX: Double(rs[ir] + 1), rightY: Double(ys[ir]),
      hasFront: endedOnClothes,
      frontX: Double(ls[last] + rs[last] + 1) / 2, frontY: Double(ys[last]),
      narrow: narrow, columnX: columnX)
  }
}
