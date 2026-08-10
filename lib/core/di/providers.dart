import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/catalog/data/datasources/catalog_local_datasource.dart';
import '../../features/catalog/data/repositories/catalog_repository_impl.dart';
import '../../features/catalog/domain/entities/jewelry_category.dart';
import '../../features/catalog/domain/repositories/catalog_repository.dart';
import '../../features/tracking/data/datasources/android_hand_detector.dart';
import '../../features/tracking/data/datasources/hand_detector.dart';
import '../../features/tracking/data/datasources/ios_hand_detector.dart';
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
final handDetectorProvider = Provider<HandDetector>((ref) {
  return Platform.isIOS ? IosHandDetector() : AndroidHandDetector();
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
    handDetector: ref.watch(handDetectorProvider),
    strategies: ref.watch(trackingStrategiesProvider),
  );
});
