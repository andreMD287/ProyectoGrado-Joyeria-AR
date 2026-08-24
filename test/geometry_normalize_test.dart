import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/core/math/geometry.dart';

const bufferW = 1280;
const bufferH = 720;

void main() {
  group('normalizeMlKitLandmarkToPreview', () {
    test('Android 90°: dimensiones intercambiadas (sin espejo frontal)', () {
      final n = normalizeMlKitLandmarkToPreview(
        pixelX: 360,
        pixelY: 900,
        bufferWidth: bufferW,
        bufferHeight: bufferH,
        rotationDegrees: 90,
        isFrontCamera: true,
        isIOS: false,
      );

      expect(n.x, closeTo(360 / bufferH, 1e-9));
      expect(n.y, closeTo(900 / bufferW, 1e-9));
      expect(n.y, inInclusiveRange(0.0, 1.0));
    });

    test('Android 270°: espeja X por rotación', () {
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
    });

    test('iOS: división simple', () {
      final n = normalizeMlKitLandmarkToPreview(
        pixelX: 640,
        pixelY: 360,
        bufferWidth: bufferW,
        bufferHeight: bufferH,
        rotationDegrees: 90,
        isFrontCamera: true,
        isIOS: true,
      );
      expect(n.x, closeTo(640 / bufferW, 1e-9));
      expect(n.y, closeTo(360 / bufferH, 1e-9));
    });

    test('frontal 0°: espeja X', () {
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
    });

    test('trasera 0°: no espeja', () {
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
    });
  });
}
