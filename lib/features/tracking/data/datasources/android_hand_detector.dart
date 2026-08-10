import 'package:camera/camera.dart';

import '../../domain/entities/landmark.dart';
import 'hand_detector.dart';

/// Detector de manos en Android, basado en `hand_landmarker` (MediaPipe Hand
/// Landmarker vía JNI). Ya validado en la fase previa: 21 landmarks con x,y,z.
///
/// TODO(C2): envolver `HandLandmarkerPlugin` (create/detect/dispose) y mapear
/// sus landmarks a la entidad [Landmark]. Ejecutar dentro del isolate de
/// detección (B5) para no bloquear el hilo principal.
class AndroidHandDetector implements HandDetector {
  @override
  Future<void> initialize() async {}

  @override
  Future<List<Landmark>> detect(CameraImage frame, int sensorOrientation) async {
    return const [];
  }

  @override
  Future<void> dispose() async {}
}
