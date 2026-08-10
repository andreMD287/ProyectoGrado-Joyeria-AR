import 'one_euro_filter.dart';
import 'kalman_filter.dart';

/// Punto 3D mínimo, compatible con las coordenadas (x, y, z) que entrega el
/// landmark de anclaje del tracking (p. ej. la muñeca / WRIST del MVP).
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)}, ${z.toStringAsFixed(4)})';
}

/// Interfaz común de estabilización, para poder intercambiar el filtro sin
/// tocar el código de anclaje.
abstract class LandmarkStabilizer {
  /// Filtra el punto [p] tomado en el instante [tSeconds] (reloj monótono,
  /// p. ej. `DateTime.now().millisecondsSinceEpoch / 1000`).
  Vec3 filter(Vec3 p, double tSeconds);
  void reset();
}

/// Estabilizador basado en One Euro Filter (un filtro por eje).
class OneEuroStabilizer implements LandmarkStabilizer {
  final OneEuroFilter _fx, _fy, _fz;

  OneEuroStabilizer({
    double minCutoff = 1.0,
    double beta = 0.007,
    double dCutoff = 1.0,
  })  : _fx = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff),
        _fy = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff),
        _fz = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff);

  @override
  Vec3 filter(Vec3 p, double tSeconds) => Vec3(
        _fx.filter(p.x, tSeconds),
        _fy.filter(p.y, tSeconds),
        _fz.filter(p.z, tSeconds),
      );

  @override
  void reset() {
    _fx.reset();
    _fy.reset();
    _fz.reset();
  }
}

/// Estabilizador basado en Kalman 1D de velocidad constante (un filtro por eje).
class KalmanStabilizer implements LandmarkStabilizer {
  final KalmanFilter1D _fx, _fy, _fz;
  double? _lastT;

  KalmanStabilizer({
    double processNoise = 1e-4,
    double measurementNoise = 1e-3,
  })  : _fx = KalmanFilter1D(
            processNoise: processNoise, measurementNoise: measurementNoise),
        _fy = KalmanFilter1D(
            processNoise: processNoise, measurementNoise: measurementNoise),
        _fz = KalmanFilter1D(
            processNoise: processNoise, measurementNoise: measurementNoise);

  @override
  Vec3 filter(Vec3 p, double tSeconds) {
    final dt = (_lastT == null || tSeconds <= _lastT!)
        ? 1.0 / 30.0
        : tSeconds - _lastT!;
    _lastT = tSeconds;
    return Vec3(
      _fx.filter(p.x, dt),
      _fy.filter(p.y, dt),
      _fz.filter(p.z, dt),
    );
  }

  @override
  void reset() {
    _fx.reset();
    _fy.reset();
    _fz.reset();
    _lastT = null;
  }
}
