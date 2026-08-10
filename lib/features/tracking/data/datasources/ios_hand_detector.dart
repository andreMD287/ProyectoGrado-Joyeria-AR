import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../../../../core/platform/platform_channels.dart';
import '../../domain/entities/landmark.dart';
import 'hand_detector.dart';

/// Detector de manos en iOS. `hand_landmarker` no soporta iOS (usa JNI), por lo
/// que aquí se consume una implementación nativa vía platform channel
/// (`PlatformChannels.iosHandTracking`). La alternativa recomendada en el spike
/// B1 es **Apple Vision** (`VNDetectHumanHandPoseRequest`).
///
/// Contrato con la capa nativa:
/// - `start` / `stop`: inicializan y liberan la petición de Vision.
/// - `detect`: recibe los bytes del frame + metadatos y devuelve una lista plana
///   `[x, y, confidence] × 21` en orden MediaPipe (índice 0 = muñeca), con x,y
///   normalizados [0,1] y origen arriba-izquierda; lista vacía si no hay mano.
///
/// La implementación nativa (Swift) y su registro están en
/// `spikes/B1-ios-hand-tracking/`. Pendiente de validación en un iPhone físico.
class IosHandDetector implements HandDetector {
  static const MethodChannel _channel =
      MethodChannel(PlatformChannels.iosHandTracking);

  @override
  Future<void> initialize() async {
    await _channel.invokeMethod<void>('start');
  }

  @override
  Future<List<Landmark>> detect(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    if (frame.planes.isEmpty) return const [];
    final plane = frame.planes.first;

    final result = await _channel.invokeMethod<List<Object?>>('detect', {
      'bytes': plane.bytes,
      'width': frame.width,
      'height': frame.height,
      'bytesPerRow': plane.bytesPerRow,
      'rotation': sensorOrientation,
    });
    if (result == null) return const [];

    return mapVisionLandmarks(
      result.cast<num>().map((n) => n.toDouble()).toList(),
    );
  }

  @override
  Future<void> dispose() async {
    await _channel.invokeMethod<void>('stop');
  }
}

/// Convierte la lista plana `[x, y, confidence] × 21` que entrega la capa nativa
/// (Vision) en landmarks. Vision es 2D: `z = 0` y la confianza va en
/// `visibility`. Función pura para poder probarla sin dispositivo.
List<Landmark> mapVisionLandmarks(List<double> flat) {
  final landmarks = <Landmark>[];
  for (var i = 0; i + 2 < flat.length; i += 3) {
    landmarks.add(Landmark(flat[i], flat[i + 1], 0, visibility: flat[i + 2]));
  }
  return landmarks;
}
