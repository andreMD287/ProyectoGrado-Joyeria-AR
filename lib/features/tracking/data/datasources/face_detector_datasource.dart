import 'package:camera/camera.dart';

import '../../domain/entities/landmark.dart';

/// Detector facial para aretes, basado en `google_mlkit_face_detection`
/// (cross-platform). Provee landmarks y contornos del rostro.
///
/// TODO(B3/C1): configurar el detector (landmarks + contornos), mapear los
/// puntos relevantes del lóbulo a [Landmark] y decidir si ML Kit basta o se
/// requiere Face Mesh (468 puntos).
class FaceDetectorDataSource {
  Future<void> initialize() async {}

  Future<List<Landmark>> detect(CameraImage frame, int sensorOrientation) async {
    return const [];
  }

  Future<void> dispose() async {}
}
