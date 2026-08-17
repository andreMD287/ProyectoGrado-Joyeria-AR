import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Encapsula la configuración y el stream de la cámara, con los ajustes
/// validados previamente (resolución media, YUV420, sin audio).
class CameraService {
  /// Observable para que la UI (vista previa) sepa cuándo el controlador
  /// queda listo, sin depender de que ya haya llegado una detección.
  final ValueNotifier<CameraController?> controllerNotifier =
      ValueNotifier(null);

  CameraController? get controller => controllerNotifier.value;

  /// Inicia el stream de la cámara indicada y entrega cada frame a [onFrame].
  ///
  /// [lensDirection] por defecto es trasera (pulseras: el usuario apunta a su
  /// muñeca); para aretes y collares se usa la frontal.
  Future<CameraController> startStream(
    void Function(CameraImage frame) onFrame, {
    CameraLensDirection lensDirection = CameraLensDirection.back,
    ResolutionPreset resolution = ResolutionPreset.medium,
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.yuv420,
  }) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw StateError('No se encontraron cámaras disponibles.');
    }
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == lensDirection,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      camera,
      resolution,
      enableAudio: false,
      imageFormatGroup: imageFormatGroup,
    );
    await controller.initialize();
    await controller.startImageStream(onFrame);
    controllerNotifier.value = controller;
    return controller;
  }

  Future<void> dispose() async {
    final controller = controllerNotifier.value;
    controllerNotifier.value = null;
    await controller?.stopImageStream();
    await controller?.dispose();
  }
}
