import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/math/geometry.dart';
import 'package:jewelry_ar/core/math/ring_geometry.dart';

/// Banda anular alrededor del eje y: radios [interior]..[exterior], alto [alto].
List<Vec3> _banda({
  required double interior,
  required double exterior,
  required double alto,
}) {
  final puntos = <Vec3>[];
  for (var i = 0; i < 180; i++) {
    final a = i / 180 * 2 * math.pi;
    for (final r in [interior, exterior]) {
      for (final y in [-alto / 2, alto / 2]) {
        puntos.add(Vec3(r * math.cos(a), y, r * math.sin(a)));
      }
    }
  }
  return puntos;
}

void main() {
  test('mide el hueco real de un brazalete de banda ancha', () {
    // Banda radial gruesa (1) y baja (0,4): la caja daria
    // diametro - 2*grosor = 10 - 0,8 = 9,2, cuando el hueco es 8.
    final m = measureRing(_banda(interior: 4, exterior: 5, alto: 0.4))!;

    expect(m.axis, 1);
    expect(m.holeDiameter, closeTo(8, 0.05));
    expect(m.outerDiameter, closeTo(10, 0.05));
  });

  test('un dije que cuelga hacia dentro no achica el hueco', () {
    final puntos = _banda(interior: 4, exterior: 4.5, alto: 0.5)
      ..addAll([
        for (var i = 0; i < 20; i++) Vec3(1 + i * 0.1, 0, 0.05),
      ]);

    final m = measureRing(puntos)!;
    expect(m.holeDiameter, closeTo(8, 0.05));
  });

  test('una pieza maciza no se toma por aro', () {
    final rnd = math.Random(1);
    final macizo = [
      for (var i = 0; i < 2000; i++)
        Vec3(
          rnd.nextDouble() * 2 - 1,
          rnd.nextDouble() * 2 - 1,
          rnd.nextDouble() * 2 - 1,
        ),
    ];
    expect(measureRing(macizo), isNull);
  });

  test('sin puntos suficientes devuelve null', () {
    expect(measureRing(const [Vec3(0, 0, 0)]), isNull);
  });
}
