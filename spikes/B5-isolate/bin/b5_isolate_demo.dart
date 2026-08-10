// Banco de comparación B5: detección síncrona en el isolate principal
// (baseline) vs. detección en un isolate dedicado.
//
// Mide, durante una ventana fija, cuántas detecciones se completan y cuántos
// "ticks de UI" (un Timer a 60 FPS = 16 ms) logra ejecutar el event loop del
// isolate principal. La clave: con detección síncrona el event loop queda
// bloqueado (UI congelada); con el isolate dedicado la UI sigue fluida.
//
//   dart run bin/b5_isolate_demo.dart

import 'dart:async';

import 'package:b5_isolate/detection_isolate.dart';
import 'package:b5_isolate/detection_workload.dart';

const int uiTickMs = 16; // objetivo 60 FPS de UI
const int benchMs = 2000; // ventana de medición por escenario

late final int _iterations;

class _Bench {
  final int detections;
  final int uiTicks;
  final int elapsedMs;
  const _Bench(this.detections, this.uiTicks, this.elapsedMs);
  double get detFps => detections * 1000 / elapsedMs;
  double get uiFps => uiTicks * 1000 / elapsedMs;
}

Future<void> main() async {
  print('B5 — Isolate dedicado de detección');
  _iterations = calibrateIterations(25);
  final oneMs = _measureOne();
  print('Detección simulada ≈ ${oneMs.toStringAsFixed(1)} ms/frame '
      '(techo teórico ${(1000 / oneMs).toStringAsFixed(0)} FPS de detección)\n');

  final baseline = await _runBaseline();
  final iso = await _runWithIsolate();

  print('■ Baseline — detección SÍNCRONA en el isolate principal');
  _report(baseline);
  print('■ Con isolate dedicado — detección en paralelo');
  _report(iso);

  print('Resumen:');
  print('  UI (event loop):  baseline ${baseline.uiFps.toStringAsFixed(1)} FPS'
      '  →  isolate ${iso.uiFps.toStringAsFixed(1)} FPS');
  print('  Detección:        baseline ${baseline.detFps.toStringAsFixed(1)} FPS'
      '  →  isolate ${iso.detFps.toStringAsFixed(1)} FPS');

  var ok = true;
  ok &= _check('El isolate mantiene la UI responsiva (>30 FPS)', iso.uiFps > 30);
  ok &= _check('El baseline bloquea la UI (<5 FPS)', baseline.uiFps < 5);
  ok &= _check('El isolate preserva el throughput de detección (>50% del baseline)',
      iso.detFps > baseline.detFps * 0.5);

  print('\n${ok ? "TODOS LOS CHEQUEOS PASARON" : "FALLÓ ALGÚN CHEQUEO"}');
  if (!ok) throw StateError('B5: no se cumplió el resultado esperado.');
}

double _measureOne() {
  final frame = makeFrame();
  final sw = Stopwatch()..start();
  runDetection(frame, _iterations);
  sw.stop();
  return sw.elapsedMicroseconds / 1000;
}

// Detección síncrona: el bucle no cede el event loop → la UI se congela.
Future<_Bench> _runBaseline() async {
  var det = 0, ui = 0;
  final timer = Timer.periodic(const Duration(milliseconds: uiTickMs), (_) => ui++);
  final frame = makeFrame();
  final sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < benchMs) {
    runDetection(frame, _iterations);
    det++;
  }
  sw.stop();
  timer.cancel();
  return _Bench(det, ui, sw.elapsedMilliseconds);
}

// Detección en isolate: cada `await` cede el event loop → la UI sigue fluida.
Future<_Bench> _runWithIsolate() async {
  final detector = DetectionIsolate();
  await detector.start();
  var det = 0, ui = 0;
  final timer = Timer.periodic(const Duration(milliseconds: uiTickMs), (_) => ui++);
  final frame = makeFrame();
  final sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < benchMs) {
    await detector.detect(frame, _iterations);
    det++;
  }
  sw.stop();
  timer.cancel();
  detector.dispose();
  return _Bench(det, ui, sw.elapsedMilliseconds);
}

void _report(_Bench b) {
  print('  detecciones: ${b.detections}  (${b.detFps.toStringAsFixed(1)} FPS)');
  print('  ticks de UI: ${b.uiTicks}  (${b.uiFps.toStringAsFixed(1)} FPS)\n');
}

bool _check(String desc, bool pass) {
  print('  [${pass ? "OK" : "FALLA"}] $desc');
  return pass;
}
