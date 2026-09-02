import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart' as hl;

import '../../../../core/math/geometry.dart';
import '../../domain/entities/landmark.dart';
import 'landmark_detector.dart';

/// Detector de manos en Android, basado en `hand_landmarker` (MediaPipe Hand
/// Landmarker vía JNI). Entrega 21 landmarks con x, y, z normalizados; para el
/// anclaje de la pulsera interesan la muñeca (0) y los MCP de índice (5) y
/// meñique (17).
///
/// **Espacio de coordenadas:** al plugin se le pasa la `sensorOrientation` y
/// él se la da a MediaPipe como `ImageProcessingOptions.setRotationDegrees`,
/// pero eso solo rota la imagen para la inferencia: los landmarks vuelven
/// normalizados en el buffer **original apaisado** del sensor. El resto del
/// pipeline los espera en el frame ya rotado a vertical, así que se convierten
/// aquí, en la frontera con el plugin.
///
/// Nota de rendimiento (B5): `detect()` del plugin es síncrono y bloquea el
/// isolate que lo llame; corre dentro del isolate dedicado de detección.
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
      for (final lm in hands.first.landmarks)
        _toUpright(lm, sensorOrientation),
    ];
  }

  static Landmark _toUpright(hl.Landmark lm, int sensorOrientation) {
    final p = rotateNormalizedToUpright(
      x: lm.x,
      y: lm.y,
      rotationDegrees: sensorOrientation,
    );
    return Landmark(p.x, p.y, lm.z);
  }

  @override
  Future<void> dispose() async {
    _plugin?.dispose();
    _plugin = null;
  }
}
