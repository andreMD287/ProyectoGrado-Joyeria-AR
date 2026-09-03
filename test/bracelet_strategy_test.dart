import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark.dart';
import 'package:jewelry_ar/features/tracking/domain/strategies/bracelet_strategy.dart';

/// Construye los 21 landmarks de MediaPipe Hands con todo en el origen salvo
/// los tres que usa la estrategia.
List<Landmark> hand({
  required (double, double) wrist,
  required (double, double) indexMcp,
  required (double, double) pinkyMcp,
}) {
  final points = List<Landmark>.filled(21, const Landmark(0, 0, 0));
  points[BraceletStrategy.wristLandmark] = Landmark(wrist.$1, wrist.$2, 0);
  points[BraceletStrategy.indexMcpLandmark] =
      Landmark(indexMcp.$1, indexMcp.$2, 0);
  points[BraceletStrategy.pinkyMcpLandmark] =
      Landmark(pinkyMcp.$1, pinkyMcp.$2, 0);
  return points;
}

void main() {
  const strategy = BraceletStrategy();

  group('anclaje en el antebrazo', () {
    test('desplaza el ancla mas alla de la muneca, alejandose de la palma', () {
      // Palma centrada en (0.5, 0.4), muneca 0.2 mas abajo: el antebrazo baja.
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
        ),
      )!;

      // muneca.y + (muneca.y - palma.y) * forearmOffset = 0.6 + 0.2 * 0.45
      expect(anchor.position.y, closeTo(0.69, 1e-9));
      expect(anchor.position.x, closeTo(0.5, 1e-9));
    });

    test('no se queda en el landmark de la muneca', () {
      const wristY = 0.6;
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, wristY),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
        ),
      )!;

      expect(anchor.position.y, greaterThan(wristY));
    });

    test('respeta la direccion de la mano, no solo el eje vertical', () {
      // Mano apuntando a la izquierda: la palma queda a la derecha del ancla.
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.4, 0.5),
          indexMcp: (0.6, 0.45),
          pinkyMcp: (0.6, 0.55),
        ),
      )!;

      expect(anchor.position.x, lessThan(0.4));
      expect(anchor.position.y, closeTo(0.5, 1e-9));
    });

    test('forearmOffset calibra cuanto se avanza hacia el codo', () {
      final points = hand(
        wrist: (0.5, 0.6),
        indexMcp: (0.4, 0.4),
        pinkyMcp: (0.6, 0.4),
      );

      final corto = const BraceletStrategy(forearmOffset: 0.2)
          .computeAnchor(points)!;
      final largo = const BraceletStrategy(forearmOffset: 0.8)
          .computeAnchor(points)!;

      expect(corto.position.y, lessThan(largo.position.y));
    });
  });

  group('escala', () {
    test('reporta el ancho de la palma en fracciones del ancho del frame', () {
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
        ),
      )!;

      expect(anchor.scale, closeTo(0.2, 1e-9));
    });

    test('crece cuando la mano se acerca a la camara', () {
      final lejos = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.55),
          indexMcp: (0.45, 0.5),
          pinkyMcp: (0.55, 0.5),
        ),
      )!;
      final cerca = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.8),
          indexMcp: (0.3, 0.4),
          pinkyMcp: (0.7, 0.4),
        ),
      )!;

      expect(cerca.scale!, greaterThan(lejos.scale!));
    });

    test('corrige por aspecto: una palma vertical no mide menos que una '
        'horizontal del mismo tamano real', () {
      // Frame 1:2 (mas alto que ancho). Un desplazamiento de 0.2 en y ocupa el
      // doble de pixeles que uno de 0.2 en x.
      const aspect = 0.5;

      final horizontal = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.7),
          indexMcp: (0.4, 0.5),
          pinkyMcp: (0.6, 0.5),
        ),
        imageAspect: aspect,
      )!;
      final vertical = strategy.computeAnchor(
        hand(
          wrist: (0.7, 0.5),
          indexMcp: (0.5, 0.45),
          pinkyMcp: (0.5, 0.55),
        ),
        imageAspect: aspect,
      )!;

      // 0.2 en x -> 0.2 anchos; 0.1 en y -> 0.1/0.5 = 0.2 anchos.
      expect(horizontal.scale, closeTo(0.2, 1e-9));
      expect(vertical.scale, closeTo(0.2, 1e-9));
    });
  });

  group('orientacion', () {
    test('el roll sigue el eje del antebrazo', () {
      // Antebrazo hacia abajo en pantalla: +90 grados (y crece hacia abajo).
      final abajo = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.6),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
        ),
      )!;
      expect(abajo.rollRadians, closeTo(math.pi / 2, 1e-9));

      // Antebrazo hacia la izquierda: 180 grados.
      final izquierda = strategy.computeAnchor(
        hand(
          wrist: (0.4, 0.5),
          indexMcp: (0.6, 0.45),
          pinkyMcp: (0.6, 0.55),
        ),
      )!;
      expect(izquierda.rollRadians.abs(), closeTo(math.pi, 1e-9));
    });

    test('el angulo tiene en cuenta el aspecto del frame', () {
      // Mismo desplazamiento normalizado, distinto aspecto: en un frame mas
      // alto que ancho el eje se ve mas inclinado de lo que sugiere el crudo.
      final points = hand(
        wrist: (0.6, 0.6),
        indexMcp: (0.45, 0.5),
        pinkyMcp: (0.55, 0.5),
      );

      final cuadrado = strategy.computeAnchor(points, imageAspect: 1.0)!;
      final alto = strategy.computeAnchor(points, imageAspect: 0.5)!;

      expect(cuadrado.rollRadians, closeTo(math.pi / 4, 1e-9));
      expect(alto.rollRadians, greaterThan(cuadrado.rollRadians));
      expect(alto.rollRadians, closeTo(math.atan2(0.2, 0.1), 1e-9));
    });
  });

  group('rechazo de detecciones malas', () {
    test('sin landmarks suficientes devuelve null', () {
      expect(strategy.computeAnchor(const []), isNull);
      expect(
        strategy.computeAnchor(List.filled(10, const Landmark(0, 0, 0))),
        isNull,
      );
    });

    test('descarta manos demasiado pequenas en el encuadre', () {
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.505),
          indexMcp: (0.495, 0.5),
          pinkyMcp: (0.505, 0.5),
        ),
      );

      expect(anchor, isNull);
    });

    test('descarta la mano degenerada (palma y muneca en el mismo punto)', () {
      final anchor = strategy.computeAnchor(
        hand(
          wrist: (0.5, 0.4),
          indexMcp: (0.4, 0.4),
          pinkyMcp: (0.6, 0.4),
        ),
      );

      expect(anchor, isNull);
    });
  });
}
