import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/math/geometry.dart';
import 'package:jewelry_ar/core/math/necklace_geometry.dart';

/// Collar puesto: media vuelta trasera horizontal de radio [radio] a la altura
/// 0, y una caída en V desde los costados hasta ([caida] abajo, [avance]
/// adelante).
List<Vec3> _collar({
  double radio = 3,
  double caida = 3,
  double avance = 2.5,
  double centroX = 0,
}) {
  final puntos = <Vec3>[];
  for (var i = 0; i <= 90; i++) {
    final a = math.pi + i / 90 * math.pi; // de -x a +x pasando por -z
    puntos.add(Vec3(centroX + radio * math.cos(a), 0, radio * math.sin(a)));
  }
  for (var i = 0; i <= 60; i++) {
    final t = i / 60;
    for (final lado in [-1.0, 1.0]) {
      puntos.add(Vec3(
        centroX + lado * radio * (1 - t),
        -caida * t,
        avance * t,
      ));
    }
  }
  return puntos;
}

void main() {
  test('el hueco es el ancho de la vuelta trasera, no de toda la pieza', () {
    final m = measureNecklace(_collar())!;

    expect(m.holeWidth, closeTo(6, 0.05));
    expect(m.neckCenter.x, closeTo(0, 0.05));
    // Nuca en z = -3, centro del cuello medio ancho por delante.
    expect(m.neckCenter.z, closeTo(0, 0.05));
    expect(m.neckCenter.y, closeTo(0, 0.1));
    expect(m.facesFront, isTrue);
    expect(m.lowest.y, closeTo(-3, 1e-9));
  });

  test('sigue al hueco aunque el modelo no esté centrado en x', () {
    final m = measureNecklace(_collar(centroX: 0.4))!;

    expect(m.neckCenter.x, closeTo(0.4, 0.05));
  });

  test('un eslabón suelto en lo alto no ensancha el hueco', () {
    final puntos = _collar()..add(const Vec3(9, 0.01, -1));

    expect(measureNecklace(puntos)!.holeWidth, closeTo(6, 0.05));
  });

  test('detecta un modelo con la caída hacia atrás', () {
    final girado = [
      for (final p in _collar()) Vec3(p.x, p.y, -p.z),
    ];

    expect(measureNecklace(girado)!.facesFront, isFalse);
  });

  test('sin altura no hay collar que medir', () {
    expect(
      measureNecklace([for (var i = 0; i < 20; i++) Vec3(i * 1.0, 0, 0)]),
      isNull,
    );
  });
}
