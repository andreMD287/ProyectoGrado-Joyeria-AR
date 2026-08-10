import 'package:camera/camera.dart';

import '../../domain/entities/landmark.dart';

/// Detector de pose para collares, basado en `google_mlkit_pose_detection`
/// (cross-platform). Interesan los hombros (landmarks 11 y 12).
///
/// TODO(B2): configurar el detector, mapear los hombros a [Landmark] y validar
/// la estimación del punto de anclaje del collar con cámara frontal.
class PoseDetectorDataSource {
  Future<void> initialize() async {}

  Future<List<Landmark>> detect(CameraImage frame, int sensorOrientation) async {
    return const [];
  }

  Future<void> dispose() async {}
}
