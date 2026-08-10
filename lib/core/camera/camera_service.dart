import 'package:camera/camera.dart';

/// Encapsula la configuración y el stream de la cámara, con los ajustes
/// validados previamente (resolución media, YUV420, sin audio).
class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;

  /// Inicia el stream de la cámara indicada y entrega cada frame a [onFrame].
  ///
  /// [lensDirection] por defecto es trasera (pulseras: el usuario apunta a su
  /// muñeca); para aretes y collares se usa la frontal.
  Future<CameraController> startStream(
    void Function(CameraImage frame) onFrame, {
    CameraLensDirection lensDirection = CameraLensDirection.back,
    ResolutionPreset resolution = ResolutionPreset.medium,
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
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    await controller.startImageStream(onFrame);
    _controller = controller;
    return controller;
  }

  Future<void> dispose() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }
}
