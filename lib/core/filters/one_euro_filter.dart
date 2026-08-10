import 'dart:math' as math;

/// Filtro pasa-bajos exponencial de primer orden.
class _LowPassFilter {
  double? _hatXPrev;

  bool get hasLastValue => _hatXPrev != null;
  double get lastValue => _hatXPrev!;

  double filter(double x, double alpha) {
    final hatX = hasLastValue ? alpha * x + (1 - alpha) * _hatXPrev! : x;
    _hatXPrev = hatX;
    return hatX;
  }

  void reset() => _hatXPrev = null;
}

/// One Euro Filter (Casiez, Roussel & Vogel, CHI 2012), implementación 1D.
///
/// Filtro adaptativo para señales interactivas ruidosas: baja la frecuencia de
/// corte cuando la señal está casi quieta (menos jitter) y la sube cuando se
/// mueve rápido (menos latencia). Recomendado para estabilizar landmarks
/// (ver spike B4).
class OneEuroFilter {
  double minCutoff;
  double beta;
  double dCutoff;

  final _LowPassFilter _x = _LowPassFilter();
  final _LowPassFilter _dx = _LowPassFilter();
  double? _lastTime;
  double? _lastRawX;

  OneEuroFilter({
    this.minCutoff = 1.0,
    this.beta = 0.02,
    this.dCutoff = 1.0,
  });

  static double _alpha(double cutoff, double dt) {
    final tau = 1.0 / (2 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }

  double filter(double x, double tSeconds) {
    double dt;
    if (_lastTime == null || tSeconds <= _lastTime!) {
      dt = 1.0 / 30.0;
    } else {
      dt = tSeconds - _lastTime!;
    }
    _lastTime = tSeconds;

    final rawDx = _lastRawX == null ? 0.0 : (x - _lastRawX!) / dt;
    _lastRawX = x;

    final edx = _dx.filter(rawDx, _alpha(dCutoff, dt));
    final cutoff = minCutoff + beta * edx.abs();
    return _x.filter(x, _alpha(cutoff, dt));
  }

  void reset() {
    _x.reset();
    _dx.reset();
    _lastTime = null;
    _lastRawX = null;
  }
}
