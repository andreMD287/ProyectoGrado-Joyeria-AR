// Portado del spike B1 (spikes/B1-ios-hand-tracking/native/HandTrackingHandler.swift).
//
// Implementación nativa del platform channel que consume `IosHandDetector`
// (lado Dart). Usa Apple Vision (VNDetectHumanHandPoseRequest) para obtener los
// 21 landmarks de la mano y los devuelve en orden MediaPipe (índice 0 = muñeca).

import Flutter
import Vision
import CoreVideo

class HandTrackingHandler: NSObject {
  private let request = VNDetectHumanHandPoseRequest()

  // Orden MediaPipe (21 landmarks): muñeca + 4 por dedo (pulgar→meñique).
  private let jointOrder: [VNHumanHandPoseObservation.JointName] = [
    .wrist,
    .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
    .indexMCP, .indexPIP, .indexDIP, .indexTip,
    .middleMCP, .middlePIP, .middleDIP, .middleTip,
    .ringMCP, .ringPIP, .ringDIP, .ringTip,
    .littleMCP, .littlePIP, .littleDIP, .littleTip,
  ]

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    request.maximumHandCount = 1
    let channel = FlutterMethodChannel(
      name: "co.edu.javeriana.jewelry_ar/hand_tracking_ios",
      binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start", "stop":
      result(nil)
    case "detect":
      result(detect(args: call.arguments as? [String: Any]))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // Devuelve [x, y, confidence] × 21 (x,y normalizados, origen arriba-izquierda).
  private func detect(args: [String: Any]?) -> [Double] {
    guard
      let args = args,
      let data = args["bytes"] as? FlutterStandardTypedData,
      let width = args["width"] as? Int,
      let height = args["height"] as? Int,
      let bytesPerRow = args["bytesPerRow"] as? Int,
      let pixelBuffer = makePixelBuffer(
        data: data.data, width: width, height: height, bytesPerRow: bytesPerRow)
    else { return [] }

    let handler = VNImageRequestHandler(
      cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
    do {
      try handler.perform([request])
    } catch {
      return []
    }

    guard
      let observation = request.results?.first as? VNHumanHandPoseObservation,
      let points = try? observation.recognizedPoints(.all)
    else { return [] }

    var flat: [Double] = []
    flat.reserveCapacity(jointOrder.count * 3)
    for joint in jointOrder {
      if let p = points[joint], p.confidence > 0 {
        // Vision usa origen abajo-izquierda; se invierte y para arriba-izquierda.
        flat.append(Double(p.location.x))
        flat.append(Double(1.0 - p.location.y))
        flat.append(Double(p.confidence))
      } else {
        flat.append(contentsOf: [0, 0, 0])
      }
    }
    return flat
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
