import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/catalog/data/datasources/catalog_local_datasource.dart';
import '../../features/catalog/data/repositories/catalog_repository_impl.dart';
import '../../features/catalog/domain/entities/jewelry_category.dart';
import '../../features/catalog/domain/repositories/catalog_repository.dart';
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
/// Estrategias de anclaje por categoría (patrón Strategy). El detector de
/// cada estrategia (`DetectorKind`) se instancia dentro de un isolate
/// dedicado por sesión de tracking (ver `DetectionIsolate`), no aquí.
final trackingStrategiesProvider =
    Provider<Map<JewelryCategory, TrackingStrategy>>((ref) {
  return {
    JewelryCategory.bracelet: const BraceletStrategy(),
    JewelryCategory.earring: EarringStrategy(),
    JewelryCategory.necklace: const NecklaceStrategy(),
  };
});

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  return TrackingRepositoryImpl(
    cameraService: ref.watch(cameraServiceProvider),
    strategies: ref.watch(trackingStrategiesProvider),
  );
});
