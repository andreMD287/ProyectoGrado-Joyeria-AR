import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/features/tracking/data/datasources/ios_neck_face_datasource.dart';
import 'package:jewelry_ar/features/tracking/domain/strategies/necklace_strategy.dart';

/// Contorno circular de radio [r] (en anchos de frame) centrado en (cx, cy),
/// en un frame de aspecto alto/ancho [aspect]. Con [roll] se ladea la cara.
List<Pt> contorno({
  double cx = 0.5,
  double cy = 0.4,
  double r = 0.1,
  double aspect = 4 / 3,
  int n = 36,
}) =>
    [
      for (var i = 0; i < n; i++)
        (
          x: cx + r * math.sin(2 * math.pi * i / n),
          y: cy - r * math.cos(2 * math.pi * i / n) / aspect,
        ),
    ];

void main() {
  const aspect = 4 / 3;

  group('neckFrameFromFaceContour', () {
    test('de frente: mentón abajo, mejillas a los lados, sin giro', () {
      final f = neckFrameFromFaceContour(
        contour: contorno(),
        nose: (x: 0.5, y: 0.4),
        eyes: (x: 0.5, y: 0.37),
        mouth: (x: 0.5, y: 0.44),
        headYawDegrees: 0,
        frameAspect: aspect,
      );
      final o = f.neck!;
      expect(o.chin.x, closeTo(0.5, 1e-9));
      expect(o.chin.y, closeTo(0.4 + 0.1 / aspect, 1e-9));
      expect(o.cheekLeft.x, closeTo(0.4, 1e-9));
      expect(o.cheekRight.x, closeTo(0.6, 1e-9));
      expect(o.faceWidth, closeTo(0.2, 1e-9));
      expect(o.cheekRight.z - o.cheekLeft.z, closeTo(0, 1e-9));
      expect(o.neck, isNull);
    });

    test('el signo del giro sale de hacia dónde se corre la nariz', () {
      double giro(double narizX, double yawMlKit) {
        final o = neckFrameFromFaceContour(
          contour: contorno(),
          nose: (x: narizX, y: 0.4),
          eyes: null,
          mouth: null,
          headYawDegrees: yawMlKit,
          frameAspect: aspect,
        ).neck!;
        return math.atan2(
          o.cheekRight.z - o.cheekLeft.z,
          o.cheekRight.x - o.cheekLeft.x,
        );
      }

      // El signo del ángulo de ML Kit no importa: manda la nariz.
      expect(giro(0.53, 20), closeTo(20 * math.pi / 180, 1e-9));
      expect(giro(0.53, -20), closeTo(20 * math.pi / 180, 1e-9));
      expect(giro(0.47, 20), closeTo(-20 * math.pi / 180, 1e-9));
    });

    test('con la cabeza girada el ancho se corrige hacia arriba', () {
      final o = neckFrameFromFaceContour(
        contour: contorno(),
        nose: (x: 0.53, y: 0.4),
        eyes: null,
        mouth: null,
        headYawDegrees: 40,
        frameAspect: aspect,
      ).neck!;
      expect(o.faceWidth, greaterThan(0.2));
      expect(
        o.faceWidth,
        closeTo(
          0.2 / math.pow(math.cos(40 * math.pi / 180), faceWidthYawExponent),
          1e-9,
        ),
      );
    });

    test('cabeza ladeada: el mentón sigue la dirección ojos→boca', () {
      // Ladeada 30°: "abajo" de la cara apunta abajo y a la izquierda.
      const a = 30 * math.pi / 180;
      final abajo = (x: -math.sin(a), y: math.cos(a));
      const ojos = (x: 0.5, y: 0.4);
      final boca = (
        x: ojos.x + 0.05 * abajo.x,
        y: ojos.y + 0.05 * abajo.y / aspect,
      );
      final o = neckFrameFromFaceContour(
        contour: contorno(),
        nose: (x: 0.5, y: 0.4),
        eyes: ojos,
        mouth: boca,
        headYawDegrees: 0,
        frameAspect: aspect,
      ).neck!;
      expect(o.chin.x, lessThan(0.5));
      expect(o.chin.x, closeTo(0.5 + 0.1 * abajo.x, 0.02));
    });

    test('la estrategia del collar cuelga el collar bajo el mentón', () {
      final f = neckFrameFromFaceContour(
        contour: contorno(),
        nose: (x: 0.5, y: 0.4),
        eyes: (x: 0.5, y: 0.37),
        mouth: (x: 0.5, y: 0.44),
        headYawDegrees: 0,
        frameAspect: aspect,
      );
      final pose = const NecklaceStrategy()
          .computeAnchor(f, imageAspect: 1 / aspect);
      expect(pose, isNotNull);
      expect(pose!.position.x, closeTo(0.5, 1e-9));
      expect(pose.position.y, greaterThan(f.neck!.chin.y));
      expect(pose.yawRadians, closeTo(0, 1e-9));
    });

    test('contorno vacío: nada', () {
      final f = neckFrameFromFaceContour(
        contour: const [],
        nose: null,
        eyes: null,
        mouth: null,
        headYawDegrees: 0,
        frameAspect: aspect,
      );
      expect(f.neck, isNull);
    });
  });
}
