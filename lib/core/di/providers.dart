import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/catalog/data/datasources/catalog_local_datasource.dart';
import '../../features/catalog/data/repositories/catalog_repository_impl.dart';
import '../../features/catalog/domain/entities/jewelry_category.dart';
import '../../features/catalog/domain/repositories/catalog_repository.dart';
import '../../features/tracking/data/datasources/android_hand_detector.dart';
import '../../features/tracking/data/datasources/face_detector_datasource.dart';
import '../../features/tracking/data/datasources/ios_hand_detector.dart';
import '../../features/tracking/data/datasources/landmark_detector.dart';
import '../../features/tracking/data/datasources/pose_detector_datasource.dart';
import '../../features/tracking/data/repositories/tracking_repository_impl.dart';
import '../../features/tracking/domain/repositories/tracking_repository.dart';
import '../../features/tracking/domain/strategies/bracelet_strategy.dart';
import '../../features/tracking/domain/strategies/earring_strategy.dart';
import '../../features/tracking/domain/strategies/necklace_strategy.dart';
import '../../features/tracking/domain/strategies/tracking_strategy.dart';
import '../camera/camera_service.dart';
import '../permissions/permission_service.dart';

// ── Servicios transversales ──────────────────────────────────────────────
final permissionServiceProvider =
    Provider<PermissionService>((ref) => const PermissionService());

final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraService();
  ref.onDispose(service.dispose);
  return service;
});

// ── Catálogo ──────────────────────────────────────────────────────────────
final catalogLocalDataSourceProvider =
    Provider<CatalogLocalDataSource>((ref) => const CatalogLocalDataSource());

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepositoryImpl(ref.watch(catalogLocalDataSourceProvider)),
);

// ── Tracking ────────────────────────────────────────────────────────────────
/// Detector de manos según plataforma (Android: MediaPipe/JNI; iOS: nativo B1).
final handDetectorProvider = Provider<LandmarkDetector>((ref) {
  return Platform.isIOS ? IosHandDetector() : AndroidHandDetector();
});

final faceDetectorProvider =
    Provider<LandmarkDetector>((ref) => FaceDetectorDataSource());

final poseDetectorProvider =
    Provider<LandmarkDetector>((ref) => PoseDetectorDataSource());

/// Detector por tipo, para que el repositorio elija según la estrategia.
final detectorsByKindProvider =
    Provider<Map<DetectorKind, LandmarkDetector>>((ref) {
  return {
    DetectorKind.hand: ref.watch(handDetectorProvider),
    DetectorKind.face: ref.watch(faceDetectorProvider),
    DetectorKind.pose: ref.watch(poseDetectorProvider),
  };
});

/// Estrategias de anclaje por categoría (patrón Strategy).
final trackingStrategiesProvider =
    Provider<Map<JewelryCategory, TrackingStrategy>>((ref) {
  return const {
    JewelryCategory.bracelet: BraceletStrategy(),
    JewelryCategory.earring: EarringStrategy(),
    JewelryCategory.necklace: NecklaceStrategy(),
  };
});

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  return TrackingRepositoryImpl(
    cameraService: ref.watch(cameraServiceProvider),
    detectors: ref.watch(detectorsByKindProvider),
    strategies: ref.watch(trackingStrategiesProvider),
  );
});
