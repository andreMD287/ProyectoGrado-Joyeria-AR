import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/math/geometry.dart';
import 'package:jewelry_ar/core/math/head_geometry.dart';
import 'package:jewelry_ar/features/tracking/data/datasources/head_detector_datasource.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/head_observation.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark_frame.dart';
import 'package:jewelry_ar/features/tracking/domain/strategies/earring_strategy.dart';

/// Cara de frente en la vista previa espejada: la mejilla derecha de la
/// persona (234) se ve a la derecha de la pantalla.
///
/// [zDerecha] es la profundidad de la mejilla de la derecha de la pantalla:
/// positiva, se aleja y la cara gira hacia la derecha.
HeadObservation caraDeFrente({
  HeadAxes? axes,
  bool mirrored = true,
  double zDerecha = 0,
}) =>
    HeadObservation(
      points: {
        HeadObservation.rightFaceSide:
            Landmark(mirrored ? 0.6 : 0.4, 0.5, mirrored ? zDerecha : 0),
        HeadObservation.leftFaceSide: Landmark(mirrored ? 0.4 : 0.6, 0.5, 0),
        HeadObservation.forehead: const Landmark(0.5, 0.3, -0.02),
        HeadObservation.chin: const Landmark(0.5, 0.75, -0.01),
        // Contorno bajo cada oreja, del lado de su mejilla.
        HeadObservation.rightUpperContour:
            Landmark(mirrored ? 0.595 : 0.405, 0.56, 0),
        HeadObservation.rightLowerContour:
            Landmark(mirrored ? 0.585 : 0.415, 0.62, 0),
        HeadObservation.leftUpperContour:
            Landmark(mirrored ? 0.405 : 0.595, 0.56, 0),
        HeadObservation.leftLowerContour:
            Landmark(mirrored ? 0.415 : 0.585, 0.62, 0),
      },
      axes: axes,
      mirrored: mirrored,
    );

const identidad = HeadAxes(Vec3(1, 0, 0), Vec3(0, 1, 0));

/// 4×4 por columnas de un giro alrededor de la vertical, con la cara a 40 cm.
List<double> giroVertical(double grados) {
  final a = grados * math.pi / 180;
  final c = math.cos(a), s = math.sin(a);
  return [c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, 0, 0, -40, 1];
}

void main() {
  group('estrategia con la cabeza medida', () {
    late EarringStrategy strategy;
    setUp(() => strategy = EarringStrategy());

    test('ancla en el centro de las mejillas y escala por su distancia', () {
      final anchor = strategy.computeAnchor(
        LandmarkFrame(head: caraDeFrente(axes: identidad)),
        imageAspect: 0.75,
      )!;
      expect(anchor.position.x, closeTo(0.5, 1e-9));
      expect(anchor.position.y, closeTo(0.5, 1e-9));
      expect(anchor.scale, closeTo(0.2, 1e-9));
      expect(anchor.headAxes!.x.x, closeTo(1, 1e-9));
      expect(anchor.earringSide, isNull);
    });

    test('sin matriz, arma los ejes con las mejillas, la frente y el mentón',
        () {
      final anchor = strategy.computeAnchor(
        LandmarkFrame(head: caraDeFrente()),
        imageAspect: 0.75,
      )!;
      final axes = anchor.headAxes!;
      expect(axes.x.x, closeTo(1, 1e-9));
      // Del mentón a la frente: hacia arriba de la pantalla.
      expect(axes.y.y, greaterThan(0.99));
      // La cara mira a la cámara.
      expect(axes.z.z, greaterThan(0.99));
    });

    test('una matriz que contradice a los puntos se descarta', () {
      // Girada 180°: su x va al revés de la línea de mejilla a mejilla.
      final anchor = strategy.computeAnchor(
        LandmarkFrame(
          head: caraDeFrente(axes: headAxesFromMatrix(giroVertical(180))),
        ),
        imageAspect: 0.75,
      )!;
      expect(anchor.headAxes!.x.x, closeTo(1, 1e-9));
    });

    test('la oreja elegida en la preparación deja solo ese arete', () {
      // 0 = izquierda de la persona. Con la vista espejada se ve a la
      // izquierda de la pantalla, que es el lado local -x.
      strategy.setPreferredSide(0);
      final izquierda = strategy.computeAnchor(
        LandmarkFrame(head: caraDeFrente(axes: identidad)),
        imageAspect: 0.75,
      )!;
      expect(izquierda.earringSide, -1);

      strategy.setPreferredSide(1);
      final derecha = strategy.computeAnchor(
        LandmarkFrame(head: caraDeFrente(axes: identidad)),
        imageAspect: 0.75,
      )!;
      expect(derecha.earringSide, 1);
    });

    test('sin espejo, la izquierda de la persona queda en +x', () {
      strategy.setPreferredSide(0);
      final anchor = strategy.computeAnchor(
        LandmarkFrame(head: caraDeFrente(axes: identidad, mirrored: false)),
        imageAspect: 0.75,
      )!;
      expect(anchor.earringSide, 1);
    });

    test('el giro sale de las mejillas medidas, no de la matriz', () {
      // Las mejillas dicen 20° (la de la derecha se aleja 0,2·tan 20°) y la
      // matriz dice 35°: manda lo medido, que es donde cuelgan los lóbulos.
      final anchor = strategy.computeAnchor(
        LandmarkFrame(
          head: caraDeFrente(
            axes: headAxesFromMatrix(giroVertical(35)),
            zDerecha: 0.2 * math.tan(20 * math.pi / 180),
          ),
        ),
        imageAspect: 0.75,
      )!;
      expect(anchor.yawRadians, closeTo(20 * math.pi / 180, 1e-9));
    });

    test('los lóbulos caen sobre las mejillas medidas aunque la cabeza gire',
        () {
      final anchor = strategy.computeAnchor(
        LandmarkFrame(
          head: caraDeFrente(
            axes: headAxesFromMatrix(giroVertical(35)),
            zDerecha: 0.2 * math.tan(20 * math.pi / 180),
          ),
        ),
        imageAspect: 0.75,
      )!;
      // El ±0,5 del modelo, sin el desplazamiento del lóbulo, es la mejilla.
      final derecha = headPointToImage(
        local: const Vec3(0.5, 0, 0),
        origin: anchor.position,
        width: anchor.scale!,
        axes: anchor.headAxes!,
        aspect: 0.75,
      );
      expect(derecha.x, closeTo(0.6, 1e-9));
      expect(derecha.y, closeTo(0.5, 1e-9));
    });

    test('cada lóbulo se ubica sobre el contorno medido de su lado', () {
      final anchor = strategy.computeAnchor(
        LandmarkFrame(head: caraDeFrente(axes: identidad)),
        imageAspect: 0.75,
      )!;
      const t = HeadModel.lobeAlongContour;
      for (final side in const [-1, 1]) {
        // Sin el ajuste fijo, el lóbulo cae en el punto del contorno.
        final p = headPointToImage(
          local: anchor.lobeFor(side)! - HeadModel.lobeOffsetFor(side),
          origin: anchor.position,
          width: anchor.scale!,
          axes: anchor.headAxes!,
          aspect: 0.75,
        );
        final arriba = side < 0 ? 0.405 : 0.595;
        final abajo = side < 0 ? 0.415 : 0.585;
        expect(p.x, closeTo(arriba + (abajo - arriba) * t, 1e-9));
        expect(p.y, closeTo(0.56 + 0.06 * t, 1e-9));
      }
      // El ajuste lleva cada lóbulo hacia afuera de su lado y hacia atrás.
      expect(anchor.lobeNegative!.x, lessThan(-0.4));
      expect(anchor.lobePositive!.x, greaterThan(0.4));
    });

    test('sin contorno de un lado, ese lóbulo es el atado a las mejillas', () {
      final anchor = strategy.computeAnchor(
        LandmarkFrame(
          head: HeadObservation(
            points: {
              for (final e in caraDeFrente(axes: identidad).points.entries)
                if (e.key != HeadObservation.leftLowerContour) e.key: e.value,
            },
            axes: identidad,
            mirrored: true,
          ),
        ),
        imageAspect: 0.75,
      )!;
      // De frente y nivelada no hay corrección por cabeceo.
      final rigido = HeadModel.lobeFor(-1);
      expect(anchor.lobeNegative!.x, closeTo(rigido.x, 1e-9));
      expect(anchor.lobeNegative!.y, closeTo(rigido.y, 1e-9));
      expect(anchor.lobeNegative!.z, closeTo(rigido.z, 1e-9));
      // El otro lado sí tiene contorno y sigue sobre él, distinto del rígido.
      expect(anchor.lobePositive!.y, isNot(closeTo(HeadModel.lobe.y, 1e-6)));
    });

    test('con la cabeza muy girada el lóbulo pasa al atado a las mejillas', () {
      // Mejilla derecha 0,2·tan 50° más lejos: la cara gira 50°.
      final anchor = strategy.computeAnchor(
        LandmarkFrame(
          head: caraDeFrente(
            axes: headAxesFromMatrix(giroVertical(50)),
            zDerecha: 0.2 * math.tan(50 * math.pi / 180),
          ),
        ),
        imageAspect: 0.75,
      )!;
      // La matriz gira solo alrededor de la vertical: sin cabeceo.
      final rigido = HeadModel.lobeFor(1);
      expect(anchor.lobePositive!.x, closeTo(rigido.x, 1e-9));
      expect(anchor.lobePositive!.y, closeTo(rigido.y, 1e-9));
      expect(anchor.lobePositive!.z, closeTo(rigido.z, 1e-9));
    });

    test('sin mejillas no hay ancla', () {
      expect(
        strategy.computeAnchor(
          const LandmarkFrame(
            head: HeadObservation(points: {}, mirrored: true),
          ),
        ),
        isNull,
      );
    });
  });

  group('respuesta del nativo en modo cabeza', () {
    Map<String, Object?> respuesta({List<double>? matrix}) => {
          'face': true,
          'points': [
            for (var k = 0; k < headMeshPoints.length; k++) ...[
              // Sin espejar: 234 a la izquierda de la imagen y 454 a la derecha.
              headMeshPoints[k] == 234
                  ? 0.4
                  : headMeshPoints[k] == 454
                      ? 0.6
                      : 0.5,
              0.5,
              0.0,
            ],
          ],
          'matrix': ?matrix,
        };

    test('espeja los puntos como la vista previa', () {
      final frame = headFrameFromNative(respuesta(), 270);
      final head = frame.head!;
      expect(head.mirrored, isTrue);
      expect(head.points[234]!.x, closeTo(0.6, 1e-12));
      expect(head.points[454]!.x, closeTo(0.4, 1e-12));
      expect(frame.landmarks, hasLength(headMeshPoints.length));
    });

    test('con el sensor a 90° no espeja', () {
      final head = headFrameFromNative(respuesta(), 90).head!;
      expect(head.mirrored, isFalse);
      expect(head.points[234]!.x, closeTo(0.4, 1e-12));
    });

    test('espeja también la rotación: la cara mira hacia el otro lado', () {
      final head = headFrameFromNative(
        respuesta(matrix: giroVertical(30)),
        270,
      ).head!;
      expect(head.axes!.z.x, closeTo(-math.sin(30 * math.pi / 180), 1e-9));
    });

    test('la cara de frente sigue de frente tras espejar, y cuadra con la '
        'estrategia', () {
      final frame = headFrameFromNative(
        respuesta(matrix: giroVertical(0)),
        270,
      );
      final anchor = EarringStrategy().computeAnchor(frame, imageAspect: 0.75)!;
      expect(anchor.headAxes!.x.x, closeTo(1, 1e-9));
      expect(anchor.headAxes!.z.z, closeTo(1, 1e-9));
    });

    test('sin cara no hay nada', () {
      expect(headFrameFromNative({'face': false}, 270).isEmpty, isTrue);
      expect(headFrameFromNative({'face': false}, 270).head, isNull);
    });
  });
}
