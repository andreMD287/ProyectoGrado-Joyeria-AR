import 'dart:math' as math;
import 'dart:typed_data';

/// Trabajo CPU-bound que simula el costo de `detect()` de MediaPipe / ML Kit
/// (~15–40 ms por frame). Se usa idéntico en el baseline y en el isolate para
/// que la comparación sea justa.
double _busy(int iterations) {
  var acc = 0.0;
  for (var i = 0; i < iterations; i++) {
    acc += math.sqrt((i % 1000) + 1.0);
  }
  return acc;
}

/// Calibra cuántas iteraciones equivalen aproximadamente a [targetMs] en esta
/// máquina, para que la detección simulada tenga un costo realista.
int calibrateIterations(int targetMs) {
  var iters = 500000;
  while (true) {
    final sw = Stopwatch()..start();
    _busy(iters);
    sw.stop();
    if (sw.elapsedMicroseconds >= targetMs * 1000) return iters;
    iters *= 2;
  }
}

/// "Detecta" sobre un frame: consume CPU como `detect()` y devuelve 21 landmarks
/// simulados (x, y, z por punto = 63 dobles).
List<double> runDetection(Uint8List frame, int iterations) {
  final sink = _busy(iterations);
  final out = List<double>.filled(63, 0);
  out[0] = (frame.isNotEmpty ? frame[0] : 0) / 255.0;
  out[62] = sink % 1.0;
  return out;
}

/// Frame simulado (bytes YUV de ~640×480). Los bytes se transfieren al isolate
/// por SendPort, igual que se haría con el `CameraImage` real convertido a bytes.
Uint8List makeFrame({int size = 640 * 480}) => Uint8List(size);
