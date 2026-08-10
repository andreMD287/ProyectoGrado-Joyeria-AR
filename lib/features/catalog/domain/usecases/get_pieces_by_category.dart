import '../../../../core/error/result.dart';
import '../entities/jewelry_category.dart';
import '../entities/jewelry_piece.dart';
import '../repositories/catalog_repository.dart';

/// Devuelve las piezas de una categoría (aretes, pulseras o collares).
class GetPiecesByCategory {
  final CatalogRepository _repository;
  const GetPiecesByCategory(this._repository);

  Future<Result<List<JewelryPiece>>> call(JewelryCategory category) =>
      _repository.getByCategory(category);
}
