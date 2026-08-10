import 'package:camera/camera.dart';

import '../../domain/entities/landmark.dart';

/// Contrato de un detector de landmarks de mano, independiente de plataforma.
/// Android lo implementa con `hand_landmarker` (MediaPipe/JNI); iOS con un
/// platform channel a Vision/MediaPipe (spike B1).
abstract interface class HandDetector {
  Future<void> initialize();

  /// Devuelve los 21 landmarks de la mano detectada (vacío si no hay mano).
  Future<List<Landmark>> detect(CameraImage frame, int sensorOrientation);

  Future<void> dispose();
}
