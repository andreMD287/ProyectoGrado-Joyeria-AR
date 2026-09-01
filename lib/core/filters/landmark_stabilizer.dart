import 'dart:math' as math;

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

/// Estabilizador de una magnitud escalar (p. ej. la escala aparente de la
/// pieza), con el mismo One Euro Filter que usa la posición.
class ScalarStabilizer {
  final OneEuroFilter _filter;

  ScalarStabilizer({
    double minCutoff = 1.0,
    double beta = 0.02,
    double dCutoff = 1.0,
  }) : _filter =
            OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff);

  double filter(double value, double tSeconds) =>
      _filter.filter(value, tSeconds);

  void reset() => _filter.reset();
}

/// Estabilizador de un ángulo, en radianes.
///
/// Filtrar el ángulo directamente produce un salto brusco cada vez que cruza
/// ±π (el filtro interpola entre +3.14 y -3.14 pasando por 0, girando la pieza
/// media vuelta). Se filtran en su lugar el coseno y el seno —que son
/// continuos— y se recompone el ángulo con `atan2`.
class AngleStabilizer {
  final OneEuroFilter _cos, _sin;

  AngleStabilizer({
    double minCutoff = 1.0,
    double beta = 0.02,
    double dCutoff = 1.0,
  })  : _cos =
            OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff),
        _sin =
            OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff);

  double filter(double radians, double tSeconds) {
    final c = _cos.filter(math.cos(radians), tSeconds);
    final s = _sin.filter(math.sin(radians), tSeconds);
    return math.atan2(s, c);
  }

  void reset() {
    _cos.reset();
    _sin.reset();
  }
}
