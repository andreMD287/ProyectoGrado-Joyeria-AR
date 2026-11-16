import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/math/earring_geometry.dart';
import 'package:jewelry_ar/core/math/geometry.dart';
import 'package:jewelry_ar/features/catalog/data/models/jewelry_piece_model.dart';
import 'package:jewelry_ar/features/catalog/domain/entities/earring_type.dart';

/// Adorno de botón: un disco de radio 0,5 en z ∈ [-0,2, 0,2], centrado en
/// (0, 1), con un poste delgado que sale hacia [lado] (+1 o -1 en z).
List<Vec3> boton({double lado = -1}) => [
      for (var i = 0; i < 36; i++)
        for (final z in const [-0.2, 0.0, 0.2])
          for (final r in const [0.3, 0.5])
            Vec3(
              r * math.cos(i * math.pi / 18),
              1 + r * math.sin(i * math.pi / 18),
              z,
            ),
      for (var k = 0; k <= 10; k++)
        for (var i = 0; i < 6; i++)
          Vec3(
            0.02 * math.cos(i * math.pi / 3),
            1 + 0.02 * math.sin(i * math.pi / 3),
            lado * (0.25 + 0.075 * k),
          ),
    ];

/// Colgante: un gancho arriba en (0,1, 0) y el cuerpo, más pesado, abajo en
/// (0,3, -1).
List<Vec3> colgante() => [
      for (var k = 0; k <= 10; k++) Vec3(0.1, -0.03 * k, 0),
      for (var i = 0; i < 40; i++)
        Vec3(
          0.3 + 0.3 * math.cos(i * math.pi / 20),
          -1.0 + 0.3 * math.sin(i * math.pi / 20),
          0,
        ),
    ];

/// Anillo de puntos de radio [r] alrededor del eje y, a la altura [y].
List<Vec3> anilloY(double r, double y, {Vec3 centro = Vec3.zero}) => [
      for (var i = 0; i < 24; i++)
        centro +
            Vec3(r * math.cos(i * math.pi / 12), y, r * math.sin(i * math.pi / 12)),
    ];

/// Como `Aretes_Juanes`: la piedra mira hacia +y, la aguja baja desde ella y
/// el cierre de mariposa —más ancho que la piedra— va ensartado en la aguja,
/// sin llegar a la punta. Cada malla por separado.
List<List<Vec3>> botonVertical() => [
      // Piedra y engaste: y ∈ [0, 0,3], radio 0,5.
      [for (final y in const [0.0, 0.1, 0.2, 0.3]) ...anilloY(0.5 - y, y)],
      // Aguja: y ∈ [-2,5, 0,05], radio 0,03.
      [for (var k = 0; k <= 25; k++) ...anilloY(0.03, 0.05 - 0.1 * k)],
      // Cierre: y ∈ [-2,0, -1,6], radio 0,7.
      [for (final y in const [-2.0, -1.8, -1.6]) ...anilloY(0.7, y)],
    ];

/// Como `arete_perla`: una perla de radio 0,45 y una aguja hacia +z que nace
/// dentro de ella. Sin cierre.
List<List<Vec3>> perlaConAguja() => [
      [
        for (var i = 0; i < 12; i++)
          for (var j = 0; j <= 12; j++)
            Vec3(
              0.45 * math.sin(j * math.pi / 12) * math.cos(i * math.pi / 6),
              1 + 0.45 * math.sin(j * math.pi / 12) * math.sin(i * math.pi / 6),
              0.17 + 0.45 * math.cos(j * math.pi / 12),
            ),
      ],
      [
        for (var k = 0; k <= 20; k++)
          for (var i = 0; i < 6; i++)
            Vec3(
              0.03 * math.cos(i * math.pi / 3),
              1 + 0.03 * math.sin(i * math.pi / 3),
              -0.14 + 0.0765 * k,
            ),
      ],
    ];

/// Gira cada punto [grados] alrededor del eje z.
List<List<Vec3>> giradoEnZ(List<List<Vec3>> partes, double grados) {
  final a = grados * math.pi / 180;
  final c = math.cos(a), s = math.sin(a);
  return [
    for (final parte in partes)
      [for (final p in parte) Vec3(c * p.x - s * p.y, s * p.x + c * p.y, p.z)],
  ];
}

void main() {
  group('botón con aguja como malla aparte', () {
    test('la piedra mira al lado contrario de la aguja, aunque vaya vertical',
        () {
      final m = measureEarring(botonVertical(), hangs: false)!;
      expect(m.hangs, isFalse);
      expect(m.front.y, closeTo(1, 1e-6));
      // Sujeta por el respaldo de la piedra, sobre la aguja: el cierre queda
      // detrás, donde irá el lóbulo.
      expect(m.pivot.x, closeTo(0, 1e-6));
      expect(m.pivot.y, closeTo(0, 1e-6));
      expect(m.pivot.z, closeTo(0, 1e-6));
      // El alto es el de la piedra, no el del cierre, que es más ancho.
      expect(m.length, closeTo(1.0, 1e-6));
      expect(m.up.dot(m.front), closeTo(0, 1e-9));
    });

    test('sigue a la aguja aunque el modelo venga inclinado', () {
      final m = measureEarring(giradoEnZ(botonVertical(), 22), hangs: false)!;
      final a = 22 * math.pi / 180;
      expect(m.front.x, closeTo(-math.sin(a), 1e-6));
      expect(m.front.y, closeTo(math.cos(a), 1e-6));
    });

    test('perla con la aguja hacia +z: mira hacia -z y se sujeta atrás', () {
      final m = measureEarring(perlaConAguja(), hangs: false)!;
      expect(m.front.z, closeTo(-1, 1e-6));
      expect(m.pivot.z, closeTo(0.62, 1e-6));
      expect(m.pivot.y, closeTo(1, 1e-6));
      expect(m.length, closeTo(0.9, 1e-6));
    });

    test('con aguja se reconoce como botón sin tipo en el catálogo', () {
      expect(measureEarring(botonVertical())!.hangs, isFalse);
    });
  });

  group('botón', () {
    test('mira al lado contrario del poste y se sujeta por su respaldo', () {
      final m = measureEarring([boton(lado: -1)], hangs: false)!;
      expect(m.hangs, isFalse);
      expect(m.front.z, closeTo(1, 1e-9));
      // Centro del adorno, en el respaldo (el lado del poste).
      expect(m.pivot.x, closeTo(0, 1e-6));
      expect(m.pivot.y, closeTo(1, 1e-6));
      expect(m.pivot.z, closeTo(-0.2, 1e-9));
      // `alto` es el del adorno; el poste no cuenta.
      expect(m.length, closeTo(1.0, 1e-6));
    });

    test('con el poste hacia +z el adorno mira hacia -z', () {
      final m = measureEarring([boton(lado: 1)], hangs: false)!;
      expect(m.front.z, closeTo(-1, 1e-9));
      expect(m.pivot.z, closeTo(0.2, 1e-9));
    });

    test('se reconoce sin tipo en el catálogo', () {
      expect(measureEarring([boton()])!.hangs, isFalse);
    });
  });

  group('colgante', () {
    test('cuelga de lo más alto hacia su centro', () {
      final m = measureEarring([colgante()], hangs: true)!;
      expect(m.hangs, isTrue);
      expect(m.pivot.x, closeTo(0.1, 1e-9));
      expect(m.pivot.y, closeTo(0, 1e-9));
      expect(m.hang.y, lessThan(-0.9));
      // El cuerpo pesa más y está corrido a +x: cuelga algo inclinado en el
      // archivo, y la gravedad lo enderezará.
      expect(m.hang.x, greaterThan(0));
      expect(m.hangLength, greaterThan(0.5));
    });

    test('el frente queda perpendicular a la caída', () {
      final m = measureEarring([colgante()], hangs: true)!;
      expect(m.front.dot(m.hang), closeTo(0, 1e-9));
      expect(m.front.length, closeTo(1, 1e-9));
    });

    test('el largo es lo que cuelga, medido a lo largo de la caída', () {
      final m = measureEarring([colgante()], hangs: true)!;
      expect(m.length, greaterThan(1.2));
      expect(m.length, lessThan(1.4));
    });

    test('se reconoce sin tipo en el catálogo por ser alto y delgado', () {
      expect(measureEarring([colgante()])!.hangs, isTrue);
    });

    test('un punto de sujeción forzado manda sobre lo más alto', () {
      final m = measureEarring(
        [colgante()],
        hangs: true,
        pivot: const Vec3(0, -0.1, 0),
      )!;
      expect(m.pivot.y, closeTo(-0.1, 1e-12));
    });
  });

  test('sin vértices no hay medida', () {
    expect(measureEarring(const []), isNull);
  });

  group('catálogo', () {
    Map<String, dynamic> arete(Map<String, dynamic> extra) => {
          'id': 'a',
          'nombre': 'A',
          'categoria': 'arete',
          'modelo_glb': 'm.glb',
          'foto': 'f.jpg',
          'dimensiones_mm': {'alto': 8, 'ancho': 8, 'profundidad': 15},
          ...extra,
        };

    test('lee el tipo de arete y el punto de sujeción', () {
      final pieza = JewelryPieceModel.fromJson(arete({
        'tipo_arete': 'colgante',
        'punto_sujecion': [0, 1.5, -0.25],
      })).toEntity();
      expect(pieza.tipoArete, EarringType.drop);
      expect(pieza.tipoArete!.hangs, isTrue);
      expect(pieza.puntoSujecion, [0.0, 1.5, -0.25]);
    });

    test('sin esos campos quedan sin indicar', () {
      final pieza = JewelryPieceModel.fromJson(arete({})).toEntity();
      expect(pieza.tipoArete, isNull);
      expect(pieza.puntoSujecion, isNull);
    });

    test('un punto mal formado se ignora', () {
      final pieza = JewelryPieceModel.fromJson(arete({
        'punto_sujecion': [0, 1],
      })).toEntity();
      expect(pieza.puntoSujecion, isNull);
    });
  });
}
