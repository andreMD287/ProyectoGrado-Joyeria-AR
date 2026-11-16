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

/// Un detector que además publica cada resultado apenas lo tiene, sin esperar
/// a la siguiente llamada a [LandmarkDetector.detect].
///
/// Con petición y respuesta, el resultado de un frame solo sale con el frame
/// siguiente: con la cámara frontal a ~15 por segundo eso son hasta 66 ms en
/// los que la pose ya está calculada y no se usa (medido en el Galaxy A15,
/// 2026-11-08). Con estos detectores [LandmarkDetector.detect] solo entrega
/// el frame y devuelve [LandmarkFrame.empty]; lo detectado llega por
/// [results], incluido un [LandmarkFrame.empty] cuando no se vio nada.
abstract interface class PushesResults {
  Stream<LandmarkFrame> get results;
}
