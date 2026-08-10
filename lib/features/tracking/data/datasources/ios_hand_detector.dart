import 'package:camera/camera.dart';

import '../../domain/entities/landmark.dart';
import 'hand_detector.dart';

/// Detector de manos en iOS. `hand_landmarker` no soporta iOS (usa JNI), por lo
/// que aquí se consume una implementación nativa vía platform channel
/// (`PlatformChannels.iosHandTracking`): Vision (`VNDetectHumanHandPoseRequest`)
/// o MediaPipe Tasks. La alternativa se decide en el spike B1.
///
/// TODO(B1/C2): implementar el puente con el código nativo iOS.
class IosHandDetector implements HandDetector {
  @override
  Future<void> initialize() async {}

  @override
  Future<List<Landmark>> detect(CameraImage frame, int sensorOrientation) async {
    return const [];
  }

  @override
  Future<void> dispose() async {}
}
