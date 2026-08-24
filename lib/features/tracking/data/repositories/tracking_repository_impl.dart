import 'dart:async';

import 'package:camera/camera.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/filters/landmark_stabilizer.dart';
import '../../../../core/isolate/detection_isolate.dart';
import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../domain/entities/anchor_pose.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/strategies/tracking_strategy.dart';

/// Pipeline de tracking en tiempo real:
/// cámara → [DetectionIsolate] → estrategia de anclaje → estabilizador →
/// [AnchorPose].
///
/// - El **detector** (manos, rostro o pose, según la plataforma) vive dentro
///   de un isolate dedicado (spike B5): la detección es costosa (15–40 ms de
///   trabajo nativo por frame) y correrla en el isolate principal saturaba la
///   UI hasta el punto de producir ANR al cambiar de categoría.
/// - La **cámara** usa la lente trasera para pulseras (el usuario apunta a su
///   muñeca) y la frontal para aretes y collares.
/// - La detección se limita con throttling (≤10 FPS) para no encolar más
///   peticiones de las que el isolate puede procesar.
class TrackingRepositoryImpl implements TrackingRepository {
  final CameraService cameraService;
  final Map<JewelryCategory, TrackingStrategy> strategies;
  final LandmarkStabilizer stabilizer;

  static const int _minIntervalMs = 100; // ≤10 FPS de detección

  StreamController<AnchorPose>? _controller;
  DetectionIsolate? _activeIsolate;
  JewelryCategory? _activeCategory;
  bool _busy = false;
  int _lastMs = 0;

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

  @override
  Stream<AnchorPose> anchorPoseStream(JewelryCategory category) {
    final strategy = strategies[category];
    if (strategy == null) {
      return const Stream<AnchorPose>.empty();
    }

    final controller = StreamController<AnchorPose>();

    controller.onListen = () async {
      try {
        await stop(); // asegura que no quede una sesión previa a medio liberar
        _controller = controller;
        _activeCategory = category;
        strategy.reset();
        _sessionStabilizer = _stabilizerFor(category);
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
      final anchor = strategy.computeAnchor(landmarks);
      final controller = _controller;
      final sessionFilter = _sessionStabilizer ?? stabilizer;
      if (anchor != null && controller != null && !controller.isClosed) {
        final smoothed = sessionFilter.filter(anchor.position, now / 1000.0);
        controller.add(AnchorPose(
          position: smoothed,
          rollRadians: anchor.rollRadians,
          confidence: anchor.confidence,
        ));
      }
    } catch (_) {
      // Se descarta el frame con error para no interrumpir el stream.
    } finally {
      _busy = false;
    }
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
    _sessionStabilizer?.reset();
    _sessionStabilizer = null;
    stabilizer.reset();
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }
}
