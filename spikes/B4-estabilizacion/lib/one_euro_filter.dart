import 'dart:math' as math;

/// Filtro pasa-bajos exponencial de primer orden.
///
///   ŷ_i = α·x_i + (1 - α)·ŷ_{i-1}
///
/// El coeficiente α se calcula por frame en función de la frecuencia de corte
/// y del paso de tiempo (dt), por eso se pasa como argumento en cada llamada.
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
/// Filtro adaptativo pensado para señales interactivas ruidosas: baja la
/// frecuencia de corte cuando la señal está casi quieta (más suavizado, menos
/// jitter) y la sube cuando la señal se mueve rápido (menos latencia). Es la
/// referencia habitual para estabilizar landmarks de tracking en tiempo real.
///
/// Parámetros a ajustar:
/// - [minCutoff] (Hz): frecuencia de corte mínima. Menor ⇒ más suavizado en
///   reposo, pero más lag. Punto de partida típico: 1.0.
/// - [beta]: cuánto sube el corte con la velocidad. Mayor ⇒ menos lag al mover,
///   pero deja pasar más jitter. Punto de partida típico: 0.005–0.05.
/// - [dCutoff] (Hz): corte del filtro de la derivada. Normalmente 1.0.
class OneEuroFilter {
  double minCutoff;
  double beta;
  double dCutoff;

  final _LowPassFilter _x = _LowPassFilter();
  final _LowPassFilter _dx = _LowPassFilter();
  double? _lastTime; // segundos
  double? _lastRawX;

  OneEuroFilter({
    this.minCutoff = 1.0,
    this.beta = 0.007,
    this.dCutoff = 1.0,
  });

  static double _alpha(double cutoff, double dt) {
    final tau = 1.0 / (2 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }

  /// Filtra la muestra [x] tomada en el instante [tSeconds] (reloj monótono).
  double filter(double x, double tSeconds) {
    double dt;
    if (_lastTime == null || tSeconds <= _lastTime!) {
      dt = 1.0 / 30.0; // valor por defecto para el primer frame o dt inválido
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
