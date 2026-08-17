import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../domain/entities/landmark.dart';
import 'landmark_detector.dart';

/// Detector de pose para collares, basado en `google_mlkit_pose_detection`
/// (cross-platform). Extrae los 33 landmarks de pose; para el anclaje del collar
/// interesan los hombros (11 y 12), que consume `NecklaceStrategy` (spike B2).
///
/// Los landmarks de ML Kit vienen en píxeles de la imagen; aquí se **normalizan**
/// a [0,1] dividiendo por el tamaño del frame, para ser consistentes con la
/// entidad [Landmark].
///
/// La conversión `CameraImage → InputImage` sigue el patrón oficial de ML Kit y
/// queda **pendiente de validación en dispositivo** (formato/rotación por
/// plataforma): en Android conviene configurar la cámara en `nv21`; en iOS,
/// `bgra8888`.
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

    return _mapPose(poses.first, frame.width, frame.height);
  }

  @override
  Future<void> dispose() async {
    await _detector.close();
  }

  @override
  ImageFormatGroup get imageFormatGroup =>
      Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

  /// Convierte una [Pose] a la lista de [Landmark] normalizados, en el orden del
  /// enum de ML Kit (índice 11 = hombro izquierdo, 12 = hombro derecho).
  List<Landmark> _mapPose(Pose pose, int width, int height) {
    final w = width.toDouble();
    final h = height.toDouble();
    return [
      for (final type in PoseLandmarkType.values)
        if (pose.landmarks[type] case final lm?)
          Landmark(lm.x / w, lm.y / h, lm.z, visibility: lm.likelihood)
        else
          const Landmark(0, 0, 0, visibility: 0),
    ];
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
