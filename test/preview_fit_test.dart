import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/math/geometry.dart';

void main() {
  // Caso real de la pantalla de prueba virtual: preview 720x480 del sensor,
  // rotado a vertical (480x720), dentro de la tarjeta de camara.
  const imageWidth = 480.0;
  const imageHeight = 720.0;
  const areaWidth = 360.0;
  const areaHeight = 505.0;

  final fit = coverFit(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    areaWidth: areaWidth,
    areaHeight: areaHeight,
  );

  group('coverFit', () {
    test('escala por el eje que llena el area y recorta el otro', () {
      // max(360/480, 505/720) = max(0.75, 0.701) = 0.75
      expect(fit.scale, closeTo(0.75, 1e-9));
      expect(fit.dx, closeTo(0, 1e-9));
      // La imagen renderizada mide 540 de alto: sobresale 17.5 por lado.
      expect(fit.dy, closeTo(-17.5, 1e-9));
    });

    test('el centro del frame cae en el centro del area', () {
      expect(fit.xOf(0.5), closeTo(areaWidth / 2, 1e-9));
      expect(fit.yOf(0.5), closeTo(areaHeight / 2, 1e-9));
    });

    test('fuera del centro NO coincide con multiplicar por el area', () {
      // Este es el desfase que arrastraba el overlay: en el centro acertaba,
      // hacia los bordes del eje recortado se iba varios pixeles.
      const normalizedY = 0.9;
      final ingenuo = normalizedY * areaHeight; // 454.5
      final correcto = fit.yOf(normalizedY); // 468.5

      expect(correcto, closeTo(468.5, 1e-9));
      expect((correcto - ingenuo).abs(), greaterThan(10));
    });

    test('convierte longitudes en fracciones del ancho a pixeles', () {
      expect(fit.lengthOf(0.2), closeTo(0.2 * imageWidth * 0.75, 1e-9));
    });

    test('recorta a lo ancho cuando el area es mas panoramica', () {
      final ancho = coverFit(
        imageWidth: 480,
        imageHeight: 720,
        areaWidth: 800,
        areaHeight: 400,
      );

      // max(800/480, 400/720) = 1.667 -> imagen de 800x1200, recorta arriba y
      // abajo, no a los lados.
      expect(ancho.scale, closeTo(800 / 480, 1e-9));
      expect(ancho.dx, closeTo(0, 1e-9));
      expect(ancho.dy, lessThan(0));
    });

    test('tolera un tamano de imagen desconocido sin romper el mapeo', () {
      final degenerado = coverFit(
        imageWidth: 0,
        imageHeight: 0,
        areaWidth: areaWidth,
        areaHeight: areaHeight,
      );

      expect(degenerado.scale, 1);
      expect(degenerado.xOf(0.5), closeTo(areaWidth / 2, 1e-9));
      expect(degenerado.yOf(0.5), closeTo(areaHeight / 2, 1e-9));
    });
  });
}
