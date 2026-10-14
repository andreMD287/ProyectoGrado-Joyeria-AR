import 'dart:async';

import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart' as hl;

import '../../../../core/math/geometry.dart';
import '../../../../core/vision/forearm_probe.dart';
import '../../domain/entities/landmark.dart';
import '../../domain/entities/landmark_frame.dart';
import '../repositories/tracking_repository_impl.dart';
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

  LandmarkFrame _latest = LandmarkFrame.empty;
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
    if (hands.isEmpty) {
      _latest = LandmarkFrame.empty;
      _latestAt = DateTime.now();
      return;
    }

    final hand = hands.first;
    _latest = LandmarkFrame(
      landmarks: [
        for (final lm in hand.landmarks) _toUpright(lm, _orientation),
      ],
      // Los puntos metricos vienen en los ejes del buffer del sensor, igual que
      // los normalizados, asi que necesitan la misma rotacion para quedar en el
      // marco vertical que usa el resto del pipeline.
      worldLandmarks: [
        for (final lm in hand.worldLandmarks)
          rotateVectorToUpright(
            v: Vec3(lm.x, lm.y, lm.z),
            rotationDegrees: _orientation,
          ),
      ],
    );
    _latestAt = DateTime.now();
  }

  @override
  Future<LandmarkFrame> detect(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    final plugin = _plugin;
    if (plugin == null) return LandmarkFrame.empty;

    _orientation = sensorOrientation;
    plugin.processFrame(frame, sensorOrientation);

    final at = _latestAt;
    if (at == null || DateTime.now().difference(at) > _staleAfter) {
      return LandmarkFrame.empty;
    }
    final latest = _latest;
    if (latest.isEmpty) return latest;

    // Los landmarks son de un frame algo anterior (el plugin los entrega por
    // su stream); el brazo se busca en este, que es el que se tiene. A la
    // frecuencia de detección la diferencia es de pocos píxeles, y la sonda
    // explora a ambos lados del eje.
    final sampler = _yuvSampler(frame, sensorOrientation);
    if (sampler == null) return latest;
    return LandmarkFrame(
      landmarks: latest.landmarks,
      worldLandmarks: latest.worldLandmarks,
      forearm: probeForearm(
        landmarks: latest.landmarks,
        sample: sampler,
        imageAspect: TrackingRepositoryImpl.uprightAspect(
          frame,
          sensorOrientation,
        ),
      ),
    );
  }

  /// Lector de color sobre el frame en YUV 4:2:0, en coordenadas del frame
  /// vertical. Solo se leen unos cientos de píxeles por frame, así que no se
  /// convierte la imagen: se va directo al byte.
  static YuvSampler? _yuvSampler(CameraImage frame, int sensorOrientation) {
    if (frame.planes.length < 3) return null;
    final yP = frame.planes[0], uP = frame.planes[1], vP = frame.planes[2];
    final w = frame.width, h = frame.height;
    final uStride = uP.bytesPerPixel ?? 1;
    final vStride = vP.bytesPerPixel ?? 1;

    return (x, y) {
      if (x < 0 || x >= 1 || y < 0 || y >= 1) return null;
      final b = uprightToBuffer(x: x, y: y, rotationDegrees: sensorOrientation);
      final bx = (b.x * w).floor().clamp(0, w - 1);
      final by = (b.y * h).floor().clamp(0, h - 1);
      final cx = bx >> 1, cy = by >> 1;
      final yi = by * yP.bytesPerRow + bx;
      final ui = cy * uP.bytesPerRow + cx * uStride;
      final vi = cy * vP.bytesPerRow + cx * vStride;
      if (yi >= yP.bytes.length ||
          ui >= uP.bytes.length ||
          vi >= vP.bytes.length) {
        return null;
      }
      return Yuv(yP.bytes[yi], uP.bytes[ui], vP.bytes[vi]);
    };
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
    _latest = LandmarkFrame.empty;
    _latestAt = null;
  }
}
