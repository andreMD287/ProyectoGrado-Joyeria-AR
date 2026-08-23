import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart'
    show CameraImageData, CameraImageFormat, CameraImagePlane;
import 'package:flutter/services.dart'
    show BackgroundIsolateBinaryMessenger, RootIsolateToken;

import '../../features/tracking/data/datasources/android_hand_detector.dart';
import '../../features/tracking/data/datasources/face_detector_datasource.dart';
import '../../features/tracking/data/datasources/ios_hand_detector.dart';
import '../../features/tracking/data/datasources/landmark_detector.dart';
import '../../features/tracking/data/datasources/pose_detector_datasource.dart';
import '../../features/tracking/domain/entities/landmark.dart';
import '../../features/tracking/domain/strategies/tracking_strategy.dart'
    show DetectorKind;

/// Formato de imagen de cámara que necesita cada [DetectorKind]: los
/// detectores basados en ML Kit (`InputImage.fromBytes`) requieren un solo
/// plano (`nv21` en Android, `bgra8888` en iOS); `hand_landmarker`
/// (MediaPipe vía JNI) requiere `yuv420`.
ImageFormatGroup imageFormatGroupFor(DetectorKind kind) => switch (kind) {
      DetectorKind.hand =>
        Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      DetectorKind.face ||
      DetectorKind.pose =>
        Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    };

class _StartMessage {
  final SendPort replyTo;
  final RootIsolateToken token;
  final DetectorKind kind;
  const _StartMessage(this.replyTo, this.token, this.kind);
}

class _DetectRequest {
  final int id;
  final CameraImageData frame;
  final int sensorOrientation;
  const _DetectRequest(this.id, this.frame, this.sensorOrientation);
}

class _DetectResponse {
  final int id;
  final List<Landmark> landmarks;
  const _DetectResponse(this.id, this.landmarks);
}

class _StopMessage {
  const _StopMessage();
}

class _StopAck {
  const _StopAck();
}

/// Isolate dedicado de detección (spike B5 portado con el detector real):
/// aloja la instancia del [LandmarkDetector] que corresponda según
/// [DetectorKind] y la plataforma, y procesa cada frame fuera del isolate
/// principal para no bloquear la UI. Cada llamada a [start] crea un isolate
/// nuevo con su propia instancia del detector; se destruye con [dispose].
///
/// `CameraImage` no es transferible entre isolates directamente: se envían
/// sus campos primitivos como [CameraImageData] (deep copy vía `SendPort`) y
/// se reconstruye con `CameraImage.fromPlatformInterface` dentro del isolate.
class DetectionIsolate {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  final Map<int, Completer<List<Landmark>>> _pending = {};
  int _seq = 0;
  Completer<void>? _stopAck;

  Future<void> start(DetectorKind kind) async {
    final token = RootIsolateToken.instance;
    if (token == null) {
      throw StateError('RootIsolateToken no disponible.');
    }
    final receivePort = ReceivePort();
    _receivePort = receivePort;
    final ready = Completer<SendPort>();
    receivePort.listen((Object? msg) {
      if (msg is SendPort) {
        ready.complete(msg);
      } else if (msg is _DetectResponse) {
        _pending.remove(msg.id)?.complete(msg.landmarks);
      } else if (msg is _StopAck) {
        _stopAck?.complete();
      }
    });
    _isolate = await Isolate.spawn(
      _entry,
      _StartMessage(receivePort.sendPort, token, kind),
    );
    _sendPort = await ready.future;
  }

  /// Envía un frame al isolate y espera los landmarks detectados.
  Future<List<Landmark>> detect(CameraImage frame, int sensorOrientation) {
    final sendPort = _sendPort;
    if (sendPort == null) return Future.value(const []);
    final id = _seq++;
    final completer = Completer<List<Landmark>>();
    _pending[id] = completer;
    sendPort.send(_DetectRequest(id, _toPlatformData(frame), sensorOrientation));
    return completer.future;
  }

  /// Le pide al isolate que se detenga y espera su confirmación antes de
  /// matarlo. Es necesario esperar (con límite de tiempo): algunos
  /// detectores (p. ej. [IosHandDetector]) hacen una llamada de vuelta a
  /// nativo en `dispose()`, y matar el isolate mientras esa respuesta está
  /// en camino provoca un crash fatal del motor de Flutter (`did_send`
  /// check failed) en vez de una excepción manejable.
  Future<void> dispose() async {
    final sendPort = _sendPort;
    if (sendPort != null) {
      final ack = Completer<void>();
      _stopAck = ack;
      sendPort.send(const _StopMessage());
      await ack.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    }
    _stopAck = null;
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.complete(const []);
    }
    _pending.clear();
  }

  static CameraImageData _toPlatformData(CameraImage image) => CameraImageData(
        format: CameraImageFormat(image.format.group, raw: image.format.raw),
        height: image.height,
        width: image.width,
        planes: [
          for (final plane in image.planes)
            CameraImagePlane(
              bytes: plane.bytes,
              bytesPerRow: plane.bytesPerRow,
              bytesPerPixel: plane.bytesPerPixel,
              height: plane.height,
              width: plane.width,
            ),
        ],
        lensAperture: image.lensAperture,
        sensorExposureTime: image.sensorExposureTime,
        sensorSensitivity: image.sensorSensitivity,
      );

  static LandmarkDetector _createDetector(DetectorKind kind) => switch (kind) {
        DetectorKind.hand =>
          Platform.isIOS ? IosHandDetector() : AndroidHandDetector(),
        DetectorKind.face => FaceDetectorDataSource(),
        DetectorKind.pose => PoseDetectorDataSource(),
      };

  static void _entry(_StartMessage start) async {
    // Necesario para que los detectores basados en platform channels (ML
    // Kit) funcionen fuera del isolate principal.
    BackgroundIsolateBinaryMessenger.ensureInitialized(start.token);

    final detector = _createDetector(start.kind);
    await detector.initialize();

    final port = ReceivePort();
    start.replyTo.send(port.sendPort);

    await for (final msg in port) {
      if (msg is _StopMessage) {
        await detector.dispose();
        start.replyTo.send(const _StopAck());
        port.close();
        break;
      }
      if (msg is _DetectRequest) {
        try {
          final frame = CameraImage.fromPlatformInterface(msg.frame);
          final landmarks = await detector.detect(frame, msg.sensorOrientation);
          start.replyTo.send(_DetectResponse(msg.id, landmarks));
        } catch (_) {
          start.replyTo.send(_DetectResponse(msg.id, const []));
        }
      }
    }
  }
}
