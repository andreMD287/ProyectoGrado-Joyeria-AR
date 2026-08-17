import 'package:camera/camera.dart';

import '../../domain/entities/landmark.dart';

/// Contrato común de un detector de landmarks (manos, rostro o pose),
/// independiente de plataforma. El `TrackingRepositoryImpl` selecciona la
/// implementación según el `DetectorKind` que declara cada estrategia.
abstract interface class LandmarkDetector {
  Future<void> initialize();

  /// Devuelve los landmarks detectados en el frame (vacío si no hay).
  Future<List<Landmark>> detect(CameraImage frame, int sensorOrientation);

  Future<void> dispose();

  /// Formato de imagen de cámara que este detector necesita. Los detectores
  /// basados en ML Kit (`InputImage.fromBytes`) requieren un solo plano
  /// (`nv21` en Android, `bgra8888` en iOS); `hand_landmarker` (MediaPipe vía
  /// JNI) requiere `yuv420`.
  ImageFormatGroup get imageFormatGroup;
}
