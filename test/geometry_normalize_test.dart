import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/math/geometry.dart';

/// Buffer típico landscape de cámara Android (antes de rotar a portrait).
const bufferW = 1280;
const bufferH = 720;

void main() {
  group('normalizeMlKitLandmarkToPreview', () {
    test('Android 90°: usa dimensiones intercambiadas (evita y > 1)', () {
      // Caso del bug: y en espacio rotado llega a ~900 px; / height(720) → 1.25.
      final buggyY = 900.0 / bufferH;
      expect(buggyY, greaterThan(1.0));

      final n = normalizeMlKitLandmarkToPreview(
        pixelX: 360,
        pixelY: 900,
        bufferWidth: bufferW,
        bufferHeight: bufferH,
        rotationDegrees: 90,
        isFrontCamera: true,
        isIOS: false,
      );

      expect(n.x, closeTo(360 / bufferH, 1e-9)); // / height
      expect(n.y, closeTo(900 / bufferW, 1e-9)); // / width
      expect(n.x, inInclusiveRange(0.0, 1.0));
      expect(n.y, inInclusiveRange(0.0, 1.0));
    });

    test('Android 270°: espeja X y usa dimensiones intercambiadas', () {
      final n = normalizeMlKitLandmarkToPreview(
        pixelX: 360,
        pixelY: 640,
        bufferWidth: bufferW,
        bufferHeight: bufferH,
        rotationDegrees: 270,
        isFrontCamera: true,
        isIOS: false,
      );

      expect(n.x, closeTo(1.0 - 360 / bufferH, 1e-9));
      expect(n.y, closeTo(640 / bufferW, 1e-9));
      expect(n.x, inInclusiveRange(0.0, 1.0));
      expect(n.y, inInclusiveRange(0.0, 1.0));
    });

    test('iOS: división simple sin corrección de rotación ni espejo', () {
      final at90 = normalizeMlKitLandmarkToPreview(
        pixelX: 640,
        pixelY: 360,
        bufferWidth: bufferW,
        bufferHeight: bufferH,
        rotationDegrees: 90,
        isFrontCamera: true,
        isIOS: true,
      );
      expect(at90.x, closeTo(640 / bufferW, 1e-9));
      expect(at90.y, closeTo(360 / bufferH, 1e-9));

      final at0 = normalizeMlKitLandmarkToPreview(
        pixelX: 320,
        pixelY: 360,
        bufferWidth: bufferW,
        bufferHeight: bufferH,
        rotationDegrees: 0,
        isFrontCamera: true,
        isIOS: true,
      );
      // iOS no aplica espejo frontal (comportamiento previo al fix).
      expect(at0.x, closeTo(320 / bufferW, 1e-9));
      expect(at0.y, closeTo(360 / bufferH, 1e-9));
    });

    test('frontal 0°: espeja X como el CameraPreview', () {
      final n = normalizeMlKitLandmarkToPreview(
        pixelX: 320,
        pixelY: 360,
        bufferWidth: bufferW,
        bufferHeight: bufferH,
        rotationDegrees: 0,
        isFrontCamera: true,
        isIOS: false,
      );

      expect(n.x, closeTo(1.0 - 320 / bufferW, 1e-9));
      expect(n.y, closeTo(360 / bufferH, 1e-9));
    });

    test('trasera 0°: no espeja X', () {
      final n = normalizeMlKitLandmarkToPreview(
        pixelX: 320,
        pixelY: 360,
        bufferWidth: bufferW,
        bufferHeight: bufferH,
        rotationDegrees: 0,
        isFrontCamera: false,
        isIOS: false,
      );

      expect(n.x, closeTo(320 / bufferW, 1e-9));
      expect(n.y, closeTo(360 / bufferH, 1e-9));
    });

    test('esquinas Android 90° quedan en [0,1]', () {
      final topLeft = normalizeMlKitLandmarkToPreview(
        pixelX: 0,
        pixelY: 0,
        bufferWidth: bufferW,
        bufferHeight: bufferH,
        rotationDegrees: 90,
        isFrontCamera: true,
        isIOS: false,
      );
      final bottomRight = normalizeMlKitLandmarkToPreview(
        pixelX: bufferH.toDouble(),
        pixelY: bufferW.toDouble(),
        bufferWidth: bufferW,
        bufferHeight: bufferH,
        rotationDegrees: 90,
        isFrontCamera: true,
        isIOS: false,
      );

      expect(topLeft.x, 0.0);
      expect(topLeft.y, 0.0);
      expect(bottomRight.x, 1.0);
      expect(bottomRight.y, 1.0);
    });
  });
}
