import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/math/geometry.dart';
import 'package:jewelry_ar/core/math/pendulum.dart';

/// Avanza [segundos] a 60 Hz con la sujeción quieta en [p].
Vec3 quieto(Pendulum pendulo, Vec3 p, double segundos) {
  var d = pendulo.direction;
  for (var t = 0.0; t < segundos; t += 1 / 60) {
    d = pendulo.step(p, 1 / 60);
  }
  return d;
}

void main() {
  test('en reposo cuelga hacia abajo y se queda así', () {
    final pendulo = Pendulum(length: 0.02)..reset(Vec3.zero);
    final d = quieto(pendulo, Vec3.zero, 2);
    expect(d.y, closeTo(-1, 1e-9));
  });

  test('al mover la sujeción el arete se queda atrás', () {
    final pendulo = Pendulum(length: 0.02)..reset(Vec3.zero);
    // 1 cm hacia +x en 1/30 s: un giro de cabeza rápido.
    final d = pendulo.step(const Vec3(0.01, 0, 0), 1 / 30);
    expect(d.x, lessThan(-0.05));
  });

  test('vuelve a colgar hacia abajo cuando la cabeza se detiene', () {
    final pendulo = Pendulum(length: 0.02)..reset(Vec3.zero);
    pendulo.step(const Vec3(0.01, 0, 0), 1 / 30);
    final d = quieto(pendulo, const Vec3(0.01, 0, 0), 3);
    expect(d.x.abs(), lessThan(0.01));
    expect(d.y, lessThan(-0.99));
  });

  test('oscila a la frecuencia de un arete real', () {
    // Un péndulo de 2 cm va a ~3,5 Hz: tras soltarlo, el primer cruce por la
    // vertical llega en un cuarto de periodo, ~70 ms.
    final pendulo = Pendulum(length: 0.02, dampingRatio: 0)..reset(Vec3.zero);
    pendulo.step(const Vec3(0.004, 0, 0), 1 / 120);
    final signo = pendulo.direction.x.sign;
    var t = 0.0;
    while (pendulo.direction.x.sign == signo && t < 1) {
      pendulo.step(const Vec3(0.004, 0, 0), 1 / 1000);
      t += 1 / 1000;
    }
    final periodo = 2 * math.pi * math.sqrt(0.02 / 9.81);
    expect(t, closeTo(periodo / 4, 0.03));
  });

  test('no pasa del ángulo máximo aunque la cabeza salte', () {
    final pendulo = Pendulum(length: 0.02)..reset(Vec3.zero);
    var peor = 0.0;
    for (var i = 0; i < 30; i++) {
      final x = i.isEven ? 0.05 : -0.05;
      final d = pendulo.step(Vec3(x, 0, 0), 1 / 30);
      peor = math.max(peor, math.acos(-d.y.clamp(-1.0, 1.0)));
    }
    expect(peor, lessThanOrEqualTo(pendulo.maxAngle + 1e-6));
  });

  test('tras una pausa larga cuelga en reposo en vez de salir disparado', () {
    final pendulo = Pendulum(length: 0.02)..reset(Vec3.zero);
    final d = pendulo.step(const Vec3(0.5, 0, 0), 1.0);
    expect(d.y, closeTo(-1, 1e-9));
  });

  test('clear hace que el próximo paso cuelgue en reposo', () {
    final pendulo = Pendulum(length: 0.02)..reset(Vec3.zero);
    pendulo.step(const Vec3(0.01, 0, 0), 1 / 30);
    pendulo.clear();
    final d = pendulo.step(const Vec3(0.3, 0, 0), 1 / 30);
    expect(d.y, closeTo(-1, 1e-9));
  });
}
