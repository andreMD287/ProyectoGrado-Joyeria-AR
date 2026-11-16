import 'dart:math' as math;

import 'geometry.dart';

/// Péndulo amortiguado para los aretes que cuelgan del lóbulo.
///
/// La masa cuelga a [length] metros del punto de sujeción, que se mueve con la
/// cabeza. Al moverlo, la masa se queda atrás y oscila hasta volver a colgar
/// hacia abajo; es lo que hace que el arete se vea colgado y no pegado.
///
/// Se integra por posiciones (se mueve la masa y se la devuelve a su distancia
/// del punto de sujeción), que es estable con pasos grandes. El intervalo entre
/// llamadas se parte en pasos de [_maxStep] y el punto de sujeción se
/// interpola a lo largo de él: la cabeza llega a saltos, a la frecuencia del
/// tracking, y un salto entero en un solo paso sería un golpe que lanzaría el
/// arete.
///
/// Marco de la escena: y hacia arriba, en metros.
class Pendulum {
  /// Distancia de la sujeción al centro de la pieza, en metros.
  final double length;

  /// Fracción del amortiguamiento crítico. Un arete real se calma en unas
  /// pocas oscilaciones.
  final double dampingRatio;

  /// Tope del ángulo con la vertical: el arete roza la piel y el gancho no
  /// deja que se levante más.
  final double maxAngle;

  final double gravity;

  static const double _maxStep = 1 / 240;

  /// Pausa a partir de la cual no se intenta seguir el movimiento: con el
  /// tracking perdido o la app en pausa, se vuelve a colgar en reposo.
  static const double _maxGap = 0.25;

  Vec3? _pivot, _bob;
  Vec3 _vel = Vec3.zero;

  Pendulum({
    required double length,
    this.dampingRatio = 0.2,
    this.maxAngle = 45 * math.pi / 180,
    this.gravity = 9.81,
  }) : length = math.max(length, 1e-4);

  /// Unitario de la sujeción a la masa. Hacia abajo mientras no se haya
  /// movido.
  Vec3 get direction {
    final p = _pivot, b = _bob;
    if (p == null || b == null) return const Vec3(0, -1, 0);
    return (b - p).normalized();
  }

  /// Olvida el estado: el próximo [step] cuelga en reposo. Para cuando se
  /// pierde el tracking y la cabeza puede reaparecer en otro sitio.
  void clear() {
    _pivot = null;
    _bob = null;
    _vel = Vec3.zero;
  }

  /// Cuelga en reposo desde [pivot].
  void reset(Vec3 pivot) {
    _pivot = pivot;
    _bob = pivot + const Vec3(0, -1, 0) * length;
    _vel = Vec3.zero;
  }

  /// Avanza [dt] segundos con la sujeción llegando a [pivot] y devuelve
  /// [direction].
  Vec3 step(Vec3 pivot, double dt) {
    final inicio = _pivot;
    if (inicio == null || _bob == null || dt > _maxGap) {
      reset(pivot);
      return direction;
    }
    if (dt <= 0) return direction;

    final pasos = math.max(1, (dt / _maxStep).ceil());
    final h = dt / pasos;
    for (var i = 1; i <= pasos; i++) {
      _substep(inicio + (pivot - inicio) * (i / pasos), h);
    }
    _pivot = pivot;
    return direction;
  }

  void _substep(Vec3 pivot, double h) {
    final omega = math.sqrt(gravity / length);
    final previa = _bob!;
    var v = _vel + Vec3(0, -gravity * h, 0);
    v = v * math.exp(-2 * dampingRatio * omega * h);
    var b = previa + v * h;

    var d = (b - pivot).normalized();
    const abajo = Vec3(0, -1, 0);
    final cosA = d.dot(abajo);
    final cosMax = math.cos(maxAngle);
    if (cosA < cosMax) {
      final lado = d - abajo * cosA;
      d = lado.length < 1e-9
          ? abajo
          : abajo * cosMax + lado.normalized() * math.sin(maxAngle);
    }
    b = pivot + d * length;
    _vel = (b - previa) * (1 / h);
    _bob = b;
  }
}
