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

  test('mete hacia adentro el lóbulo derivado del bbox', () {
    final anchor = strategy.computeAnchor(faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.30, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.78, 0.58, 0.0, visibility: 1),
    ));

    expect(anchor, isNotNull);
    // |0.78-0.5| > |0.30-0.5| → lado derecho.
    //
    // ML Kit dibuja el bounding box con margen alrededor de la cara, así que
    // su borde queda por fuera de la oreja y el punto se mete hacia adentro.
    // Antes se empujaba hacia afuera y el ancla acababa sobre el fondo.
    expect(anchor!.position.x, lessThan(0.78));
    expect(anchor.position.y, greaterThan(0.58));
  });

  test('mete hacia adentro tambien con la imagen espejada', () {
    // La camara frontal entrega la imagen espejada, asi que el lobulo que ML
    // Kit llama derecho aparece a la IZQUIERDA y su ojo derecho tiene menor x.
    // El ajuste se decide por la posicion en la imagen, no por la etiqueta:
    // con el indice de lado el empuje salia invertido y sacaba el ancla de la
    // cabeza (visto en dispositivo).
    final anchor = strategy.computeAnchor(faceLandmarks(
      leftEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.78, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.22, 0.58, 0.0, visibility: 1),
    ));

    expect(anchor, isNotNull);
    // Sea cual sea el lado que bloquee, el ancla tiene que quedar mas cerca
    // del centro que el borde del bbox, nunca mas lejos.
    final x = anchor!.position.x;
    final elegido = x > 0.5 ? 0.78 : 0.22;
    expect((x - 0.5).abs(), lessThan((elegido - 0.5).abs()));
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

  test('setPreferredSide fuerza el lado aunque el otro sea mas visible', () {
    final frame = faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      // El bbox derecho es mas lateral (mas visible): sin forzar, ganaria.
      leftBBoxLobe: const Landmark(0.35, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.85, 0.58, 0.0, visibility: 1),
    );

    strategy.setPreferredSide(0); // izquierdo
    final anchor = strategy.computeAnchor(frame);

    expect(anchor, isNotNull);
    // El lobulo izquierdo (bbox en 0.35) queda del lado izquierdo del centro.
    expect(anchor!.position.x, lessThan(0.5));
  });

  test('setPreferredSide sobrevive a reset (no es el lock de sesion)', () {
    final frame = faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.35, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.85, 0.58, 0.0, visibility: 1),
    );

    strategy.setPreferredSide(0);
    strategy.reset();
    final anchor = strategy.computeAnchor(frame);

    expect(anchor, isNotNull);
    expect(anchor!.position.x, lessThan(0.5));
  });

  test('setPreferredSide(null) vuelve al modo automatico', () {
    final frame = faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.35, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.85, 0.58, 0.0, visibility: 1),
    );

    strategy.setPreferredSide(0);
    strategy.computeAnchor(frame);
    strategy.setPreferredSide(null);
    strategy.reset();
    final anchor = strategy.computeAnchor(frame);

    // Sin preferencia, gana el lado mas lateral: el derecho (bbox en 0.85).
    expect(anchor, isNotNull);
    expect(anchor!.position.x, greaterThan(0.5));
  });
}
