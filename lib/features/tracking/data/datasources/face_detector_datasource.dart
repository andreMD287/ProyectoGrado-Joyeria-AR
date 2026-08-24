import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/math/geometry.dart';
import '../../domain/entities/landmark.dart';
import 'landmark_detector.dart';

/// Detector facial para aretes (`google_mlkit_face_detection`).
///
/// Orden fijo para `EarringStrategy`:
/// 0 oreja izq · 1 oreja der · 2 ojo izq · 3 ojo der · 4 mejilla izq ·
/// 5 mejilla der · 6 lóbulo izq (bbox) · 7 lóbulo der (bbox).
///
/// Los puntos 6/7 salen del [Face.boundingBox] (muy estables de frente); las
/// orejas de ML Kit parpadean y hacen saltar el anclaje de un lado a otro.
class FaceDetectorDataSource implements LandmarkDetector {
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(enableLandmarks: true),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Landmark>> detect(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    final input = _toInputImage(frame, sensorOrientation);
    if (input == null) return const [];

    final faces = await _detector.processImage(input);
    if (faces.isEmpty) return const [];

    return _mapFace(
      faces.first,
      frame.width,
      frame.height,
      sensorOrientation,
    );
  }

  @override
  Future<void> dispose() async {
    await _detector.close();
  }

  List<Landmark> _mapFace(
    Face face,
    int width,
    int height,
    int sensorOrientation,
  ) {
    Landmark ofPixel(double px, double py, {double visibility = 1}) {
      final n = normalizeMlKitLandmarkToPreview(
        pixelX: px,
        pixelY: py,
        bufferWidth: width,
        bufferHeight: height,
        rotationDegrees: sensorOrientation,
        isFrontCamera: true,
        isIOS: Platform.isIOS,
      );
      return Landmark(n.x, n.y, 0, visibility: visibility);
    }

    Landmark of(FaceLandmarkType type) {
      final lm = face.landmarks[type];
      if (lm == null) return const Landmark(0, 0, 0, visibility: 0);
      return ofPixel(lm.position.x.toDouble(), lm.position.y.toDouble());
    }

    // Lóbulo ≈ borde lateral a ~64% de la altura del rostro (bajo el centro
    // de la oreja; 0.58 quedaba entre hélix y lóbulo).
    final box = face.boundingBox;
    final lobeY = box.top + box.height * 0.64;
    final leftBBoxLobe = ofPixel(box.left, lobeY);
    final rightBBoxLobe = ofPixel(box.right, lobeY);

    return [
      of(FaceLandmarkType.leftEar), // 0
      of(FaceLandmarkType.rightEar), // 1
      of(FaceLandmarkType.leftEye), // 2
      of(FaceLandmarkType.rightEye), // 3
      of(FaceLandmarkType.leftCheek), // 4
      of(FaceLandmarkType.rightCheek), // 5
      leftBBoxLobe, // 6
      rightBBoxLobe, // 7
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
