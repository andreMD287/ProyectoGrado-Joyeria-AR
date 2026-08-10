import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/jewelry_category.dart';
import '../../domain/entities/jewelry_piece.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_local_datasource.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  final CatalogLocalDataSource _local;
  const CatalogRepositoryImpl(this._local);

  @override
  Future<Result<List<JewelryPiece>>> getAll() async {
    try {
      final models = await _local.loadPieces();
      return Ok(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Err(CatalogFailure('No se pudo cargar el catálogo: $e'));
    }
  }

  @override
  Future<Result<List<JewelryPiece>>> getByCategory(
      JewelryCategory category) async {
    final result = await getAll();
    return switch (result) {
      Ok(:final value) =>
        Ok(value.where((p) => p.categoria == category).toList()),
      Err(:final failure) => Err(failure),
    };
  }
}
