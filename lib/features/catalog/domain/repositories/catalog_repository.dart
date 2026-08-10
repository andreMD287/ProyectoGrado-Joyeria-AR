import '../../../../core/error/result.dart';
import '../entities/jewelry_category.dart';
import '../entities/jewelry_piece.dart';

/// Frontera hacia la capa de datos del catálogo. La presentación y los casos de
/// uso dependen de esta interfaz, nunca de la fuente concreta (local o remota).
abstract interface class CatalogRepository {
  Future<Result<List<JewelryPiece>>> getAll();
  Future<Result<List<JewelryPiece>>> getByCategory(JewelryCategory category);
}
