import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/math/geometry.dart';
import 'package:jewelry_ar/core/math/head_geometry.dart';

/// Rotación alrededor de la vertical, como 4×4 por columnas con la cara a
/// 40 cm de la cámara (así la entrega MediaPipe).
List<double> giroVertical(double grados, {bool porFilas = false}) {
  final a = grados * math.pi / 180;
  final c = math.cos(a), s = math.sin(a);
  // Filas de la 3×3: x = (c, 0, s), y = (0, 1, 0), z = (-s, 0, c).
  final r = [
    [c, 0.0, s],
    [0.0, 1.0, 0.0],
    [-s, 0.0, c],
  ];
  const t = [0.0, 0.0, -40.0];
  final m = List<double>.filled(16, 0);
  for (var fila = 0; fila < 3; fila++) {
    for (var col = 0; col < 3; col++) {
      if (porFilas) {
        m[fila * 4 + col] = r[fila][col];
      } else {
        m[col * 4 + fila] = r[fila][col];
      }
    }
    if (porFilas) {
      m[fila * 4 + 3] = t[fila];
    } else {
      m[12 + fila] = t[fila];
    }
  }
  m[15] = 1;
  return m;
}

void expectVec(Vec3 v, Vec3 esperado, {double tol = 1e-9}) {
  expect(v.x, closeTo(esperado.x, tol));
  expect(v.y, closeTo(esperado.y, tol));
  expect(v.z, closeTo(esperado.z, tol));
}

void main() {
  group('matriz de transformación facial', () {
    test('identidad: ejes de la cámara', () {
      final axes = headAxesFromMatrix(giroVertical(0))!;
      expectVec(axes.x, const Vec3(1, 0, 0));
      expectVec(axes.y, const Vec3(0, 1, 0));
      expectVec(axes.z, const Vec3(0, 0, 1));
    });

    test('por columnas y por filas dan la misma rotación', () {
      final a = headAxesFromMatrix(giroVertical(30))!;
      final b = headAxesFromMatrix(giroVertical(30, porFilas: true))!;
      expectVec(a.x, b.x);
      expectVec(a.y, b.y);
    });

    test('la cara girada hacia la derecha de la imagen mira hacia +x', () {
      final axes = headAxesFromMatrix(giroVertical(30))!;
      expect(axes.z.x, closeTo(math.sin(30 * math.pi / 180), 1e-9));
      expect(axes.z.z, greaterThan(0));
    });

    test('rechaza lo que no es una 4×4', () {
      expect(headAxesFromMatrix(const [1, 0, 0]), isNull);
    });
  });

  group('espejo', () {
    test('conjugar con el espejo da lo mismo que espejar los puntos', () {
      // Lo que se ve en el espejo de un punto de la cabeza tiene que caer
      // donde la pose espejada pone el mismo punto, también espejado.
      final pose = headAxesFromMatrix(giroVertical(25))!;
      final espejada = pose.mirrored();
      Vec3 espejo(Vec3 v) => Vec3(-v.x, v.y, v.z);
      for (final h in const [
        Vec3(0.5, -0.2, -0.05),
        Vec3(-0.3, 0.4, 0.6),
        Vec3(0.1, 0.9, -0.7),
      ]) {
        expectVec(espejada.apply(espejo(h)), espejo(pose.apply(h)));
      }
    });

    test('sigue siendo una rotación: la cara mira hacia el otro lado', () {
      final espejada = headAxesFromMatrix(giroVertical(30))!.mirrored();
      expect(espejada.z.x, closeTo(-math.sin(30 * math.pi / 180), 1e-9));
      expect(espejada.z.z, greaterThan(0));
      expect(espejada.x.dot(espejada.y), closeTo(0, 1e-12));
    });
  });

  group('ejes ortonormales', () {
    test('conserva x y endereza y', () {
      final axes = HeadAxes.orthonormal(
        const Vec3(2, 0, 0),
        const Vec3(0.3, 1, 0),
      )!;
      expectVec(axes.x, const Vec3(1, 0, 0));
      expectVec(axes.y, const Vec3(0, 1, 0));
    });

    test('null si las direcciones son paralelas', () {
      expect(
        HeadAxes.orthonormal(const Vec3(1, 0, 0), const Vec3(2, 0, 0)),
        isNull,
      );
    });
  });

  group('proyección de la cabeza a la imagen', () {
    test('el lóbulo cae debajo y hacia afuera de la mejilla', () {
      const axes = HeadAxes(Vec3(1, 0, 0), Vec3(0, 1, 0));
      final p = headPointToImage(
        local: HeadModel.lobeFor(1),
        origin: const Vec3(0.5, 0.5, 0),
        width: 0.2,
        axes: axes,
        aspect: 0.75,
      );
      expect(p.x, closeTo(0.5 + HeadModel.lobe.x * 0.2, 1e-9));
      // Hacia abajo; en y normalizada se multiplica por el aspecto, porque el
      // ancho de cara va en fracciones del ancho.
      expect(p.y, closeTo(0.5 - HeadModel.lobe.y * 0.2 * 0.75, 1e-9));
      expect(p.y, greaterThan(0.5));
    });

    test('con perspectiva, lo que queda hacia la cámara se aleja del centro',
        () {
      // Cabeza girada: el lóbulo del lado -x queda hacia la cámara.
      final girada = headAxesFromMatrix(giroVertical(40))!;
      Vec3 lobulo({double? tan}) => headPointToImage(
            local: HeadModel.lobeFor(-1),
            origin: const Vec3(0.5, 0.5, 0),
            width: 0.5,
            axes: girada,
            aspect: 2 / 3,
            tanHalfFrameWidth: tan,
          );
      final orto = lobulo();
      final persp = lobulo(tan: mediapipeTanHalfWidth(2 / 3));
      expect(girada.apply(HeadModel.lobeFor(-1)).z, greaterThan(0));
      expect((persp.x - 0.5).abs(), greaterThan((orto.x - 0.5).abs()));
      expect(persp.y - 0.5, greaterThan(orto.y - 0.5));
    });

    test('para un frame de 480×720 MediaPipe supone ~44° de ancho', () {
      final grados = 2 * math.atan(mediapipeTanHalfWidth(480 / 720)) * 180 /
          math.pi;
      expect(grados, closeTo(44.4, 0.1));
    });

    test('ida y vuelta entre imagen y escena', () {
      const p = Vec3(0.3, 0.7, -0.05);
      expectVec(sceneToImage(imageToScene(p, 0.75), 0.75), p);
    });
  });

  group('modelo de la cabeza', () {
    test('el lóbulo sobresale del cráneo, la cara y el cuello', () {
      // Si un oclusor llegara al lóbulo, taparía también el arete cercano.
      final l = HeadModel.lobeFor(1);
      double dentroElipsoide(Vec3 p, Vec3 c, Vec3 r) =>
          math.pow((p.x - c.x) / r.x, 2) +
          math.pow((p.y - c.y) / r.y, 2) +
          math.pow((p.z - c.z) / r.z, 2).toDouble();
      expect(
        dentroElipsoide(l, HeadModel.craniumCenter, HeadModel.craniumRadii),
        greaterThan(1),
      );
      expect(
        dentroElipsoide(l, HeadModel.faceCenter, HeadModel.faceRadii),
        greaterThan(1),
      );
      final alEje = math.sqrt(
        l.x * l.x + math.pow(l.z - HeadModel.neckAxisZ, 2),
      );
      expect(alEje, greaterThan(HeadModel.neckRadius));
    });

    test('la normal del lóbulo mira hacia afuera y algo hacia adelante', () {
      expect(HeadModel.earNormal(1).x, greaterThan(0.9));
      expect(HeadModel.earNormal(-1).x, lessThan(-0.9));
      expect(HeadModel.earNormal(1).z, greaterThan(0));
      expect(HeadModel.earNormal(-1).z, greaterThan(0));
    });
  });
}
