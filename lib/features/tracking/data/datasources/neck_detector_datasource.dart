import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show MethodChannel;

import '../../domain/entities/landmark.dart';
import '../../domain/entities/landmark_frame.dart';
import '../../domain/entities/neck_observation.dart';
import 'landmark_detector.dart';

/// Cara y cuello para collares, medidos con MediaPipe (Face Landmarker +
/// segmentación multiclase) por `NeckTracker` en Android y
/// `NeckTrackingHandler` en iOS, con el mismo protocolo de canal.
///
/// Va en tubería: se entrega el frame y vuelve enseguida el **último**
/// resultado del nativo, que procesa siempre el frame más reciente. Cada
/// resultado trae un número de secuencia; uno ya entregado vuelve como vacío,
/// para no alimentar los filtros con muestras repetidas. Funciona desde el
/// isolate de detección porque solo hace llamadas salientes al canal, que el
/// isolate secundario sí admite.
class NeckDetectorDataSource implements LandmarkDetector {
  static const _channel = MethodChannel('jewelry_ar/neck');

  int? _lastSeq;

  @override
  Future<void> initialize() => _channel.invokeMethod<void>('start');

  @override
  Future<LandmarkFrame> detect(CameraImage frame, int sensorOrientation) async {
    // nv21 llega en un solo plano: luminancia y croma intercalada detrás.
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
    // En iOS la cámara ya entrega el frame vertical y espejado como la vista
    // previa (igual que asume ML Kit ahí), así que no se espeja de nuevo.
    return neckFrameFromNative(
      result,
      sensorOrientation,
      mirror: Platform.isIOS ? false : null,
    );
  }

  @override
  Future<void> dispose() => _channel.invokeMethod<void>('stop');
}

/// Convierte la respuesta de `NeckTracker` al espacio de la vista previa.
///
/// En Android el nativo entrega el frame vertical **sin espejar**. La vista
/// previa de la cámara frontal sí va espejada, salvo con el sensor a 90°: es
/// el mismo criterio que `normalizeMlKitLandmarkToPreview`, con el que se
/// validaron aretes y collares. [mirror] lo fuerza (iOS: `false`).
///
/// Además de [LandmarkFrame.neck], llena [LandmarkFrame.landmarks] con los
/// puntos medidos (mentón, mejillas, nariz y, si hay cuello, sus bordes y el
/// escote) para que el overlay de diagnóstico los dibuje.
@visibleForTesting
LandmarkFrame neckFrameFromNative(
  Map<String, Object?> result,
  int sensorOrientation, {
  bool? mirror,
}) {
  if (result['face'] != true) return LandmarkFrame.empty;
  final points = result['points'];
  final faceWidth = (result['faceWidth'] as num?)?.toDouble();
  if (points is! List || points.length < 12 || faceWidth == null) {
    return LandmarkFrame.empty;
  }

  final rotation = ((sensorOrientation % 360) + 360) % 360;
  final espejar = mirror ?? rotation != 90;
  double mx(double x) => espejar ? 1 - x : x;

  Landmark punto(int i) => Landmark(
        mx((points[i * 3] as num).toDouble()),
        (points[i * 3 + 1] as num).toDouble(),
        (points[i * 3 + 2] as num).toDouble(),
      );

  final chin = punto(0);
  final a = punto(1), b = punto(2);
  final (cheekLeft, cheekRight) = a.x <= b.x ? (a, b) : (b, a);
  final nose = punto(3);

  NeckShape? neck;
  final raw = result['neck'];
  if (raw is Map) {
    double? v(String k) => (raw[k] as num?)?.toDouble();
    final lx = v('leftX'), ly = v('leftY'), rx = v('rightX'), ry = v('rightY');
    final refX = v('refChinX'), refY = v('refChinY'), refW = v('refFaceWidth');
    if (lx != null &&
        ly != null &&
        rx != null &&
        ry != null &&
        refX != null &&
        refY != null &&
        refW != null) {
      // Al espejar, el borde izquierdo de la imagen pasa a la derecha.
      final p1 = (x: mx(lx), y: ly), p2 = (x: mx(rx), y: ry);
      final (izq, der) = p1.x <= p2.x ? (p1, p2) : (p2, p1);
      final hasFront = raw['hasFront'] == true;
      neck = NeckShape(
        leftX: izq.x,
        leftY: izq.y,
        rightX: der.x,
        rightY: der.y,
        frontX: hasFront ? mx(v('frontX') ?? 0.5) : null,
        frontY: hasFront ? v('frontY') : null,
        narrowWidth: v('narrow') ?? 0,
        columnX: (v('columnX') ?? -1) < 0 ? null : mx(v('columnX')!),
        refChinX: mx(refX),
        refChinY: refY,
        refFaceWidth: refW,
      );
    }
  }

  return LandmarkFrame(
    landmarks: [
      chin,
      cheekLeft,
      cheekRight,
      nose,
      if (neck != null) ...[
        Landmark(neck.leftX, neck.leftY, 0),
        Landmark(neck.rightX, neck.rightY, 0),
        if (neck.frontX != null) Landmark(neck.frontX!, neck.frontY!, 0),
      ],
    ],
    neck: NeckObservation(
      chin: chin,
      cheekLeft: cheekLeft,
      cheekRight: cheekRight,
      nose: nose,
      faceWidth: faceWidth,
      neck: neck,
    ),
  );
}
