import 'package:camera/camera.dart';

import '../../domain/entities/landmark_frame.dart';

/// Contrato común de un detector de landmarks (manos, rostro o pose),
/// independiente de plataforma. El `TrackingRepositoryImpl` selecciona la
/// implementación según el `DetectorKind` que declara cada estrategia.
abstract interface class LandmarkDetector {
  Future<void> initialize();

  /// Devuelve lo detectado en el frame ([LandmarkFrame.empty] si no hay nada).
  ///
  /// Un detector que solo produzca landmarks de imagen deja vacía la parte
  /// métrica; no es un error, es la ausencia de esa capacidad.
  Future<LandmarkFrame> detect(CameraImage frame, int sensorOrientation);

  Future<void> dispose();
}
