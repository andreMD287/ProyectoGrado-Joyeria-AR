import 'package:flutter_test/flutter_test.dart';
import 'package:jewelry_ar/features/tracking/data/datasources/ios_hand_detector.dart';

void main() {
  test('mapea la lista plana de Vision a landmarks (x, y, confidence)', () {
    // Dos articulaciones: muñeca y otra.
    final landmarks = mapVisionLandmarks([0.50, 0.60, 0.9, 0.10, 0.20, 0.7]);

    expect(landmarks.length, 2);
    expect(landmarks[0].x, 0.50);
    expect(landmarks[0].y, 0.60);
    expect(landmarks[0].z, 0.0); // Vision es 2D
    expect(landmarks[0].visibility, 0.9);
    expect(landmarks[1].x, 0.10);
    expect(landmarks[1].visibility, 0.7);
  });

  test('lista vacía o incompleta no rompe el mapeo', () {
    expect(mapVisionLandmarks(const []), isEmpty);
    // Una tripleta incompleta se ignora.
    expect(mapVisionLandmarks([0.5, 0.6]), isEmpty);
  });
}
