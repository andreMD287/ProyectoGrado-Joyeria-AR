import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/jewelry_piece.dart';
import '../../domain/usecases/load_catalog.dart';

/// Expone el catálogo de piezas como estado asíncrono. La UI lo consume con
/// `AsyncValue` (loading / data / error).
class CatalogController extends AsyncNotifier<List<JewelryPiece>> {
  @override
  Future<List<JewelryPiece>> build() async {
    final loadCatalog = LoadCatalog(ref.watch(catalogRepositoryProvider));
    final result = await loadCatalog();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw Exception(failure.message),
    };
  }
}

final catalogControllerProvider =
    AsyncNotifierProvider<CatalogController, List<JewelryPiece>>(
  CatalogController.new,
);
