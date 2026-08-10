import '../../../../core/error/result.dart';
import '../entities/jewelry_piece.dart';
import '../repositories/catalog_repository.dart';

/// Carga el catálogo completo de piezas.
class LoadCatalog {
  final CatalogRepository _repository;
  const LoadCatalog(this._repository);

  Future<Result<List<JewelryPiece>>> call() => _repository.getAll();
}
