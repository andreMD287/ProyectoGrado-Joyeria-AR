import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/features/tracking/data/datasources/neck_detector_datasource.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark_frame.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/neck_observation.dart';
import 'package:jewelry_ar/features/tracking/domain/strategies/necklace_strategy.dart';

/// Cara de frente con el mentón en (0.5, 0.4) y 0.2 de ancho.
NeckObservation cara({NeckShape? neck, double zDerecha = 0}) =>
    NeckObservation(
      chin: const Landmark(0.5, 0.4, 0),
      cheekLeft: const Landmark(0.4, 0.3, 0),
      cheekRight: Landmark(0.6, 0.3, zDerecha),
      nose: const Landmark(0.5, 0.3, 0),
      faceWidth: 0.2,
      neck: neck,
    );

/// Cuello medido sobre esa misma cara.
NeckShape cuello({
  double izq = 0.42,
  double der = 0.58,
  double y = 0.45,
  double? frenteX,
  double? frenteY,
  double columna = 0,
}) =>
    NeckShape(
      leftX: izq,
      leftY: y,
      rightX: der,
      rightY: y,
      frontX: frenteX,
      frontY: frenteY,
      narrowWidth: columna,
      refChinX: 0.5,
      refChinY: 0.4,
      refFaceWidth: 0.2,
    );

void main() {
  const strategy = NecklaceStrategy();

  group('estrategia con el cuello medido', () {
    test('ancla en el centro de la base y escala por su ancho', () {
      final anchor = strategy.computeAnchor(
        LandmarkFrame(neck: cara(neck: cuello(frenteX: 0.5, frenteY: 0.5))),
      )!;

      expect(anchor.position.x, closeTo(0.5, 1e-9));
      expect(anchor.position.y, closeTo(0.45, 1e-9));
      expect(anchor.scale, closeTo(0.16, 1e-9));
      // Sin columna medida, una fracción fija de la base.
      expect(anchor.limbWidth, closeTo(0.16 * strategy.columnToBase, 1e-9));
      expect(anchor.yawRadians, closeTo(0, 1e-9));
    });

    test('la forma del cuello sigue a la cara actual', () {
      // La cara se movió 0.1 a la derecha y se ve un 50 % más grande que
      // cuando se midió el cuello.
      final obs = NeckObservation(
        chin: const Landmark(0.6, 0.4, 0),
        cheekLeft: const Landmark(0.45, 0.25, 0),
        cheekRight: const Landmark(0.75, 0.25, 0),
        nose: const Landmark(0.6, 0.25, 0),
        faceWidth: 0.3,
        neck: cuello(),
      );
      final anchor = strategy.computeAnchor(LandmarkFrame(neck: obs))!;

      expect(anchor.position.x, closeTo(0.6, 1e-9));
      expect(anchor.position.y, closeTo(0.4 + 0.05 * 1.5, 1e-9));
      expect(anchor.scale, closeTo(0.16 * 1.5, 1e-9));
    });

    test('el escote corrido da el giro del torso, con su signo', () {
      // Base de 0.16 (radio 0.08) y escote a su altura: d = frontAhead · 0.08.
      // Corrido 0.04 a la derecha.
      final anchor = strategy.computeAnchor(
        LandmarkFrame(neck: cara(neck: cuello(frenteX: 0.54, frenteY: 0.45))),
      )!;

      expect(
        anchor.yawRadians,
        closeTo(math.asin(0.04 / (strategy.frontAhead * 0.08)), 1e-9),
      );
    });

    test('un escote más bajo queda más adelante: menos giro por lo mismo', () {
      final alto = strategy.computeAnchor(
        LandmarkFrame(neck: cara(neck: cuello(frenteX: 0.54, frenteY: 0.45))),
      )!;
      final bajo = strategy.computeAnchor(
        LandmarkFrame(neck: cara(neck: cuello(frenteX: 0.54, frenteY: 0.55))),
      )!;

      expect(bajo.yawRadians!, lessThan(alto.yawRadians!));
      expect(bajo.yawRadians!, greaterThan(0));
    });

    test('sin escote a la vista, una fracción del giro de la cabeza', () {
      // Mejilla derecha 0.2·tan(30°) más lejos: la cabeza gira 30°.
      final z = 0.2 * math.tan(math.pi / 6);
      final anchor = strategy.computeAnchor(
        LandmarkFrame(neck: cara(neck: cuello(), zDerecha: z)),
      )!;

      expect(
        anchor.yawRadians,
        closeTo(math.pi / 6 * strategy.headYawFollow, 1e-9),
      );
    });

    test('la columna medida se usa si es coherente con la base', () {
      final buena = strategy.computeAnchor(
        LandmarkFrame(neck: cara(neck: cuello(columna: 0.14))),
      )!;
      final absurda = strategy.computeAnchor(
        LandmarkFrame(neck: cara(neck: cuello(columna: 0.3))),
      )!;

      expect(buena.limbWidth, closeTo(0.14, 1e-9));
      expect(absurda.limbWidth, closeTo(0.16 * strategy.columnToBase, 1e-9));
    });

    test('sin forma medida, el cuello sale de las proporciones de la cara',
        () {
      final anchor =
          strategy.computeAnchor(LandmarkFrame(neck: cara()))!;

      expect(anchor.position.x, closeTo(0.5, 1e-9));
      expect(anchor.position.y,
          closeTo(0.4 + strategy.defaultBaseBelowChin * 0.2, 1e-9));
      expect(anchor.scale, closeTo(strategy.defaultBaseToFace * 0.2, 1e-9));
    });

    test('trabaja en espacio isótropo: el aspecto no deforma la base', () {
      // Frame de 480x720: lo que baja 0.05 en alto son 0.075 anchos.
      const aspect = 480 / 720;
      final obs = NeckObservation(
        chin: const Landmark(0.5, 0.4, 0),
        cheekLeft: const Landmark(0.4, 0.35, 0),
        cheekRight: const Landmark(0.6, 0.35, 0),
        nose: const Landmark(0.5, 0.35, 0),
        // La cara mide el doble que cuando se midió: la base baja el doble.
        faceWidth: 0.4,
        neck: cuello(),
      );
      final anchor = strategy.computeAnchor(
        LandmarkFrame(neck: obs),
        imageAspect: aspect,
      )!;

      expect(anchor.position.y, closeTo(0.4 + 0.05 * 2, 1e-9));
      expect(anchor.rollRadians, closeTo(0, 1e-9));
    });
  });

  group('respuesta del nativo', () {
    Map<String, Object?> respuesta({Map<String, Object?>? neck}) => {
          'face': true,
          // mentón, mejilla de la imagen izquierda, la derecha, nariz
          'points': [
            0.30, 0.40, 0.0, //
            0.20, 0.30, 0.01, //
            0.40, 0.30, 0.02, //
            0.30, 0.30, -0.05,
          ],
          'faceWidth': 0.2,
          'neck': ?neck,
        };

    test('sin cara no hay frame', () {
      expect(neckFrameFromNative({'face': false}, 270).isEmpty, isTrue);
    });

    test('con el sensor a 270° espeja en horizontal, como la vista previa', () {
      final frame = neckFrameFromNative(respuesta(), 270);
      final obs = frame.neck!;

      expect(obs.chin.x, closeTo(0.70, 1e-9));
      expect(obs.chin.y, closeTo(0.40, 1e-9));
      // La mejilla izquierda de la imagen queda a la derecha de la pantalla.
      expect(obs.cheekLeft.x, closeTo(0.60, 1e-9));
      expect(obs.cheekLeft.z, closeTo(0.02, 1e-9));
      expect(obs.cheekRight.x, closeTo(0.80, 1e-9));
      expect(obs.faceWidth, 0.2);
      expect(obs.neck, isNull);
    });

    test('con el sensor a 90° no espeja', () {
      final obs = neckFrameFromNative(respuesta(), 90).neck!;
      expect(obs.chin.x, closeTo(0.30, 1e-9));
      expect(obs.cheekLeft.x, closeTo(0.20, 1e-9));
    });

    test('el cuello se espeja y sus lados se reordenan', () {
      final frame = neckFrameFromNative(
        respuesta(neck: {
          'leftX': 0.22,
          'leftY': 0.44,
          'rightX': 0.38,
          'rightY': 0.46,
          'hasFront': true,
          'frontX': 0.33,
          'frontY': 0.55,
          'narrow': 0.12,
          'refChinX': 0.30,
          'refChinY': 0.40,
          'refFaceWidth': 0.2,
        }),
        270,
      );
      final cuello = frame.neck!.neck!;

      expect(cuello.leftX, closeTo(0.62, 1e-9));
      expect(cuello.leftY, closeTo(0.46, 1e-9));
      expect(cuello.rightX, closeTo(0.78, 1e-9));
      expect(cuello.rightY, closeTo(0.44, 1e-9));
      expect(cuello.frontX, closeTo(0.67, 1e-9));
      expect(cuello.refChinX, closeTo(0.70, 1e-9));
      expect(cuello.narrowWidth, 0.12);
      // Puntos para el overlay: cara (4) + bordes (2) + escote (1).
      expect(frame.landmarks, hasLength(7));
    });

    test('sin escote visible no se inventa', () {
      final cuello = neckFrameFromNative(
        respuesta(neck: {
          'leftX': 0.22,
          'leftY': 0.44,
          'rightX': 0.38,
          'rightY': 0.46,
          'hasFront': false,
          'frontX': 0.0,
          'frontY': 0.0,
          'narrow': 0.0,
          'refChinX': 0.30,
          'refChinY': 0.40,
          'refFaceWidth': 0.2,
        }),
        270,
      ).neck!.neck!;

      expect(cuello.frontX, isNull);
      expect(cuello.frontY, isNull);
    });
  });
}
