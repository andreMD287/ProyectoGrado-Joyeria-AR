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
    // |0.78-0.5| > |0.30-0.5| → la caja se corrió hacia la derecha → elige
    // izquierdo (ver _lateralCandidate: el lado elegido es el contrario al
    // lóbulo mas lateral, verificado en dispositivo).
    final anchor = strategy.computeAnchor(faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.30, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.78, 0.58, 0.0, visibility: 1),
    ));

    expect(anchor, isNotNull);
    // ML Kit dibuja el bounding box con margen alrededor de la cara, así que
    // su borde queda por fuera de la oreja y el punto se mete hacia adentro.
    // Antes se empujaba hacia afuera y el ancla acababa sobre el fondo.
    expect(anchor!.position.x, greaterThan(0.30));
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

  test('cambia de lado si el giro hacia el otro lado se sostiene varios '
      'frames', () {
    final frontal = faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.30, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.70, 0.58, 0.0, visibility: 1),
    );
    final first = strategy.computeAnchor(frontal);
    expect(first, isNotNull);
    expect(first!.position.x, lessThan(0.5)); // bloquea izquierdo por defecto

    // Girar para exponer la oreja DERECHA corre toda la caja hacia la
    // izquierda de la pantalla (verificado en dispositivo): leftBBoxLobe se
    // aleja mas del centro que rightBBoxLobe.
    final giradoDerecha = faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.05, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.55, 0.58, 0.0, visibility: 1),
    );

    // 5 frames seguidos de giro: todavia no alcanza el umbral, sigue en
    // izquierdo.
    for (var i = 0; i < 4; i++) {
      strategy.computeAnchor(giradoDerecha);
    }
    final quinto = strategy.computeAnchor(giradoDerecha);
    expect(quinto!.position.x, lessThan(0.5));

    // 6to frame seguido de giro: ya cambia al lado derecho.
    final sexto = strategy.computeAnchor(giradoDerecha);
    expect(sexto!.position.x, greaterThan(0.5));
  });

  test('no cambia de lado si el giro no se sostiene (ruido de un solo '
      'frame)', () {
    final frontal = faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.30, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.70, 0.58, 0.0, visibility: 1),
    );
    strategy.computeAnchor(frontal);

    final giradoDerecha = faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.05, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.55, 0.58, 0.0, visibility: 1),
    );

    // Un solo frame de giro, luego vuelve de frente: no alcanza a cambiar.
    strategy.computeAnchor(giradoDerecha);
    final vuelta = strategy.computeAnchor(frontal);
    expect(vuelta!.position.x, lessThan(0.5));
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
      // El bbox derecho es mas lateral: sin forzar, ganaria el izquierdo.
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

  test(
      'de frente (bbox empatado) con solo la oreja derecha visible, elige '
      'el lado derecho', () {
    // bbox simetrico: |0.30-0.5| == |0.70-0.5| -> sin senal lateral real.
    final anchor = strategy.computeAnchor(faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.30, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.70, 0.58, 0.0, visibility: 1),
      rightEar: const Landmark(0.72, 0.55, 0.0, visibility: 1),
    ));

    expect(anchor, isNotNull);
    expect(anchor!.position.x, greaterThan(0.5));
  });

  test(
      'de frente (bbox empatado) con solo la oreja izquierda visible, elige '
      'el lado izquierdo', () {
    final anchor = strategy.computeAnchor(faceLandmarks(
      leftEye: const Landmark(0.42, 0.50, 0.0, visibility: 1),
      rightEye: const Landmark(0.58, 0.50, 0.0, visibility: 1),
      leftBBoxLobe: const Landmark(0.30, 0.58, 0.0, visibility: 1),
      rightBBoxLobe: const Landmark(0.70, 0.58, 0.0, visibility: 1),
      leftEar: const Landmark(0.28, 0.55, 0.0, visibility: 1),
    ));

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

    // Sin preferencia, gana el lado contrario al bbox mas lateral: el
    // izquierdo (rightBBoxLobe en 0.85 es el mas lateral).
    expect(anchor, isNotNull);
    expect(anchor!.position.x, lessThan(0.5));
  });
}
