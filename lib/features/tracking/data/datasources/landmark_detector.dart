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
}
