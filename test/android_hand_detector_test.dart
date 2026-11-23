import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/features/tracking/data/datasources/android_hand_detector.dart';

/// Etiqueta de MediaPipe -> mano de la persona. Con la camara trasera la
/// etiqueta ya nombra la mano real (verificado en el Galaxy A15, 2026-11-22).
void main() {
  test("'Left' es la mano izquierda", () {
    expect(AndroidHandDetector.manoIzquierdaDe('Left', 0.99), isTrue);
  });

  test("'Right' es la mano derecha", () {
    expect(AndroidHandDetector.manoIzquierdaDe('Right', 0.96), isFalse);
  });

  test('sin etiqueta no se sabe', () {
    expect(AndroidHandDetector.manoIzquierdaDe(null, null), isNull);
  });

  test('con poca confianza se descarta (la mano entrando o saliendo)', () {
    expect(AndroidHandDetector.manoIzquierdaDe('Left', 0.62), isNull);
    expect(AndroidHandDetector.manoIzquierdaDe('Right', 0.53), isNull);
  });
}
