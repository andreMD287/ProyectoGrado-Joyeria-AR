import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'detection_workload.dart';

/// Petición de detección enviada al isolate.
class DetectionRequest {
  final int id;
  final Uint8List frame;
  final int iterations;
  const DetectionRequest(this.id, this.frame, this.iterations);
}

/// Respuesta con los landmarks detectados.
class DetectionResponse {
  final int id;
  final List<double> landmarks;
  const DetectionResponse(this.id, this.landmarks);
}

/// Isolate dedicado de detección: mantiene su propia instancia del detector y
/// procesa los frames que llegan por `SendPort`, devolviendo los landmarks. Así
/// el trabajo pesado no bloquea el isolate principal (UI).
///
/// Es el espejo del componente que irá en `lib/core/isolate/detection_isolate.dart`
/// del proyecto real. Restricción documentada: `CameraImage` no es transferible
/// entre isolates directamente; se envían sus bytes (planos YUV). Los detectores
/// vía platform channels (ML Kit) requieren además inicializar
/// `BackgroundIsolateBinaryMessenger` con el `RootIsolateToken` dentro del
/// isolate; `hand_landmarker` (JNI) es más autónomo.
class DetectionIsolate {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  final Completer<void> _ready = Completer<void>();
  final Map<int, Completer<List<double>>> _pending = {};
  int _seq = 0;

  Future<void> start() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_entry, _receivePort!.sendPort);
    _receivePort!.listen((Object? msg) {
      if (msg is SendPort) {
        _sendPort = msg;
        _ready.complete();
      } else if (msg is DetectionResponse) {
        _pending.remove(msg.id)?.complete(msg.landmarks);
      }
    });
    await _ready.future;
  }

  /// Envía un frame y devuelve los landmarks cuando el isolate responde.
  Future<List<double>> detect(Uint8List frame, int iterations) {
    final id = _seq++;
    final completer = Completer<List<double>>();
    _pending[id] = completer;
    _sendPort!.send(DetectionRequest(id, frame, iterations));
    return completer.future;
  }

  void dispose() {
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
  }

  /// Punto de entrada del isolate: crea su instancia del detector (aquí, el
  /// workload simulado) y atiende peticiones.
  static void _entry(SendPort mainSendPort) {
    final port = ReceivePort();
    mainSendPort.send(port.sendPort);
    port.listen((Object? msg) {
      if (msg is DetectionRequest) {
        final landmarks = runDetection(msg.frame, msg.iterations);
        mainSendPort.send(DetectionResponse(msg.id, landmarks));
      }
    });
  }
}
