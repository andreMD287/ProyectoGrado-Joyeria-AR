import 'dart:async';

import 'package:camera/camera.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/filters/landmark_stabilizer.dart';
import '../../../../core/isolate/detection_isolate.dart';
import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../domain/entities/anchor_pose.dart';
import '../../domain/entities/tracking_frame.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/strategies/tracking_strategy.dart';

/// Pipeline de tracking en tiempo real:
/// cámara → [DetectionIsolate] → estrategia de anclaje → estabilizador →
/// [TrackingFrame].
///
/// - El **detector** (manos, rostro o pose, según la plataforma) vive dentro
///   de un isolate dedicado (spike B5): la detección es costosa (15–40 ms de
///   trabajo nativo por frame) y correrla en el isolate principal saturaba la
///   UI hasta el punto de producir ANR al cambiar de categoría.
/// - La **cámara** usa la lente trasera para pulseras (el usuario apunta a su
///   muñeca) y la frontal para aretes y collares.
/// - La detección se limita con throttling (≤10 FPS) para no encolar más
///   peticiones de las que el isolate puede procesar.
/// - Se estabilizan posición, orientación y escala por separado; el ángulo con
///   un filtro que no salta al cruzar ±π.
class TrackingRepositoryImpl implements TrackingRepository {
  final CameraService cameraService;
  final Map<JewelryCategory, TrackingStrategy> strategies;
  final LandmarkStabilizer stabilizer;

  static const int _minIntervalMs = 100; // ≤10 FPS de detección

  /// Margen antes de declarar perdido el tracking. Sin él, un solo frame sin
  /// detección (frecuentes con MediaPipe) haría parpadear la joya.
  static const int _lostGraceMs = 400;

  StreamController<TrackingFrame>? _controller;
  DetectionIsolate? _activeIsolate;
  JewelryCategory? _activeCategory;
  bool _busy = false;
  int _lastMs = 0;
  int _lastDetectionMs = 0;
  bool _lost = true;

  TrackingRepositoryImpl({
    required this.cameraService,
    required this.strategies,
    LandmarkStabilizer? stabilizer,
  }) : stabilizer = stabilizer ?? OneEuroStabilizer();

  LandmarkStabilizer _stabilizerFor(JewelryCategory category) {
    // Aretes: más suavizado — el bbox/landmarks faciales tiemblan más que pose.
    if (category == JewelryCategory.earring) {
      return OneEuroStabilizer(minCutoff: 0.4, beta: 0.007, dCutoff: 1.0);
    }
    return stabilizer;
  }

  LandmarkStabilizer? _sessionStabilizer;
  AngleStabilizer? _rollStabilizer;
  ScalarStabilizer? _scaleStabilizer;

  @override
  Stream<TrackingFrame> trackingStream(JewelryCategory category) {
    final strategy = strategies[category];
    if (strategy == null) {
      return const Stream<TrackingFrame>.empty();
    }

    final controller = StreamController<TrackingFrame>();

    controller.onListen = () async {
      try {
        await stop(); // asegura que no quede una sesión previa a medio liberar
        _controller = controller;
        _activeCategory = category;
        strategy.reset();
        _sessionStabilizer = _stabilizerFor(category);
        // El roll y la escala se mueven mucho más despacio que la posición y
        // son mucho más ruidosos: se filtran más agresivamente.
        _rollStabilizer = AngleStabilizer(minCutoff: 0.3, beta: 0.005);
        _scaleStabilizer = ScalarStabilizer(minCutoff: 0.3, beta: 0.005);
        _lost = true;
        _lastDetectionMs = 0;
        final isolate = DetectionIsolate();
        _activeIsolate = isolate;
        await isolate.start(strategy.detectorKind);
        await cameraService.startStream(
          (frame) => _onFrame(frame, strategy, isolate),
          lensDirection: _lensFor(category),
          imageFormatGroup: imageFormatGroupFor(strategy.detectorKind),
        );
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    };
    controller.onCancel = stop;
    return controller.stream;
  }

  Future<void> _onFrame(
    CameraImage frame,
    TrackingStrategy strategy,
    DetectionIsolate isolate,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_busy || now - _lastMs < _minIntervalMs) return;
    _busy = true;
    _lastMs = now;
    try {
      final orientation =
          cameraService.controller?.description.sensorOrientation ?? 0;
      final landmarks = await isolate.detect(frame, orientation);
      final anchor = strategy.computeAnchor(
        landmarks,
        imageAspect: uprightAspect(frame, orientation),
      );
      final controller = _controller;
      if (controller == null || controller.isClosed) return;

      if (anchor == null) {
        // Se espera el margen de gracia antes de avisar de la pérdida, y se
        // avisa una sola vez para no inundar la UI de reconstrucciones.
        if (!_lost && now - _lastDetectionMs > _lostGraceMs) {
          _lost = true;
          _resetFilters();
          controller.add(const TrackingFrame.lost());
        }
        return;
      }

      _lost = false;
      _lastDetectionMs = now;
      controller.add(TrackingFrame(
        anchor: _smooth(anchor, now / 1000.0),
        landmarks: landmarks,
      ));
    } catch (_) {
      // Se descarta el frame con error para no interrumpir el stream.
    } finally {
      _busy = false;
    }
  }

  AnchorPose _smooth(AnchorPose anchor, double tSeconds) {
    final position =
        (_sessionStabilizer ?? stabilizer).filter(anchor.position, tSeconds);
    final scale = anchor.scale;
    return AnchorPose(
      position: position,
      rollRadians:
          _rollStabilizer?.filter(anchor.rollRadians, tSeconds) ??
              anchor.rollRadians,
      scale: scale == null ? null : _scaleStabilizer?.filter(scale, tSeconds),
      confidence: anchor.confidence,
    );
  }

  /// Al recuperar el tracking la mano suele reaparecer en otro sitio; arrancar
  /// los filtros de cero evita que la joya cruce la pantalla deslizándose.
  void _resetFilters() {
    _sessionStabilizer?.reset();
    _rollStabilizer?.reset();
    _scaleStabilizer?.reset();
  }

  /// Relación ancho/alto del frame **ya rotado a vertical**, que es el marco en
  /// el que MediaPipe normaliza los landmarks cuando se le pasa la rotación
  /// del sensor. Con el sensor a 90°/270° los ejes del buffer están
  /// intercambiados respecto a lo que se ve en pantalla.
  static double uprightAspect(CameraImage frame, int sensorOrientation) {
    if (frame.width <= 0 || frame.height <= 0) return 1.0;
    final rotation = ((sensorOrientation % 360) + 360) % 360;
    final swapped = rotation == 90 || rotation == 270;
    final width = swapped ? frame.height : frame.width;
    final height = swapped ? frame.width : frame.height;
    return width / height;
  }

  CameraLensDirection _lensFor(JewelryCategory category) =>
      category == JewelryCategory.bracelet
          ? CameraLensDirection.back
          : CameraLensDirection.front;

  @override
  Future<void> stop() async {
    await cameraService.dispose();
    await _activeIsolate?.dispose();
    _activeIsolate = null;
    strategies[_activeCategory]?.reset();
    _activeCategory = null;
    _resetFilters();
    _sessionStabilizer = null;
    _rollStabilizer = null;
    _scaleStabilizer = null;
    stabilizer.reset();
    _lost = true;
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }
}
