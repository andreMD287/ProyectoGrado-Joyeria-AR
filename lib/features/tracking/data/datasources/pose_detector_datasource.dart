import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/math/geometry.dart';
import '../../domain/entities/landmark.dart';
import 'landmark_detector.dart';

/// Detector de pose para collares, basado en `google_mlkit_pose_detection`
/// (cross-platform). Extrae los 33 landmarks de pose; para el anclaje del collar
/// interesan los hombros (11 y 12), que consume `NecklaceStrategy` (spike B2).
///
/// Los landmarks de ML Kit vienen en píxeles; se normalizan a [0,1] en el
/// espacio del `CameraPreview` con [normalizeMlKitLandmarkToPreview] (corrige
/// el intercambio de ejes en Android con rotación 90°/270°).
///
/// Collares usan cámara **frontal**. Corrección de rotación solo en Android;
/// iOS conserva `x/w`, `y/h`. `z` en escala cruda de ML Kit (overlay usa x/y).
class PoseDetectorDataSource implements LandmarkDetector {
  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
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

    final poses = await _detector.processImage(input);
    if (poses.isEmpty) return const [];

    return _mapPose(
      poses.first,
      frame.width,
      frame.height,
      sensorOrientation,
    );
  }

  @override
  Future<void> dispose() async {
    await _detector.close();
  }

  /// Convierte una [Pose] a la lista de [Landmark] normalizados, en el orden del
  /// enum de ML Kit (índice 11 = hombro izquierdo, 12 = hombro derecho).
  List<Landmark> _mapPose(
    Pose pose,
    int width,
    int height,
    int sensorOrientation,
  ) {
    return [
      for (final type in PoseLandmarkType.values)
        if (pose.landmarks[type] case final lm?)
          _toLandmark(lm, width, height, sensorOrientation)
        else
          const Landmark(0, 0, 0, visibility: 0),
    ];
  }

  Landmark _toLandmark(
    PoseLandmark lm,
    int width,
    int height,
    int sensorOrientation,
  ) {
    final n = normalizeMlKitLandmarkToPreview(
      pixelX: lm.x,
      pixelY: lm.y,
      bufferWidth: width,
      bufferHeight: height,
      rotationDegrees: sensorOrientation,
      isFrontCamera: true,
      isIOS: Platform.isIOS,
    );
    return Landmark(n.x, n.y, lm.z, visibility: lm.likelihood);
  }

  InputImage? _toInputImage(CameraImage image, int sensorOrientation) {
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Patrón oficial: en Android (nv21) e iOS (bgra8888) el plano es único.
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
