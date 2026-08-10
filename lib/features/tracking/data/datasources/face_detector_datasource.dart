import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../domain/entities/landmark.dart';

/// Detector facial para aretes, basado en `google_mlkit_face_detection`
/// (cross-platform). Habilita los landmarks del rostro y entrega —en el orden
/// que espera `EarringStrategy`— oreja izq (0), oreja der (1), ojo izq (2) y
/// ojo der (3), normalizados a [0,1].
///
/// La conversión `CameraImage → InputImage` sigue el patrón oficial de ML Kit y
/// queda **pendiente de validación en dispositivo** (Android `nv21`, iOS
/// `bgra8888`, rotación según `sensorOrientation`).
class FaceDetectorDataSource {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(enableLandmarks: true),
  );

  Future<void> initialize() async {}

  Future<List<Landmark>> detect(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    final input = _toInputImage(frame, sensorOrientation);
    if (input == null) return const [];

    final faces = await _detector.processImage(input);
    if (faces.isEmpty) return const [];

    return _mapFace(faces.first, frame.width, frame.height);
  }

  Future<void> dispose() async {
    await _detector.close();
  }

  List<Landmark> _mapFace(Face face, int width, int height) {
    final w = width.toDouble();
    final h = height.toDouble();

    Landmark of(FaceLandmarkType type) {
      final lm = face.landmarks[type];
      if (lm == null) return const Landmark(0, 0, 0, visibility: 0);
      return Landmark(lm.position.x / w, lm.position.y / h, 0, visibility: 1);
    }

    return [
      of(FaceLandmarkType.leftEar), // 0
      of(FaceLandmarkType.rightEar), // 1
      of(FaceLandmarkType.leftEye), // 2
      of(FaceLandmarkType.rightEye), // 3
    ];
  }

  InputImage? _toInputImage(CameraImage image, int sensorOrientation) {
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
