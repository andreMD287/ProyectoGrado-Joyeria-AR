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

  test('usa el lóbulo del bbox sin separarlo de la cara', () {
    final anchor = strategy.computeAnchor(faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.30, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.78, 0.58, 0.0, visibility: 1),
    ));

    expect(anchor, isNotNull);
    // |0.78-0.5| > |0.30-0.5| → lado derecho.
    //
    // El borde del bounding box ya es el límite exterior de la cara, así que
    // aquí NO se empuja hacia afuera. Antes sí se hacía, y en dispositivo el
    // ancla acababa fuera de la cabeza, sobre el fondo.
    expect(anchor!.position.x, closeTo(0.78, 1e-9));
    expect(anchor.position.y, greaterThan(0.58));
  });

  test('sí separa hacia afuera cuando el punto viene de la oreja de ML Kit', () {
    // Sin bbox ni mejilla: cae al landmark de oreja, que está en el centro de
    // la oreja y sí necesita el empuje hacia el lóbulo.
    final anchor = strategy.computeAnchor(faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      rightEar: const Landmark(0.72, 0.55, 0.0, visibility: 1),
    ));

    expect(anchor, isNotNull);
    expect(anchor!.position.x, greaterThan(0.72));
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
