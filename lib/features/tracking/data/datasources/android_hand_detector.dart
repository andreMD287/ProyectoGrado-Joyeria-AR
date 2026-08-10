import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart' as hl;

import '../../domain/entities/landmark.dart';
import 'landmark_detector.dart';

/// Detector de manos en Android, basado en `hand_landmarker` (MediaPipe Hand
/// Landmarker vía JNI). Entrega 21 landmarks con x, y, z normalizados; para el
/// anclaje de la pulsera interesa la muñeca (índice 0).
///
/// Nota de rendimiento (B5): `detect()` del plugin es síncrono y bloquea el
/// isolate principal; el `TrackingRepositoryImpl` lo protege con throttling.
/// La solución de fondo es moverlo al isolate dedicado.
class AndroidHandDetector implements LandmarkDetector {
  hl.HandLandmarkerPlugin? _plugin;

  @override
  Future<void> initialize() async {
    _plugin = hl.HandLandmarkerPlugin.create(
      numHands: 1,
      minHandDetectionConfidence: 0.6,
      delegate: hl.HandLandmarkerDelegate.gpu,
    );
  }

  @override
  Future<List<Landmark>> detect(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    final plugin = _plugin;
    if (plugin == null) return const [];

    final hands = plugin.detect(frame, sensorOrientation);
    if (hands.isEmpty) return const [];

    return [
      for (final lm in hands.first.landmarks) Landmark(lm.x, lm.y, lm.z),
    ];
  }

  @override
  Future<void> dispose() async {
    _plugin?.dispose();
    _plugin = null;
  }
}
