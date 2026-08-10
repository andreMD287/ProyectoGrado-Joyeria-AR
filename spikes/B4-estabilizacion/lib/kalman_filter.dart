/// Filtro de Kalman 1D con modelo de velocidad constante.
///
/// Estado x = [posición, velocidad]ᵀ. Medición z = posición.
///   Predicción:  x = F·x           P = F·P·Fᵀ + Q
///   Actualización: y = z - H·x      S = H·P·Hᵀ + R
///                  K = P·Hᵀ·S⁻¹     x = x + K·y     P = (I - K·H)·P
/// con F = [[1, dt], [0, 1]] y H = [1, 0].
///
/// Q (ruido de proceso) se aproxima como diag([q, q]) por simplicidad; un
/// modelo más riguroso usaría el de aceleración de ruido blanco. Suficiente
/// para el spike.
///
/// Parámetros a ajustar (para coordenadas normalizadas [0,1]):
/// - [processNoise] (q): confianza en el modelo de movimiento. Mayor ⇒ sigue
///   más rápido, filtra menos.
/// - [measurementNoise] (r): ruido asumido de la medición. Mayor ⇒ suaviza
///   más, pero con más lag. Aproximadamente la varianza del jitter observado.
class KalmanFilter1D {
  double processNoise;
  double measurementNoise;

  double _x = 0, _v = 0; // estado
  double _p00 = 1, _p01 = 0, _p10 = 0, _p11 = 1; // covarianza P
  bool _initialized = false;

  KalmanFilter1D({
    this.processNoise = 1e-4,
    this.measurementNoise = 1e-3,
  });

  /// Filtra la medición [z] con paso de tiempo [dt] (segundos) respecto a la
  /// muestra anterior.
  double filter(double z, double dt) {
    if (!_initialized) {
      _x = z;
      _v = 0;
      _initialized = true;
      return _x;
    }

    // ── Predicción ──────────────────────────────────────────────────────
    _x = _x + dt * _v; // F·x

    // P = F·P·Fᵀ + Q
    final a00 = _p00 + dt * _p10;
    final a01 = _p01 + dt * _p11;
    final a10 = _p10;
    final a11 = _p11;
    _p00 = a00 + dt * a01 + processNoise;
    _p01 = a01;
    _p10 = a10 + dt * a11;
    _p11 = a11 + processNoise;

    // ── Actualización ───────────────────────────────────────────────────
    final y = z - _x; // innovación (H = [1,0])
    final s = _p00 + measurementNoise; // S = H·P·Hᵀ + R
    final k0 = _p00 / s; // ganancia de Kalman
    final k1 = _p10 / s;

    _x = _x + k0 * y;
    _v = _v + k1 * y;

    // P = (I - K·H)·P
    final p00 = _p00, p01 = _p01, p10 = _p10, p11 = _p11;
    _p00 = (1 - k0) * p00;
    _p01 = (1 - k0) * p01;
    _p10 = p10 - k1 * p00;
    _p11 = p11 - k1 * p01;

    return _x;
  }

  void reset() {
    _x = 0;
    _v = 0;
    _p00 = 1;
    _p01 = 0;
    _p10 = 0;
    _p11 = 1;
    _initialized = false;
  }
}
