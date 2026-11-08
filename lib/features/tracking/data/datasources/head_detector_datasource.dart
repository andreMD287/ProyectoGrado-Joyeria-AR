import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show MethodChannel;

import '../../../../core/math/head_geometry.dart';
import '../../domain/entities/head_observation.dart';
import '../../domain/entities/landmark.dart';
import '../../domain/entities/landmark_frame.dart';
import 'landmark_detector.dart';

/// Puntos de la malla facial que entrega `NeckTracker` en modo cabeza, **en
/// este orden**. Tiene que coincidir con `HEAD_POINTS` en `NeckTracker.kt`.
///
/// Mejillas delante de cada oreja (234, 454), frente (10), mentón (152),
/// nariz (1, 2), rabillos de los ojos (33, 263) y el contorno de la cara hacia
/// la mandíbula a cada lado (93/323, 132/361, 58/288), que es lo que se mira
/// para calibrar el lóbulo.
@visibleForTesting
const List<int> headMeshPoints = [
  234, 454, 10, 152, 1, 2, 33, 263, 93, 323, 132, 361, 58, 288, //
];

/// Cabeza para aretes, medida con MediaPipe Face Landmarker por `NeckTracker`
/// en modo `head`. **Solo Android**: en iOS los aretes siguen con ML Kit Face
/// (ver `createLandmarkDetector`).
///
/// Usa el mismo canal y la misma tubería que los collares (ver
/// `NeckDetectorDataSource`): se entrega el frame y vuelve enseguida el último
/// resultado; uno ya entregado vuelve vacío. En este modo el nativo no
/// segmenta, que es la parte pesada.
class HeadDetectorDataSource implements LandmarkDetector {
  static const _channel = MethodChannel('jewelry_ar/neck');

  int? _lastSeq;

  @override
  Future<void> initialize() =>
      _channel.invokeMethod<void>('start', {'mode': 'head'});

  @override
  Future<LandmarkFrame> detect(CameraImage frame, int sensorOrientation) async {
    if (frame.planes.length != 1) return LandmarkFrame.empty;
    final plane = frame.planes.first;
    final result = await _channel.invokeMapMethod<String, Object?>('process', {
      'bytes': plane.bytes,
      'width': frame.width,
      'height': frame.height,
      'stride': plane.bytesPerRow,
      'rotation': sensorOrientation,
    });
    if (result == null) return LandmarkFrame.empty;
    final seq = (result['seq'] as num?)?.toInt();
    if (seq != null && seq == _lastSeq) return LandmarkFrame.empty;
    _lastSeq = seq;
    return headFrameFromNative(result, sensorOrientation);
  }

  @override
  Future<void> dispose() => _channel.invokeMethod<void>('stop');
}

/// Convierte la respuesta de `NeckTracker` en modo cabeza al espacio de la
/// vista previa.
///
/// El nativo entrega el frame vertical **sin espejar**, y la vista previa de
/// la cámara frontal va espejada salvo con el sensor a 90°: el mismo criterio
/// que `neckFrameFromNative`. Al espejar se invierte la x de los puntos y se
/// conjuga la rotación (ver [HeadAxes.mirrored]). [mirror] lo fuerza.
///
/// [LandmarkFrame.landmarks] lleva los mismos puntos, para que el overlay de
/// diagnóstico los dibuje.
@visibleForTesting
LandmarkFrame headFrameFromNative(
  Map<String, Object?> result,
  int sensorOrientation, {
  bool? mirror,
}) {
  if (result['face'] != true) return LandmarkFrame.empty;
  final raw = result['points'];
  if (raw is! List || raw.length < headMeshPoints.length * 3) {
    return LandmarkFrame.empty;
  }

  final rotation = ((sensorOrientation % 360) + 360) % 360;
  final espejar = mirror ?? rotation != 90;

  final points = <int, Landmark>{};
  for (var k = 0; k < headMeshPoints.length; k++) {
    final x = (raw[k * 3] as num).toDouble();
    points[headMeshPoints[k]] = Landmark(
      espejar ? 1 - x : x,
      (raw[k * 3 + 1] as num).toDouble(),
      (raw[k * 3 + 2] as num).toDouble(),
    );
  }

  HeadAxes? axes;
  final matrix = result['matrix'];
  if (matrix is List && matrix.length == 16) {
    final m = headAxesFromMatrix([for (final v in matrix) (v as num).toDouble()]);
    axes = espejar ? m?.mirrored() : m;
  }

  return LandmarkFrame(
    landmarks: [for (final i in headMeshPoints) points[i]!],
    head: HeadObservation(points: points, axes: axes, mirrored: espejar),
  );
}
