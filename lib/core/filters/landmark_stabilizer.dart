import '../math/geometry.dart';
import 'one_euro_filter.dart';

/// Interfaz común de estabilización, para intercambiar el filtro sin tocar el
/// código de anclaje. Ver comparación y recomendación en el spike B4.
abstract interface class LandmarkStabilizer {
  /// Filtra el punto [p] tomado en el instante [tSeconds] (reloj monótono).
  Vec3 filter(Vec3 p, double tSeconds);
  void reset();
}

/// Estabilizador basado en One Euro Filter (un filtro por eje). Recomendado.
class OneEuroStabilizer implements LandmarkStabilizer {
  final OneEuroFilter _fx, _fy, _fz;

  OneEuroStabilizer({
    double minCutoff = 1.0,
    double beta = 0.02,
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
