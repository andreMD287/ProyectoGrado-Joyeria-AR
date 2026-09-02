import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/math/geometry.dart';

void main() {
  group('rotateNormalizedToUpright', () {
    test('sin rotacion deja el punto igual', () {
      final p = rotateNormalizedToUpright(x: 0.3, y: 0.8, rotationDegrees: 0);
      expect(p.x, closeTo(0.3, 1e-9));
      expect(p.y, closeTo(0.8, 1e-9));
    });

    test('a 90 grados, una mano que apunta a la izquierda en el buffer '
        'apunta hacia arriba en pantalla', () {
      // Caso reproducido en dispositivo: los dedos volvian con x pequena (a la
      // izquierda del buffer apaisado) y la muneca con x grande. Tras la
      // conversion los dedos tienen que quedar arriba y la muneca abajo.
      final dedos =
          rotateNormalizedToUpright(x: 0.2, y: 0.5, rotationDegrees: 90);
      final muneca =
          rotateNormalizedToUpright(x: 0.8, y: 0.5, rotationDegrees: 90);

      expect(dedos.y, lessThan(muneca.y));
      expect(dedos.y, closeTo(0.2, 1e-9));
      expect(muneca.y, closeTo(0.8, 1e-9));
      // Ambos quedan a la misma altura horizontal: y del buffer -> x invertida.
      expect(dedos.x, closeTo(0.5, 1e-9));
      expect(muneca.x, closeTo(0.5, 1e-9));
    });

    test('a 90 grados invierte el eje y del buffer sobre el eje x', () {
      final p = rotateNormalizedToUpright(x: 0.0, y: 0.0, rotationDegrees: 90);
      expect(p.x, closeTo(1.0, 1e-9));
      expect(p.y, closeTo(0.0, 1e-9));
    });

    test('270 grados es la rotacion inversa de 90', () {
      const x = 0.31, y = 0.74;
      final ida = rotateNormalizedToUpright(
        x: x,
        y: y,
        rotationDegrees: 90,
      );
      final vuelta = rotateNormalizedToUpright(
        x: ida.x,
        y: ida.y,
        rotationDegrees: 270,
      );

      expect(vuelta.x, closeTo(x, 1e-9));
      expect(vuelta.y, closeTo(y, 1e-9));
    });

    test('180 grados es un giro completo de los dos ejes', () {
      final p =
          rotateNormalizedToUpright(x: 0.25, y: 0.6, rotationDegrees: 180);
      expect(p.x, closeTo(0.75, 1e-9));
      expect(p.y, closeTo(0.4, 1e-9));
    });

    test('el centro del frame es punto fijo en cualquier rotacion', () {
      for (final rot in [0, 90, 180, 270]) {
        final p =
            rotateNormalizedToUpright(x: 0.5, y: 0.5, rotationDegrees: rot);
        expect(p.x, closeTo(0.5, 1e-9), reason: 'rotacion $rot');
        expect(p.y, closeTo(0.5, 1e-9), reason: 'rotacion $rot');
      }
    });

    test('normaliza rotaciones fuera de rango', () {
      final a = rotateNormalizedToUpright(x: 0.2, y: 0.7, rotationDegrees: 450);
      final b = rotateNormalizedToUpright(x: 0.2, y: 0.7, rotationDegrees: -270);
      final esperado =
          rotateNormalizedToUpright(x: 0.2, y: 0.7, rotationDegrees: 90);

      expect(a.x, closeTo(esperado.x, 1e-9));
      expect(a.y, closeTo(esperado.y, 1e-9));
      expect(b.x, closeTo(esperado.x, 1e-9));
      expect(b.y, closeTo(esperado.y, 1e-9));
    });
  });
}
