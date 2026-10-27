import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/vision/forearm_probe.dart';
import 'package:jewelry_ar/features/tracking/domain/entities/landmark.dart';

const _piel = Yuv(170, 110, 150);
const _fondo = Yuv(40, 128, 128);

/// Mano vertical (dedos arriba) con la muñeca en (0,5; 0,5) y palma de 0,2 de
/// ancho. Frame cuadrado para no mezclar el aspecto en la geometría.
List<Landmark> _mano() {
  final l = List.filled(21, const Landmark(0.5, 0.3, 0));
  l[0] = const Landmark(0.5, 0.5, 0);
  l[5] = const Landmark(0.6, 0.3, 0);
  l[17] = const Landmark(0.4, 0.3, 0);
  return l;
}

/// Imagen con la palma como un rectángulo de piel y el antebrazo como una
/// banda que sale de la muñeca desviada [grados] y corrida [corrimiento].
YuvSampler _imagen({
  required double grados,
  double ancho = 0.22,
  double corrimiento = 0,
  Yuv fondo = _fondo,
}) {
  final a = grados * math.pi / 180;
  final dx = math.sin(a), dy = math.cos(a); // hacia abajo, girado
  return (x, y) {
    if (x < 0 || x > 1 || y < 0 || y > 1) return null;
    if (y < 0.5 && y > 0.25 && (x - 0.5).abs() < 0.11) return _piel;
    final rx = x - (0.5 + corrimiento), ry = y - 0.5;
    final largo = rx * dx + ry * dy;
    final lateral = (rx * dy - ry * dx).abs();
    if (largo >= 0 && lateral <= ancho / 2) return _piel;
    return fondo;
  };
}

void main() {
  test('recupera la desviacion del antebrazo respecto a la mano', () {
    final obs = probeForearm(
      landmarks: _mano(),
      sample: _imagen(grados: 15),
      imageAspect: 1,
    )!;

    // Eje de la mano: recto hacia abajo. El brazo, 15° hacia +x.
    final grados = math.atan2(obs.dirX, obs.dirY) * 180 / math.pi;
    expect(grados, closeTo(15, 2));
    expect(obs.width, closeTo(0.22, 0.015));
  });

  test('sin desviacion devuelve el eje de la mano', () {
    final obs = probeForearm(
      landmarks: _mano(),
      sample: _imagen(grados: 0),
      imageAspect: 1,
    )!;
    expect(obs.dirX, closeTo(0, 0.02));
    expect(obs.dirY, closeTo(1, 0.01));
    expect(obs.originX, closeTo(0.5, 0.01));
  });

  test('corrige un brazo corrido respecto al landmark de la muneca', () {
    final obs = probeForearm(
      landmarks: _mano(),
      sample: _imagen(grados: 0, corrimiento: 0.03),
      imageAspect: 1,
    )!;
    expect(obs.originX, closeTo(0.53, 0.01));
  });

  test('con fondo del mismo color que la piel no inventa un brazo', () {
    final obs = probeForearm(
      landmarks: _mano(),
      sample: _imagen(grados: 10, fondo: _piel),
      imageAspect: 1,
    );
    expect(obs, isNull);
  });

  test('respeta el aspecto del frame', () {
    // Mismo brazo a 15°, pero el frame es el doble de alto que de ancho: el
    // ancho cubre x ∈ [0,1] y el alto, y ∈ [-0,5; 1,5]. Los landmarks llegan
    // normalizados a cada eje por separado, como los entrega el detector.
    final base = _imagen(grados: 15);
    Yuv? alto(double x, double y) => base(x, y * 2 - 0.5);
    final mano = [for (final l in _mano()) Landmark(l.x, (l.y + 0.5) / 2, 0)];
    final obs = probeForearm(landmarks: mano, sample: alto, imageAspect: 0.5)!;
    final grados = math.atan2(obs.dirX, obs.dirY) * 180 / math.pi;
    expect(grados, closeTo(15, 2));
  });
}
