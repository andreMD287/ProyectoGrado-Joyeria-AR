import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark.dart';
import 'package:jewelry_ar/features/tracking/domain/strategies/earring_strategy.dart';

/// Lista de landmarks de rostro en el orden que espera EarringStrategy:
/// 0 oreja izq · 1 oreja der · 2 ojo izq · 3 ojo der. Un landmark ausente se
/// pasa como `null` (visibility 0).
List<Landmark> faceLandmarks({
  Landmark? leftEar,
  Landmark? rightEar,
  Landmark? leftEye,
  Landmark? rightEye,
}) {
  const absent = Landmark(0, 0, 0, visibility: 0);
  return [
    leftEar ?? absent,
    rightEar ?? absent,
    leftEye ?? absent,
    rightEye ?? absent,
  ];
}

void main() {
  const strategy = EarringStrategy();

  test('estima el lóbulo por debajo de la oreja en rostro frontal', () {
    final anchor = strategy.computeAnchor(faceLandmarks(
      leftEar: const Landmark(0.34, 0.52, 0.0, visibility: 1),
      rightEar: const Landmark(0.66, 0.52, 0.0, visibility: 1),
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
    ));

    expect(anchor, isNotNull);
    expect(anchor!.position.y, greaterThan(0.52)); // por debajo de la oreja
    expect(anchor.position.x, closeTo(0.34, 1e-6)); // ancla la oreja izquierda
    expect(anchor.rollRadians.abs(), lessThan(0.05));
  });

  test('roll sigue la inclinación de la cabeza', () {
    final anchor = strategy.computeAnchor(faceLandmarks(
      leftEar: const Landmark(0.34, 0.50, 0.0, visibility: 1),
      leftEye: const Landmark(0.42, 0.48, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.54, 0.0, visibility: 1),
    ));

    expect(anchor, isNotNull);
    expect(anchor!.rollRadians, greaterThan(0.05));
  });

  test('devuelve null si faltan los ojos', () {
    final anchor = strategy.computeAnchor(faceLandmarks(
      leftEar: const Landmark(0.34, 0.52, 0.0, visibility: 1),
    ));
    expect(anchor, isNull);
  });

  test('devuelve null si no hay ninguna oreja', () {
    final anchor = strategy.computeAnchor(faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
    ));
    expect(anchor, isNull);
  });
}
