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
    // width = 0.2, neckDropFactor = 0.02 → y = 0.50 + 0.004
    expect(anchor.position.y, closeTo(0.504, 1e-9));
    expect(anchor.rollRadians.abs(), lessThan(0.05));
    expect(anchor.scale, closeTo(0.2, 1e-9));
  });

  test('scale crece si los hombros se ven mas anchos (mas cerca)', () {
    final lejos = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.45, 0.50, 0.0, visibility: 0.9),
      const Landmark(0.55, 0.50, 0.0, visibility: 0.9),
    ));
    final cerca = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.30, 0.50, 0.0, visibility: 0.9),
      const Landmark(0.70, 0.50, 0.0, visibility: 0.9),
    ));

    expect(cerca!.scale, greaterThan(lejos!.scale!));
  });

  test(
      'corrige por aspecto: hombros inclinados no miden menos que hombros '
      'nivelados del mismo ancho real', () {
    // Frame 1:2 (mas alto que ancho). Un desplazamiento de 0.1 en y ocupa el
    // doble de pixeles que uno de 0.1 en x.
    const aspect = 0.5;

    final nivelado = strategy.computeAnchor(
      poseWithShoulders(
        const Landmark(0.40, 0.50, 0.0, visibility: 0.9),
        const Landmark(0.60, 0.50, 0.0, visibility: 0.9),
      ),
      imageAspect: aspect,
    );
    final inclinado = strategy.computeAnchor(
      poseWithShoulders(
        const Landmark(0.50, 0.45, 0.0, visibility: 0.9),
        const Landmark(0.50, 0.55, 0.0, visibility: 0.9),
      ),
      imageAspect: aspect,
    );

    // 0.2 en x -> 0.2 anchos; 0.1 en y -> 0.1/0.5 = 0.2 anchos.
    expect(nivelado!.scale, closeTo(0.2, 1e-9));
    expect(inclinado!.scale, closeTo(0.2, 1e-9));
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
