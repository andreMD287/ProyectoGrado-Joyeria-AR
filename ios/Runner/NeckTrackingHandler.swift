// Spike: collares en iOS con Apple Vision en vez de MediaPipe.
//
// MediaPipe (malla facial + segmentacion multiclase, ver NeckTracker.kt en
// Android) no arranca en iOS: crea su propio contexto OpenGL ES y choca con
// ANGLE, la capa grafica que usa el motor 3D que dibuja la joya (detalle del
// crash en el comentario de `_necklaceBlockedOnIOS`, en try_on_screen.dart).
// Vision corre sobre Core ML y no administra su propio contexto grafico, por
// lo que ya convive con ANGLE en HandTrackingHandler (pulseras); aqui se
// prueba la misma ruta para collares.
//
// Dos diferencias de fondo con la version de Android:
//  - Vision no tiene una malla de 478 puntos: el menton y las mejillas salen
//    del contorno de la cara (`VNFaceLandmarks2D.faceContour`), que trae
//    bastantes menos puntos. El rectangulo de cara solo (sin landmarks) se
//    probo primero y resulto demasiado impreciso para el menton: su borde
//    inferior a veces caia cerca del borde de la imagen (visto en
//    dispositivo, 2026-11-22), muy por debajo del menton real.
//  - Vision no tiene segmentacion semantica piel/ropa. La base del cuello se
//    busca con una sonda de color sobre el buffer BGRA, igual en espiritu a
//    la sonda del antebrazo de las pulseras (ADR-21, `forearm_probe.dart`),
//    en vez de la mascara entrenada que usa `NeckMeasure` en Android.
//
// Segunda version, sin calibrar del todo en dispositivo. Si la base del
// cuello sigue saliendo inestable o mal ubicada, revertir el detector en
// `lib/core/isolate/detection_runner.dart` (DetectorKind.neck) y el bloqueo
// de `_necklaceBlockedOnIOS` en try_on_screen.dart.

import Flutter
import Vision
import CoreVideo

class NeckTrackingHandler: NSObject {
  private let request: VNDetectFaceLandmarksRequest = {
    let r = VNDetectFaceLandmarksRequest()
    r.revision = VNDetectFaceLandmarksRequestRevision3
    return r
  }()
  // Tercera version: la sonda de color sola confundia la pared de fondo con
  // piel (visto en dispositivo, 2026-11-22: la primera fila ya abarcaba toda
  // la imagen en varios frames). Vision no distingue piel de ropa, pero si
  // distingue persona de fondo; se usa como compuerta para que la sonda
  // nunca se escape fuera del cuerpo, aunque dentro del cuerpo (ropa vs
  // cuello) siga dependiendo del color.
  private let personSegRequest: VNGeneratePersonSegmentationRequest = {
    let r = VNGeneratePersonSegmentationRequest()
    r.qualityLevel = .fast
    r.outputPixelFormat = kCVPixelFormatType_OneComponent8
    return r
  }()
  private var seq = 0
  // Sexta version: con la sonda estable (cuarta version) y el collar ya del
  // tamano correcto (quinta version), mirando hacia arriba o hacia abajo el
  // ancho medido seguia saltando entre un valor angosto (~0.6-0.7 del ancho
  // de cara) y uno ancho (~1.1-1.3) de un frame al otro, con el menton casi
  // en la misma posicion (visto en dispositivo, 2026-11-24). La mancha mas
  // ancha de la primera fila a veces se queda angosta y a veces se funde
  // con la de al lado por un cambio minimo de iluminacion o ruido de
  // camara, porque el umbral de cromaticidad (`tol`) es un corte duro sin
  // margen. Se suaviza la posicion y el ancho ya corregidos con un
  // promedio movil (EMA) entre frames, en vez de usar el valor crudo de
  // cada frame tal cual. Se reinicia en cada `start` para no arrastrar la
  // posicion de una sesion de camara a la siguiente.
  private var smoothedLeftXPx: Double?
  private var smoothedRightXPx: Double?
  private var smoothedYPx: Double?

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    let channel = FlutterMethodChannel(
      name: "jewelry_ar/neck", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      seq = 0
      smoothedLeftXPx = nil
      smoothedRightXPx = nil
      smoothedYPx = nil
      result(nil)
    case "stop":
      result(nil)
    case "process":
      result(process(args: call.arguments as? [String: Any]))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // Responde con el mismo protocolo que `NeckTracker.kt`: `face`, `points`
  // (menton, mejilla izq., mejilla der., nariz, x3 cada uno), `faceWidth`,
  // `neck` (si se encontro base de cuello) y `seq`.
  private func process(args: [String: Any]?) -> [String: Any]? {
    guard
      let args = args,
      let data = args["bytes"] as? FlutterStandardTypedData,
      let width = args["width"] as? Int,
      let height = args["height"] as? Int,
      let stride = args["stride"] as? Int,
      let pixelBuffer = makePixelBuffer(
        data: data.data, width: width, height: height, bytesPerRow: stride)
    else { return nil }

    let actualBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    if actualBytesPerRow != stride {
      print(
        "NECKPROBE: stride no coincide: dart stride=\(stride) "
          + "buffer bytesPerRow=\(actualBytesPerRow) width=\(width)")
    }

    let handler = VNImageRequestHandler(
      cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
    do {
      try handler.perform([request, personSegRequest])
    } catch {
      return ["face": false]
    }

    guard
      let face = request.results?.first as? VNFaceObservation,
      let landmarks = face.landmarks,
      let contour = landmarks.faceContour,
      contour.normalizedPoints.count >= 5
    else {
      return ["face": false]
    }
    // Si no hay mascara de persona (p. ej. fallo puntual de la peticion), se
    // sigue sin la compuerta: la sonda vuelve a su comportamiento anterior
    // para ese frame, no se descarta toda la deteccion de cara.
    let personMask = personSegRequest.results?.first?.pixelBuffer
    if let personMask = personMask {
      print(
        "NECKPROBE: mascara ok \(CVPixelBufferGetWidth(personMask))x"
          + "\(CVPixelBufferGetHeight(personMask))")
    } else {
      print("NECKPROBE: sin mascara de persona este frame")
    }

    let box = face.boundingBox
    // Los puntos de landmarks vienen normalizados al recuadro de la cara, no
    // a la imagen completa: hay que llevarlos a la imagen con el recuadro.
    // Vision usa origen abajo-izquierda; se invierte para arriba-izquierda,
    // igual que en HandTrackingHandler.
    func toImage(_ p: CGPoint) -> (x: Double, y: Double) {
      let ix = Double(box.origin.x) + Double(p.x) * Double(box.width)
      let iy = 1.0 - (Double(box.origin.y) + Double(p.y) * Double(box.height))
      return (x: ix, y: iy)
    }

    let pts = contour.normalizedPoints
    // El contorno traza la mandibula de oreja a oreja pasando por el
    // menton: el punto medio es el menton. Mas preciso que el borde del
    // recuadro, que a veces incluye margen de mas por debajo de la
    // barbilla real (visto en dispositivo, 2026-11-22: el menton por
    // recuadro caia cerca del borde inferior de la imagen).
    let chin = toImage(pts[pts.count / 2])
    let leftRaw = pts.min(by: { $0.x < $1.x })!
    let rightRaw = pts.max(by: { $0.x < $1.x })!
    let cheekA = toImage(leftRaw)
    let cheekB = toImage(rightRaw)
    let (cheekLeft, cheekRight) = cheekA.x <= cheekB.x ? (cheekA, cheekB) : (cheekB, cheekA)

    let nose: (x: Double, y: Double)
    if let noseRegion = landmarks.nose, !noseRegion.normalizedPoints.isEmpty {
      var sx: CGFloat = 0, sy: CGFloat = 0
      for p in noseRegion.normalizedPoints { sx += p.x; sy += p.y }
      let n = CGFloat(noseRegion.normalizedPoints.count)
      nose = toImage(CGPoint(x: sx / n, y: sy / n))
    } else {
      nose = (x: (cheekLeft.x + cheekRight.x) / 2, y: (cheekLeft.y + cheekRight.y) / 2)
    }

    let dxw = cheekRight.x - cheekLeft.x
    let dyw = cheekRight.y - cheekLeft.y
    let faceWidth = (dxw * dxw + dyw * dyw).squareRoot()
    // `face.pitch` salio siempre en 0.0 en dispositivo (2026-11-22), aun
    // mirando bien hacia arriba: esta peticion no lo da. En su lugar, la
    // distancia nariz-menton en proporcion al ancho de cara: mirando hacia
    // arriba el menton se "pliega" hacia la camara y esa distancia se
    // acorta en la imagen; mirando al frente es mas larga. Reusa puntos ya
    // calculados, no depende de un dato que Vision no entrega aqui.
    let noseToChinFrac = (chin.y - nose.y) / faceWidth
    print(
      "NECKPROBE: chin=(\(chin.x),\(chin.y)) faceWidth=\(faceWidth) "
        + "noseToChinFrac=\(noseToChinFrac) confidence=\(face.confidence)")

    var out: [String: Any] = [
      "face": true,
      "points": [
        chin.x, chin.y, 0,
        cheekLeft.x, cheekLeft.y, 0,
        cheekRight.x, cheekRight.y, 0,
        nose.x, nose.y, 0,
      ],
      "faceWidth": faceWidth,
    ]

    if let neck = probeNeckBase(
      pixelBuffer: pixelBuffer, width: width, height: height,
      personMask: personMask,
      noseToChinFrac: noseToChinFrac, chin: chin, faceWidth: faceWidth)
    {
      out["neck"] = neck
    }

    seq += 1
    out["seq"] = seq
    return out
  }

  /// Busca la base del cuello bajando desde el menton por la franja de color
  /// de piel, igual en espiritu a la sonda del antebrazo (ADR-21): sin
  /// segmentacion semantica, se toma la cromaticidad de la propia piel del
  /// cuello como referencia en cada frame y se sigue mientras el color se
  /// mantenga; donde deja de mantenerse (ropa, sombra, fondo) se toma como
  /// la base. No distingue ese final de un fondo que tambien sea piel, a
  /// diferencia de la mascara de Android.
  private func probeNeckBase(
    pixelBuffer: CVPixelBuffer, width: Int, height: Int,
    personMask: CVPixelBuffer?,
    noseToChinFrac: Double, chin: (x: Double, y: Double), faceWidth: Double
  ) -> [String: Any]? {
    guard faceWidth > 0.02, faceWidth < 1.0 else {
      print("NECKPROBE: faceWidth fuera de rango: \(faceWidth)")
      return nil
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      print("NECKPROBE: no se pudo obtener el base address del buffer")
      return nil
    }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let buf = base.assumingMemoryBound(to: UInt8.self)

    func pixel(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int)? {
      guard x >= 0, x < width, y >= 0, y < height else { return nil }
      let i = y * bytesPerRow + x * 4
      // BGRA: B, G, R, A.
      return (r: Int(buf[i + 2]), g: Int(buf[i + 1]), b: Int(buf[i]))
    }

    // Compuerta de persona: la mascara suele venir en una resolucion mas
    // chica que la imagen. Si no hay mascara (peticion fallida ese frame),
    // no se bloquea nada, la sonda queda como antes (solo color). El buffer
    // se mantiene bloqueado hasta el final de la funcion (no solo hasta
    // aqui), porque `isPerson` sigue leyendolo durante todo el escaneo de
    // mas abajo.
    var isPerson: ((Int, Int) -> Bool)? = nil
    if let personMask = personMask {
      CVPixelBufferLockBaseAddress(personMask, .readOnly)
      let maskW = CVPixelBufferGetWidth(personMask)
      let maskH = CVPixelBufferGetHeight(personMask)
      let maskBytesPerRow = CVPixelBufferGetBytesPerRow(personMask)
      if let maskBase = CVPixelBufferGetBaseAddress(personMask), maskW > 0, maskH > 0 {
        let maskBuf = maskBase.assumingMemoryBound(to: UInt8.self)
        let sx = Double(maskW) / Double(width)
        let sy = Double(maskH) / Double(height)
        isPerson = { x, y in
          let mx = min(maskW - 1, max(0, Int(Double(x) * sx)))
          let my = min(maskH - 1, max(0, Int(Double(y) * sy)))
          // Medido >0 en dispositivo como persona, 0 como fondo con calidad
          // .fast; se deja un margen bajo (32 de 255) por si da valores
          // intermedios en el borde del cuerpo.
          return maskBuf[my * maskBytesPerRow + mx] > 32
        }
      }
    }
    defer {
      if let personMask = personMask {
        CVPixelBufferUnlockBaseAddress(personMask, .readOnly)
      }
    }

    // Cromaticidad normalizada (r/(r+g+b), g/(r+g+b)): compara el tono de
    // piel sin depender del brillo exacto, igual en espiritu a la
    // crominancia YUV que usa la sonda del antebrazo.
    func chroma(_ p: (r: Int, g: Int, b: Int)) -> (rn: Double, gn: Double) {
      let s = Double(p.r + p.g + p.b)
      guard s > 1 else { return (rn: 0, gn: 0) }
      return (rn: Double(p.r) / s, gn: Double(p.g) / s)
    }

    let chinX = Int(chin.x * Double(width))
    let chinY = Int(chin.y * Double(height))
    let faceWidthPx = faceWidth * Double(width)

    // Referencia de piel: unas filas debajo del menton, que ya es cuello.
    var refs: [(rn: Double, gn: Double)] = []
    let refY = chinY + Int(0.05 * faceWidthPx)
    for dy in 0..<3 {
      for dx in stride(from: -2, through: 2, by: 1) {
        if let p = pixel(chinX + dx, refY + dy) { refs.append(chroma(p)) }
      }
    }
    guard refs.count >= 6 else {
      print(
        "NECKPROBE: referencia de piel insuficiente (\(refs.count) muestras) "
          + "chin=(\(chinX),\(chinY)) refY=\(refY) wh=(\(width),\(height))")
      return nil
    }
    let refRn = refs.map { $0.rn }.sorted()[refs.count / 2]
    let refGn = refs.map { $0.gn }.sorted()[refs.count / 2]
    // Con 0.04 casi ningun par de pixeles vecinos de piel real pasaba a la
    // vez (sombras bajo el menton, ruido de la camara): la sonda seguia un
    // hilo de 1 pixel en vez de ensanchar sobre el cuello (visto en
    // dispositivo, 2026-11-22: casi todos los intentos terminaban con
    // lastL==lastR). El tope de ensanche por fila y el ancho final siguen
    // limitando que esto se escape hacia un fondo parecido a la piel.
    let tol = 0.09

    func isSkin(_ x: Int, _ y: Int) -> Bool {
      if let isPerson = isPerson, !isPerson(x, y) { return false }
      guard let p = pixel(x, y) else { return false }
      let c = chroma(p)
      return abs(c.rn - refRn) < tol && abs(c.gn - refGn) < tol
    }

    let reach = max(2, Int(0.35 * faceWidthPx))
    let minRun = 0.2 * faceWidthPx
    // Ancho plausible de hombro/base de cuello; mas alla de esto ya no es
    // cuello sino fondo. Mas generoso que el tope final (1.4) porque los
    // hombros si pueden ser mas anchos que la cara.
    let maxRowWidth = 2.0 * faceWidthPx
    let yStart = max(0, chinY - Int(0.05 * faceWidthPx))
    // `face.pitch` no lo da esta peticion (siempre 0.0 en dispositivo,
    // 2026-11-22, aun mirando hacia arriba). `noseToChinFrac` mas chico
    // (menton "plegado" hacia la camara, mirando hacia arriba) agranda la
    // ventana; mas grande (menton extendido, mirando al frente) la achica.
    // Constantes sin calibrar: primera estimacion a partir de proporciones
    // tipicas de cara, pendiente de confirmar con el log de la proxima
    // prueba.
    let windowScale = max(0.5, min(1.4, 1.6 - 2.3 * noseToChinFrac))
    let yEnd = min(height - 1, chinY + Int(windowScale * faceWidthPx))
    print("NECKPROBE: windowScale=\(windowScale)")

    // Cuarta version: antes, la fila de arranque (la mas pegada al menton)
    // se armaba agrandando desde el primer pixel de piel que se encontrara
    // al alejarse de chinX por `d` creciente (izquierda y derecha
    // alternado). Si el tono de piel justo bajo el menton quedaba partido
    // en dos manchas separadas (p. ej. una sombra en el medio), cual de las
    // dos se encontraba "primero" dependia de ruido de un frame a otro, y
    // la base saltaba de lado a lado entre frames aunque cada uno
    // individualmente saliera "ok" (visto en dispositivo, 2026-11-23: el
    // centro alternaba entre ~x100-160 y ~x270-330 en el mismo tramo
    // mirando al frente). Por eso solo la fila de arranque usa la mancha
    // contigua mas ancha dentro del alcance, no la mas cercana a chinX: una
    // mancha real de cuello casi siempre es mas ancha que un reflejo o
    // ruido aislado al otro lado. Se probo usar esto en todas las filas
    // (no solo la de arranque), pero eso le quita a la sonda la localidad
    // fila a fila: deja de crecer de forma contigua desde donde venia y
    // puede "teletransportarse" a cualquier mancha ancha dentro del
    // alcance en cada fila, así que nunca encuentra una transicion real y
    // siempre se queda sin ventana (visto en dispositivo, 2026-11-23: cero
    // `ok base` en todo el log). Las filas siguientes vuelven al criterio
    // original: el pixel mas cercano a la semilla, agrandado de forma
    // contigua desde ahi.
    func widestSkinRun(around seed: Int, row y: Int) -> (l: Int, r: Int)? {
      let lo = max(0, seed - reach)
      let hi = min(width - 1, seed + reach)
      guard lo <= hi else { return nil }
      var best: (l: Int, r: Int)? = nil
      var runStart = -1
      var x = lo
      while x <= hi + 1 {
        let skin = x <= hi && isSkin(x, y)
        if skin {
          if runStart < 0 { runStart = x }
        } else if runStart >= 0 {
          let runEnd = x - 1
          if best == nil || (runEnd - runStart) > (best!.r - best!.l) {
            best = (l: runStart, r: runEnd)
          }
          runStart = -1
        }
        x += 1
      }
      return best
    }

    var seed = chinX
    var started = false
    var lastL = -1, lastR = -1, lastY = -1
    // Ancho de la primera fila aceptada (la mas pegada al menton, la mas
    // confiable). El escape hacia la ropa o el fondo casi nunca salta de
    // golpe: crece gradualmente fila a fila, pocos pixeles cada vez, asi
    // que un tope de ensanche entre filas consecutivas no lo atrapaba
    // (visto en dispositivo, 2026-11-22: anchos finales de 1.5x a 2.6x la
    // cara, casi siempre pegados al borde de la imagen). Comparar contra
    // esta primera fila, no contra la anterior, si acota cuanto puede
    // crecer en total el tramo antes de descartarlo.
    var firstWidth = 0.0

    var y = yStart
    while y <= yEnd {
      if !started {
        guard let run = widestSkinRun(around: seed, row: y) else {
          y += 1
          continue
        }
        let rowWidth = Double(run.r - run.l + 1)
        // No se arranca con un hilo de piel junto a la mandibula: la
        // semilla se iria hacia ese lado.
        if rowWidth < minRun {
          y += 1
          continue
        }
        firstWidth = rowWidth
        started = true
        lastL = run.l
        lastR = run.r
        lastY = y
        seed = (run.l + run.r) / 2
        y += 1
        continue
      }

      var x0 = -1
      var d = 0
      while d <= reach {
        if seed - d >= 0, isSkin(seed - d, y) { x0 = seed - d; break }
        if seed + d < width, isSkin(seed + d, y) { x0 = seed + d; break }
        d += 1
      }
      if x0 < 0 {
        break
      }
      var l = x0
      while l > 0, isSkin(l - 1, y) { l -= 1 }
      var r = x0
      while r < width - 1, isSkin(r + 1, y) { r += 1 }
      let rowWidth = Double(r - l + 1)

      if rowWidth > maxRowWidth || rowWidth > firstWidth * 1.8 {
        break
      }
      lastL = l
      lastR = r
      lastY = y
      seed = (l + r) / 2
      y += 1
    }

    guard started, lastY >= 0 else {
      print(
        "NECKPROBE: nunca arranco el tramo de piel (reach=\(reach) minRun="
          + "\(Int(minRun)) ref=(\(refRn),\(refGn)) chin=(\(chinX),\(chinY)) "
          + "yStart=\(yStart) yEnd=\(yEnd))")
      return nil
    }
    // Si la sonda llego hasta el final de la ventana de busqueda sin que el
    // color dejara de calzar, no encontro una transicion de verdad: solo se
    // quedo sin imagen que explorar. Aceptar ese caso era lo que antes hacia
    // que la base terminara pegada al borde inferior de la camara en vez de
    // en el cuello real.
    guard lastY < yEnd else {
      print(
        "NECKPROBE: la sonda llego al borde de la ventana sin encontrar "
          + "transicion (lastY=\(lastY) yEnd=\(yEnd))")
      return nil
    }
    let baseWidthFrac = Double(lastR - lastL + 1) / Double(width) / faceWidth
    guard baseWidthFrac > 0.35, baseWidthFrac < 1.4 else {
      print(
        "NECKPROBE: ancho de base fuera de rango: \(baseWidthFrac) "
          + "(lastL=\(lastL) lastR=\(lastR) lastY=\(lastY) "
          + "firstWidth=\(firstWidth))")
      return nil
    }
    print(
      "NECKPROBE: ok base=(\(lastL),\(lastY))-(\(lastR),\(lastY)) "
        + "ancho=\(baseWidthFrac)")

    // Quinta version: con la sonda ya estable (cuarta version), el collar se
    // veia bien anclado pero chico en pantalla (visto en dispositivo,
    // 2026-11-24: anchos estables de 0.65-0.70 del ancho de cara mirando al
    // frente, mas angostos que los 0.9-1.3 que se veian antes de la cuarta
    // version). La piel visible del cuello (sin la quijada, el pelo o una
    // sombra encima) probablemente es mas angosta que el contorno real del
    // cuello donde se apoya el collar. Se ensancha el tramo medido
    // manteniendo el mismo centro, antes de devolverlo: la posicion
    // (frontX/frontY) no cambia, solo el ancho que alimenta la escala del
    // collar en Dart (`necklace_strategy.dart`). Factor de primera
    // estimacion, sin calibrar del todo, pendiente de confirmar que tamano
    // se ve bien en dispositivo.
    let sizeCorrection = 1.3
    let center = Double(lastL + lastR) / 2.0
    let halfWidthPx = Double(lastR - lastL + 1) / 2.0 * sizeCorrection
    let correctedL = center - halfWidthPx
    let correctedR = center + halfWidthPx

    // Sexta version: promedio movil (EMA) sobre la posicion ya corregida,
    // para no pasar de frame a frame el salto angosto/ancho descrito mas
    // arriba. `emaAlpha` de primera estimacion: mas chico suaviza mas pero
    // atrasa mas el seguimiento cuando la cabeza se mueve de verdad (al
    // mirar arriba/abajo), sin calibrar del todo.
    let emaAlpha = 0.25
    func ema(_ previous: Double?, _ current: Double) -> Double {
      guard let previous = previous else { return current }
      return previous + emaAlpha * (current - previous)
    }
    let smoothedL = ema(smoothedLeftXPx, correctedL)
    let smoothedR = ema(smoothedRightXPx, correctedR)
    let smoothedY = ema(smoothedYPx, Double(lastY))
    smoothedLeftXPx = smoothedL
    smoothedRightXPx = smoothedR
    smoothedYPx = smoothedY
    let smoothedWidthFrac =
      (smoothedR - smoothedL) / Double(width) / faceWidth

    return [
      "leftX": smoothedL / Double(width),
      "leftY": smoothedY / Double(height),
      "rightX": smoothedR / Double(width),
      "rightY": smoothedY / Double(height),
      "hasFront": false,
      "frontX": (smoothedL + smoothedR) / 2.0 / Double(width),
      "frontY": smoothedY / Double(height),
      "narrow": smoothedWidthFrac,
      "columnX": -1.0,
      "refChinX": chin.x,
      "refChinY": chin.y,
      "refFaceWidth": faceWidth,
    ]
  }

  private func makePixelBuffer(
    data: Data, width: Int, height: Int, bytesPerRow: Int
  ) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    let attrs: CFDictionary = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ] as CFDictionary

    let status = CVPixelBufferCreate(
      kCFAllocatorDefault, width, height,
      kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
    guard status == kCVReturnSuccess, let pb = pixelBuffer else { return nil }

    CVPixelBufferLockBaseAddress(pb, [])
    defer { CVPixelBufferUnlockBaseAddress(pb, []) }
    if let dest = CVPixelBufferGetBaseAddress(pb) {
      data.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
        if let base = src.baseAddress {
          memcpy(dest, base, min(data.count, bytesPerRow * height))
        }
      }
    }
    return pb
  }
}
