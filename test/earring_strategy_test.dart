import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark.dart';
import 'package:jewelry_ar/features/tracking/domain/strategies/earring_strategy.dart';

List<Landmark> faceLandmarks({
  Landmark? leftEar,
  Landmark? rightEar,
  Landmark? leftEye,
  Landmark? rightEye,
  Landmark? leftCheek,
  Landmark? rightCheek,
  Landmark? leftBBoxLobe,
  Landmark? rightBBoxLobe,
}) {
  const absent = Landmark(0, 0, 0, visibility: 0);
  return [
    leftEar ?? absent,
    rightEar ?? absent,
    leftEye ?? absent,
    rightEye ?? absent,
    leftCheek ?? absent,
    rightCheek ?? absent,
    leftBBoxLobe ?? absent,
    rightBBoxLobe ?? absent,
  ];
}

void main() {
  late EarringStrategy strategy;

  setUp(() {
    strategy = EarringStrategy();
  });

  test('usa lóbulo del bbox y empuja un poco afuera', () {
    final anchor = strategy.computeAnchor(faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.30, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.78, 0.58, 0.0, visibility: 1),
    ));

    expect(anchor, isNotNull);
    // |0.78-0.5| > |0.30-0.5| → lado derecho → outward +X
    expect(anchor!.position.x, greaterThan(0.78));
    expect(anchor.position.y, greaterThan(0.58));
  });

  test('no salta de lado entre frames (lock)', () {
    final frame = faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.28, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.72, 0.58, 0.0, visibility: 1),
    );
    final first = strategy.computeAnchor(frame)!;
    // Aunque el otro lado sea “mejor”, debe mantener el lock.
    final second = strategy.computeAnchor(frame)!;
    expect(second.position.x, closeTo(first.position.x, 1e-9));
  });

  test('devuelve null si faltan los ojos', () {
    expect(
      strategy.computeAnchor(faceLandmarks(
        leftBBoxLobe: const Landmark(0.28, 0.58, 0.0, visibility: 1),
      )),
      isNull,
    );
  });

  test('reset libera el lado bloqueado', () {
    final frame = faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.20, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.80, 0.58, 0.0, visibility: 1),
    );
    strategy.computeAnchor(frame);
    strategy.reset();
    final after = strategy.computeAnchor(frame);
    expect(after, isNotNull);
  });
}
