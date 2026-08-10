import 'dart:async';

import 'package:camera/camera.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/filters/landmark_stabilizer.dart';
import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../domain/entities/anchor_pose.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/strategies/tracking_strategy.dart';
import '../datasources/landmark_detector.dart';

/// Pipeline de tracking en tiempo real:
/// cámara → detector → estrategia de anclaje → estabilizador → [AnchorPose].
///
/// - El **detector** se elige según el `DetectorKind` de la estrategia (manos,
///   rostro o pose) y la plataforma.
/// - La **cámara** usa la lente trasera para pulseras (el usuario apunta a su
///   muñeca) y la frontal para aretes y collares.
/// - La detección se limita con throttling (≤10 FPS) para no saturar el isolate
///   principal; la solución de fondo es el isolate dedicado (spike B5).
class TrackingRepositoryImpl implements TrackingRepository {
  final CameraService cameraService;
  final Map<DetectorKind, LandmarkDetector> detectors;
  final Map<JewelryCategory, TrackingStrategy> strategies;
  final LandmarkStabilizer stabilizer;

  static const int _minIntervalMs = 100; // ≤10 FPS de detección

  StreamController<AnchorPose>? _controller;
  LandmarkDetector? _activeDetector;
  bool _busy = false;
  int _lastMs = 0;

  TrackingRepositoryImpl({
    required this.cameraService,
    required this.detectors,
    required this.strategies,
    LandmarkStabilizer? stabilizer,
  }) : stabilizer = stabilizer ?? OneEuroStabilizer();

  @override
  Stream<AnchorPose> anchorPoseStream(JewelryCategory category) {
    final strategy = strategies[category];
    final detector = strategy == null ? null : detectors[strategy.detectorKind];
    if (strategy == null || detector == null) {
      return const Stream<AnchorPose>.empty();
    }

    final controller = StreamController<AnchorPose>();
    _controller = controller;
    _activeDetector = detector;

    controller.onListen = () async {
      try {
        await detector.initialize();
        await cameraService.startStream(
          (frame) => _onFrame(frame, strategy, detector),
          lensDirection: _lensFor(category),
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
    LandmarkDetector detector,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_busy || now - _lastMs < _minIntervalMs) return;
    _busy = true;
    _lastMs = now;
    try {
      final orientation =
          cameraService.controller?.description.sensorOrientation ?? 0;
      final landmarks = await detector.detect(frame, orientation);
      final anchor = strategy.computeAnchor(landmarks);
      final controller = _controller;
      if (anchor != null && controller != null && !controller.isClosed) {
        final smoothed = stabilizer.filter(anchor.position, now / 1000.0);
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
    await _activeDetector?.dispose();
    _activeDetector = null;
    stabilizer.reset();
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }
}
