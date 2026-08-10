// Banco de comparación B4: One Euro Filter vs. Kalman de velocidad constante.
//
// Ejecuta escenarios sintéticos representativos del tracking (mano quieta,
// movimiento lento, cambio brusco) a 10 FPS —la tasa de detección del MVP—,
// aplica ambos filtros a una coordenada normalizada [0,1] y reporta métricas
// de jitter y de fidelidad/latencia. Incluye chequeos que fallan (exit != 0)
// si un filtro no reduce el jitter, para que sirva también como prueba.
//
//   dart run bin/b4_compare.dart

import 'dart:math' as math;

import 'package:b4_estabilizacion/one_euro_filter.dart';
import 'package:b4_estabilizacion/kalman_filter.dart';

const double fps = 10.0; // tasa de detección del MVP (throttle de 100 ms)
const double dt = 1.0 / fps;
const int n = 200; // ~20 s de señal
const double noiseSigma = 0.01; // jitter típico en coordenadas normalizadas

void main() {
  final rng = math.Random(42); // semilla fija ⇒ resultados reproducibles

  print('B4 — Estabilización del tracking · One Euro vs. Kalman');
  print('Muestreo: ${fps.toStringAsFixed(0)} FPS · N=$n · '
      'ruido σ=${noiseSigma.toStringAsFixed(3)} (coords normalizadas)\n');

  var ok = true;
  ok &= _scenarioStatic(rng);
  ok &= _scenarioSine(rng);
  ok &= _scenarioStep(rng);

  print('\n${ok ? "TODOS LOS CHEQUEOS PASARON" : "FALLÓ AL MENOS UN CHEQUEO"}');
  if (!ok) throw StateError('B4: algún filtro no cumplió el criterio esperado.');
}

// ── Escenario 1: mano quieta (solo ruido sobre una posición fija) ────────────
bool _scenarioStatic(math.Random rng) {
  const truth = 0.5;
  final t = <double>[];
  final raw = <double>[];
  for (var i = 0; i < n; i++) {
    t.add(i * dt);
    raw.add(truth + _gauss(rng) * noiseSigma);
  }

  final euro = _runEuro(raw, t, minCutoff: 1.0, beta: 0.02);
  final kal = _runKalman(raw, minCutoff_: null, pn: 1e-5, mn: 1e-4);

  final jRaw = _jitterRms(raw);
  final jEuro = _jitterRms(euro);
  final jKal = _jitterRms(kal);

  print('■ Escenario 1 — Mano quieta (posición fija = $truth)');
  _row('jitter RMS (Δ entre frames)', jRaw, jEuro, jKal, lowerIsBetter: true);
  _row('desv. resid. vs. verdad', _rmse(raw, truth), _rmse(euro, truth),
      _rmse(kal, truth),
      lowerIsBetter: true);

  final euroOk = jEuro < jRaw * 0.6; // debe reducir jitter ≥40%
  final kalOk = jKal < jRaw * 0.6;
  print('  → One Euro reduce jitter ${_pct(jRaw, jEuro)} · '
      'Kalman reduce jitter ${_pct(jRaw, jKal)}');
  _check('One Euro reduce ≥40% el jitter en reposo', euroOk);
  _check('Kalman reduce ≥40% el jitter en reposo', kalOk);
  print('');
  return euroOk && kalOk;
}

// ── Escenario 2: movimiento lento (seno 0.25 Hz) ─────────────────────────────
bool _scenarioSine(math.Random rng) {
  const freq = 0.25; // Hz
  const amp = 0.2;
  const offset = 0.5;
  double truthAt(double tt) => offset + amp * math.sin(2 * math.pi * freq * tt);

  final t = <double>[];
  final truth = <double>[];
  final raw = <double>[];
  for (var i = 0; i < n; i++) {
    final tt = i * dt;
    t.add(tt);
    truth.add(truthAt(tt));
    raw.add(truthAt(tt) + _gauss(rng) * noiseSigma);
  }

  final euro = _runEuro(raw, t, minCutoff: 1.0, beta: 0.02);
  final kal = _runKalman(raw, minCutoff_: null, pn: 1e-4, mn: 1e-3);

  final rmseRaw = _rmsePair(raw, truth);
  final rmseEuro = _rmsePair(euro, truth);
  final rmseKal = _rmsePair(kal, truth);

  print('■ Escenario 2 — Movimiento lento (seno ${freq}Hz, amp $amp)');
  _row('RMSE vs. verdad (lag+ruido)', rmseRaw, rmseEuro, rmseKal,
      lowerIsBetter: true);
  _row('jitter RMS (Δ entre frames)', _jitterRms(raw), _jitterRms(euro),
      _jitterRms(kal),
      lowerIsBetter: true);
  print('  nota: con ruido bajo, filtrar añade algo de lag → el RMSE-vs-verdad');
  print('        sube un poco; a cambio baja el jitter. Es el balance a ajustar.');

  // Invariantes reales en movimiento:
  //  (1) ambos filtros reducen el jitter entre frames respecto al crudo;
  //  (2) One Euro sigue la señal con menos lag que Kalman (RMSE menor) —
  //      su ventaja adaptativa frente al modelo de velocidad constante.
  final euroSmooths = _jitterRms(euro) < _jitterRms(raw);
  final kalSmooths = _jitterRms(kal) < _jitterRms(raw);
  final euroLessLag = rmseEuro <= rmseKal * 1.05;
  _check('One Euro reduce el jitter también en movimiento', euroSmooths);
  _check('Kalman reduce el jitter también en movimiento', kalSmooths);
  _check('One Euro sigue con menos (o igual) lag que Kalman', euroLessLag);
  print('');
  return euroSmooths && kalSmooths && euroLessLag;
}

// ── Escenario 3: cambio brusco (escalón) → mide latencia ─────────────────────
bool _scenarioStep(math.Random rng) {
  const before = 0.4, after = 0.6;
  const stepIdx = 50; // el escalón ocurre a los 5 s
  final t = <double>[];
  final truth = <double>[];
  final raw = <double>[];
  for (var i = 0; i < n; i++) {
    final tt = i * dt;
    final base = i < stepIdx ? before : after;
    t.add(tt);
    truth.add(base);
    raw.add(base + _gauss(rng) * noiseSigma);
  }

  final euro = _runEuro(raw, t, minCutoff: 1.0, beta: 0.02);
  final kal = _runKalman(raw, minCutoff_: null, pn: 1e-5, mn: 1e-4);

  final settleEuro = _settleFrames(euro, stepIdx, before, after);
  final settleKal = _settleFrames(kal, stepIdx, before, after);

  print('■ Escenario 3 — Cambio brusco (${before}→$after en t=5s)');
  print('  latencia hasta 90% del escalón:  '
      'One Euro=${_frames(settleEuro)} · Kalman=${_frames(settleKal)}');
  _row('jitter RMS (Δ entre frames)', _jitterRms(raw), _jitterRms(euro),
      _jitterRms(kal),
      lowerIsBetter: true);

  // Ambos deben converger en un tiempo razonable (< 1.5 s = 15 frames).
  final euroOk = settleEuro >= 0 && settleEuro <= 15;
  final kalOk = settleKal >= 0 && settleKal <= 15;
  _check('One Euro converge al escalón en < 1.5 s', euroOk);
  _check('Kalman converge al escalón en < 1.5 s', kalOk);
  print('');
  return euroOk && kalOk;
}

// ── Ejecución de filtros ─────────────────────────────────────────────────────
List<double> _runEuro(List<double> raw, List<double> t,
    {required double minCutoff, required double beta}) {
  final f = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: 1.0);
  return [for (var i = 0; i < raw.length; i++) f.filter(raw[i], t[i])];
}

List<double> _runKalman(List<double> raw,
    {double? minCutoff_, required double pn, required double mn}) {
  final f = KalmanFilter1D(processNoise: pn, measurementNoise: mn);
  return [for (final x in raw) f.filter(x, dt)];
}

// ── Métricas ─────────────────────────────────────────────────────────────────
double _jitterRms(List<double> s) {
  var acc = 0.0;
  for (var i = 1; i < s.length; i++) {
    final d = s[i] - s[i - 1];
    acc += d * d;
  }
  return math.sqrt(acc / (s.length - 1));
}

double _rmse(List<double> s, double truth) {
  var acc = 0.0;
  for (final v in s) {
    final d = v - truth;
    acc += d * d;
  }
  return math.sqrt(acc / s.length);
}

double _rmsePair(List<double> s, List<double> truth) {
  var acc = 0.0;
  for (var i = 0; i < s.length; i++) {
    final d = s[i] - truth[i];
    acc += d * d;
  }
  return math.sqrt(acc / s.length);
}

/// Número de frames tras [stepIdx] hasta alcanzar el 90% del salto. -1 si nunca.
int _settleFrames(List<double> s, int stepIdx, double before, double after) {
  final target = before + 0.9 * (after - before);
  for (var i = stepIdx; i < s.length; i++) {
    if (s[i] >= target) return i - stepIdx;
  }
  return -1;
}

// ── Ruido gaussiano (Box-Muller) ─────────────────────────────────────────────
double _gauss(math.Random rng) {
  final u1 = 1.0 - rng.nextDouble();
  final u2 = 1.0 - rng.nextDouble();
  return math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
}

// ── Impresión ────────────────────────────────────────────────────────────────
void _row(String label, double raw, double euro, double kal,
    {required bool lowerIsBetter}) {
  String f(double v) => v.toStringAsFixed(5);
  final best = lowerIsBetter
      ? math.min(euro, kal)
      : math.max(euro, kal);
  String tag(double v) => v == best ? ' *' : '  ';
  print('  ${label.padRight(30)}  raw=${f(raw)}   '
      'euro=${f(euro)}${tag(euro)}  kalman=${f(kal)}${tag(kal)}');
}

String _pct(double from, double to) {
  final r = (1 - to / from) * 100;
  return '${r.toStringAsFixed(1)}%';
}

String _frames(int fr) => fr < 0 ? 'no converge' : '$fr frames (${(fr * dt).toStringAsFixed(1)} s)';

void _check(String desc, bool pass) {
  print('  [${pass ? "OK" : "FALLA"}] $desc');
}
