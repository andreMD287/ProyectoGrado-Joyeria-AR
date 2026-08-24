import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark.dart';
import 'package:jewelry_ar/features/tracking/domain/strategies/necklace_strategy.dart';

/// Construye una lista de landmarks con solo los hombros definidos.
List<Landmark> poseWithShoulders(Landmark left, Landmark right) {
  final list = List<Landmark>.filled(13, const Landmark(0, 0, 0, visibility: 0));
  list[NecklaceStrategy.leftShoulder] = left;
  list[NecklaceStrategy.rightShoulder] = right;
  return list;
}

void main() {
  const strategy = NecklaceStrategy();

  test('ancla centrado cerca del cuello (poco drop bajo hombros)', () {
    final anchor = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.40, 0.50, 0.0, visibility: 0.96),
      const Landmark(0.60, 0.50, 0.0, visibility: 0.95),
    ));

    expect(anchor, isNotNull);
    expect(anchor!.position.x, closeTo(0.5, 1e-9));
    // width = 0.2, neckDropFactor = 0.06 → y = 0.50 + 0.012
    expect(anchor.position.y, closeTo(0.512, 1e-9));
    expect(anchor.rollRadians.abs(), lessThan(0.05));
  });

  test('roll sigue la inclinación de la línea de hombros', () {
    final anchor = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.40, 0.48, 0.0, visibility: 0.9),
      const Landmark(0.60, 0.56, 0.0, visibility: 0.9),
    ));

    expect(anchor, isNotNull);
    expect(anchor!.rollRadians, greaterThan(0.05));
  });

  test('devuelve null si la confianza de un hombro es baja', () {
    final anchor = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.40, 0.50, 0.0, visibility: 0.3),
      const Landmark(0.60, 0.50, 0.0, visibility: 0.3),
    ));

    expect(anchor, isNull);
  });

  test('devuelve null si faltan los hombros', () {
    expect(strategy.computeAnchor(const []), isNull);
  });
}
