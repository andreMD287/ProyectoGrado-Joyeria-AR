import 'dart:io' show Platform;

import 'package:camera/camera.dart';

import '../../features/tracking/data/datasources/android_hand_detector.dart';
import '../../features/tracking/data/datasources/face_detector_datasource.dart';
import '../../features/tracking/data/datasources/ios_hand_detector.dart';
import '../../features/tracking/data/datasources/landmark_detector.dart';
import '../../features/tracking/data/datasources/pose_detector_datasource.dart';
import '../../features/tracking/domain/entities/landmark.dart';
import '../../features/tracking/domain/strategies/tracking_strategy.dart'
    show DetectorKind;

/// Dónde se ejecuta la detección de landmarks.
///
/// Hay dos implementaciones porque los detectores tienen restricciones
/// opuestas:
///
/// - **ML Kit (rostro y pose)** hace el trabajo pesado dentro de `detect()` y
///   bloquea a quien lo llame. Va en un isolate dedicado (spike B5); en el
///   isolate principal saturaba la UI hasta producir ANR al cambiar de
///   categoría.
/// - **MediaPipe manos en Android** (plugin 3.x) entrega el frame y vuelve de
///   inmediato, pero devuelve los resultados por un `EventChannel`, y Flutter
///   **no permite recibir mensajes del host en un isolate secundario**
///   (`Background isolates do not support setMessageHandler()`). Tiene que ir
///   en el isolate raíz — y como ya no bloquea, tampoco hace falta aislarlo.
abstract interface class DetectionRunner {
  Future<void> start(DetectorKind kind);

  /// Entrega un frame y devuelve los landmarks disponibles.
  Future<List<Landmark>> detect(CameraImage frame, int sensorOrientation);

  Future<void> dispose();
}

/// Formato de imagen de cámara que necesita cada [DetectorKind]: los
/// detectores basados en ML Kit (`InputImage.fromBytes`) requieren un solo
/// plano (`nv21` en Android, `bgra8888` en iOS); `hand_landmarker`
/// (MediaPipe vía JNI) requiere `yuv420`.
ImageFormatGroup imageFormatGroupFor(DetectorKind kind) => switch (kind) {
      DetectorKind.hand =>
        Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      DetectorKind.face ||
      DetectorKind.pose =>
        Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    };

/// Crea el detector que corresponde al tipo y a la plataforma.
LandmarkDetector createLandmarkDetector(DetectorKind kind) => switch (kind) {
      DetectorKind.hand =>
        Platform.isIOS ? IosHandDetector() : AndroidHandDetector(),
      DetectorKind.face => FaceDetectorDataSource(),
      DetectorKind.pose => PoseDetectorDataSource(),
    };

/// `true` si el detector de [kind] tiene que correr en el isolate raíz.
///
/// Solo las manos en Android: su plugin publica los resultados por un
/// `EventChannel`, que únicamente el isolate raíz puede escuchar.
bool requiresRootIsolate(DetectorKind kind) =>
    kind == DetectorKind.hand && Platform.isAndroid;

/// Ejecuta el detector en el isolate que lo crea, sin aislamiento.
///
/// Solo es aceptable para detectores que no bloquean: ver [requiresRootIsolate].
class InlineDetectionRunner implements DetectionRunner {
  LandmarkDetector? _detector;

  @override
  Future<void> start(DetectorKind kind) async {
    final detector = createLandmarkDetector(kind);
    await detector.initialize();
    _detector = detector;
  }

  @override
  Future<List<Landmark>> detect(CameraImage frame, int sensorOrientation) async {
    final detector = _detector;
    if (detector == null) return const [];
    try {
      return await detector.detect(frame, sensorOrientation);
    } catch (_) {
      // Un frame con error no debe interrumpir la sesión.
      return const [];
    }
  }

  @override
  Future<void> dispose() async {
    await _detector?.dispose();
    _detector = null;
  }
}
