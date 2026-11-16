import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark_frame.dart';
import 'package:jewelry_ar/features/tracking/domain/strategies/necklace_strategy.dart';

/// Construye una lista de landmarks con solo los hombros definidos.
LandmarkFrame poseWithShoulders(Landmark left, Landmark right) {
  final list = List<Landmark>.filled(13, const Landmark(0, 0, 0, visibility: 0));
  list[NecklaceStrategy.leftShoulder] = left;
  list[NecklaceStrategy.rightShoulder] = right;
  return LandmarkFrame(landmarks: list);
}

void main() {
  const strategy = NecklaceStrategy();

  test('ancla en la base del cuello, sobre la línea de hombros', () {
    final anchor = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.40, 0.50, 0.0, visibility: 0.96),
      const Landmark(0.60, 0.50, 0.0, visibility: 0.95),
    ));

    expect(anchor, isNotNull);
    expect(anchor!.position.x, closeTo(0.5, 1e-9));
    // width = 0.2, neckRaise = 0.18 → sube 0.036
    expect(anchor.position.y, closeTo(0.464, 1e-9));
    expect(anchor.rollRadians.abs(), lessThan(0.05));
    expect(anchor.scale, closeTo(0.2, 1e-9));
  });

  test('la subida al cuello se corrige por aspecto', () {
    // Frame 1:2: una distancia vertical ocupa el doble en y normalizada.
    final anchor = strategy.computeAnchor(
      poseWithShoulders(
        const Landmark(0.40, 0.50, 0.0, visibility: 0.9),
        const Landmark(0.60, 0.50, 0.0, visibility: 0.9),
      ),
      imageAspect: 0.5,
    );

    expect(anchor!.position.y, closeTo(0.50 - 0.036 * 0.5, 1e-9));
  });

  test('con los hombros inclinados sube perpendicular a ellos', () {
    final anchor = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.40, 0.45, 0.0, visibility: 0.9),
      const Landmark(0.60, 0.55, 0.0, visibility: 0.9),
    ));

    // Hombro derecho más bajo: el cuello queda corrido hacia la derecha.
    expect(anchor!.position.x, greaterThan(0.5));
    expect(anchor.position.y, lessThan(0.5));
  });

  test('el giro del torso sale de la profundidad de los hombros', () {
    const strategy = NecklaceStrategy(yawGain: 1);
    final deFrente = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.40, 0.50, -0.3, visibility: 0.9),
      const Landmark(0.60, 0.50, -0.3, visibility: 0.9),
    ));
    final girado = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.40, 0.50, -0.1, visibility: 0.9),
      const Landmark(0.60, 0.50, 0.1, visibility: 0.9),
    ));
    // Mismo giro con los hombros en el orden contrario (cámara espejada).
    final espejado = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.60, 0.50, 0.1, visibility: 0.9),
      const Landmark(0.40, 0.50, -0.1, visibility: 0.9),
    ));

    expect(deFrente!.yawRadians, closeTo(0, 1e-9));
    // Se aleja el hombro de la derecha: Δz = 0.2 sobre 0.2 de ancho → 45°.
    expect(girado!.yawRadians, closeTo(math.pi / 4, 1e-9));
    expect(espejado!.yawRadians, closeTo(math.pi / 4, 1e-9));
  });

  test('la ganancia atenúa el giro que exagera ML Kit', () {
    final anchor = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.40, 0.50, -0.1, visibility: 0.9),
      const Landmark(0.60, 0.50, 0.1, visibility: 0.9),
    ));

    expect(anchor!.yawRadians, closeTo(math.atan(strategy.yawGain), 1e-9));
  });

  test('el giro del torso se acota', () {
    final anchor = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.49, 0.50, -0.5, visibility: 0.9),
      const Landmark(0.51, 0.50, 0.5, visibility: 0.9),
    ));

    expect(anchor!.yawRadians, closeTo(strategy.maxYaw, 1e-9));
  });

  test('con el torso girado el cuello se corre hacia donde mira el pecho', () {
    final deFrente = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.40, 0.50, 0.0, visibility: 0.9),
      const Landmark(0.60, 0.50, 0.0, visibility: 0.9),
    ));
    // Se aleja el hombro de la derecha: el pecho mira a la derecha.
    final girado = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.40, 0.50, -0.2, visibility: 0.9),
      const Landmark(0.60, 0.50, 0.2, visibility: 0.9),
    ));

    expect(girado!.yawRadians, greaterThan(0));
    expect(
      girado.position.x - deFrente!.position.x,
      closeTo(strategy.neckShift * 0.2 * math.tan(girado.yawRadians!), 1e-9),
    );
  });

  /// Hombros en 0.40–0.60 y orejas centradas en [orejasX], con una
  /// profundidad de hombros que, si se usara, diría lo contrario.
  List<Landmark> conOrejas(double orejasX, {double? narizX}) {
    final frame = poseWithShoulders(
      const Landmark(0.40, 0.50, 0.3, visibility: 0.9),
      const Landmark(0.60, 0.50, -0.3, visibility: 0.9),
    );
    final puntos = [...frame.landmarks];
    puntos[NecklaceStrategy.leftEar] =
        Landmark(orejasX - 0.05, 0.30, 0, visibility: 0.9);
    puntos[NecklaceStrategy.rightEar] =
        Landmark(orejasX + 0.05, 0.30, 0, visibility: 0.9);
    if (narizX != null) {
      puntos[NecklaceStrategy.nose] =
          Landmark(narizX, 0.30, 0, visibility: 0.9);
    }
    return puntos;
  }

  test('con orejas visibles el giro sale de ellas, no de la profundidad', () {
    final anchor =
        strategy.computeAnchor(LandmarkFrame(landmarks: conOrejas(0.527)));

    // Corridas 0.027 sobre 0.2 de ancho: sin θ = 0.027 / (0.27 · 0.2) = 0.5.
    expect(anchor!.yawRadians, closeTo(math.pi / 6, 1e-6));
  });

  test('de frente, orejas centradas: sin giro y cuello al centro', () {
    final anchor =
        strategy.computeAnchor(LandmarkFrame(landmarks: conOrejas(0.50)));

    expect(anchor!.yawRadians, closeTo(0, 1e-9));
    expect(anchor.position.x, closeTo(0.50, 1e-9));
  });

  test('girado, el cuello queda detrás de las orejas, hacia la nuca', () {
    final anchor =
        strategy.computeAnchor(LandmarkFrame(landmarks: conOrejas(0.527)));

    final giro = math.sin(anchor!.yawRadians! - strategy.yawDeadZone);
    expect(
      anchor.position.x,
      closeTo(0.527 - strategy.neckBehindEars * 0.2 * giro, 1e-9),
    );
  });

  test('la nariz y las orejas se promedian para ubicar el cuello', () {
    // Orejas y nariz con desvíos opuestos dentro de la zona muerta del giro.
    final anchor = strategy.computeAnchor(
      LandmarkFrame(landmarks: conOrejas(0.504, narizX: 0.516)),
    );

    expect(
      anchor!.yawRadians!.abs(),
      lessThan(strategy.yawDeadZone),
    );
    expect(anchor.position.x, closeTo(0.51, 1e-9));
  });

  test('sin profundidad no inventa giro', () {
    final anchor = strategy.computeAnchor(poseWithShoulders(
      const Landmark(0.40, 0.50, 0.0, visibility: 0.9),
      const Landmark(0.60, 0.50, 0.0, visibility: 0.9),
    ));

    expect(anchor!.yawRadians, isNull);
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
    expect(strategy.computeAnchor(LandmarkFrame.empty), isNull);
  });
}
