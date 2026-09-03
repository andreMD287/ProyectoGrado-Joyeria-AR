import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/math/geometry.dart';

void main() {
  group('normalizeAxisAngle', () {
    test('deja intactas las inclinaciones pequenas', () {
      expect(normalizeAxisAngle(0), closeTo(0, 1e-9));
      expect(normalizeAxisAngle(0.2), closeTo(0.2, 1e-9));
      expect(normalizeAxisAngle(-0.2), closeTo(-0.2, 1e-9));
    });

    test('una cara derecha vista en espejo da 0, no media vuelta', () {
      // Caso reproducido en dispositivo: con la camara frontal el vector entre
      // los ojos viene invertido y atan2 devolvia +-180 grados, con lo que la
      // pieza se dibujaba boca abajo.
      expect(normalizeAxisAngle(math.pi), closeTo(0, 1e-9));
      expect(normalizeAxisAngle(-math.pi), closeTo(0, 1e-9));
    });

    test('una cabeza inclinada da la misma inclinacion en ambos sentidos', () {
      const inclinacion = 0.35;
      final directo = normalizeAxisAngle(inclinacion);
      final invertido = normalizeAxisAngle(inclinacion + math.pi);

      expect(invertido, closeTo(directo, 1e-9));
    });

    test('el resultado siempre cae en (-pi/2, pi/2]', () {
      for (var grados = -720; grados <= 720; grados += 7) {
        final a = normalizeAxisAngle(grados * math.pi / 180);
        expect(a, greaterThan(-math.pi / 2 - 1e-9), reason: '$grados grados');
        expect(a, lessThanOrEqualTo(math.pi / 2 + 1e-9), reason: '$grados grados');
      }
    });

    test('preserva el eje: la direccion normalizada apunta igual', () {
      for (var grados = -350; grados <= 350; grados += 11) {
        final original = grados * math.pi / 180;
        final normalizado = normalizeAxisAngle(original);
        // Dos angulos representan el mismo eje si su seno del doble coincide.
        expect(
          math.sin(2 * normalizado),
          closeTo(math.sin(2 * original), 1e-9),
          reason: '$grados grados',
        );
        expect(
          math.cos(2 * normalizado),
          closeTo(math.cos(2 * original), 1e-9),
          reason: '$grados grados',
        );
      }
    });
  });
}
