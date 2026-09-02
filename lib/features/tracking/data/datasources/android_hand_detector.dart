import 'dart:async';

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
/// **Modelo de ejecución (plugin 3.x).** El plugin corre MediaPipe en modo
/// `LIVE_STREAM`: `processFrame` entrega el frame al nativo y vuelve de
/// inmediato, y los resultados llegan más tarde por un `EventChannel`. No hay
/// una correspondencia uno a uno entre frame entregado y resultado devuelto.
/// Para encajarlo en el contrato de [LandmarkDetector], que es de petición y
/// respuesta, [detect] entrega el frame y devuelve **el último resultado
/// disponible**. Es lo correcto para AR: interesa el dato más reciente, no el
/// que corresponda exactamente al frame que se acaba de mandar.
///
/// Hasta la 2.x el plugin exponía un `detect()` síncrono que bloqueaba, y que
/// además convertía cada frame comprimiéndolo a JPEG y volviéndolo a
/// decodificar; de ahí que la detección corriera a ~3.5 Hz.
///
/// **Espacio de coordenadas.** Al plugin se le pasa la `sensorOrientation` y
/// él se la da a MediaPipe como `ImageProcessingOptions.setRotationDegrees`,
/// pero eso solo rota la imagen para la inferencia: los landmarks vuelven
/// normalizados en el buffer **original apaisado** del sensor. El resto del
/// pipeline los espera en el frame ya rotado a vertical, así que se convierten
/// aquí, en la frontera con el plugin.
class AndroidHandDetector implements LandmarkDetector {
  /// Más allá de este tiempo sin recibir nada del `EventChannel` se considera
  /// que no hay dato, en vez de seguir devolviendo el último. Sin esto, si el
  /// stream se cortara, la joya se quedaría clavada en una pose vieja.
  static const Duration _staleAfter = Duration(milliseconds: 500);

  hl.HandLandmarkerPlugin? _plugin;
  StreamSubscription<List<hl.Hand>>? _subscription;

  List<Landmark> _latest = const [];
  DateTime? _latestAt;

  /// Orientación del último frame entregado. Es constante durante una sesión
  /// (la cámara no cambia de lente a mitad), así que sirve para convertir los
  /// resultados que llegan después por el stream.
  int _orientation = 0;

  @override
  Future<void> initialize() async {
    final plugin = hl.HandLandmarkerPlugin.create(
      numHands: 1,
      minHandDetectionConfidence: 0.6,
      delegate: hl.HandLandmarkerDelegate.gpu,
    );
    _plugin = plugin;
    _subscription = plugin.landmarkStream.listen(
      _onHands,
      onError: (Object _) {
        // Un error puntual del canal no debe tumbar la sesión: se deja que el
        // dato caduque por [_staleAfter] y se sigue entregando frames.
      },
    );
  }

  void _onHands(List<hl.Hand> hands) {
    _latest = hands.isEmpty
        ? const []
        : [
            for (final lm in hands.first.landmarks) _toUpright(lm, _orientation),
          ];
    _latestAt = DateTime.now();
  }

  @override
  Future<List<Landmark>> detect(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    final plugin = _plugin;
    if (plugin == null) return const [];

    _orientation = sensorOrientation;
    plugin.processFrame(frame, sensorOrientation);

    final at = _latestAt;
    if (at == null || DateTime.now().difference(at) > _staleAfter) {
      return const [];
    }
    return _latest;
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
    await _subscription?.cancel();
    _subscription = null;
    _plugin?.dispose();
    _plugin = null;
    _latest = const [];
    _latestAt = null;
  }
}
