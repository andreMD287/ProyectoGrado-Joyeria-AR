import '../../domain/entities/jewelry_category.dart';
import '../../domain/entities/jewelry_piece.dart';

/// DTO de una pieza: conoce el formato JSON del catálogo y lo traduce a la
/// entidad de dominio. Aísla al dominio de la estructura de `catalog.json`.
class JewelryPieceModel {
  final String id;
  final String nombre;
  final String categoria;
  final String modeloGlb;
  final String foto;
  final Map<String, dynamic> dimensionesMm;
  final String? material;
  final String? descripcion;

  const JewelryPieceModel({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.modeloGlb,
    required this.foto,
    required this.dimensionesMm,
    this.material,
    this.descripcion,
  });

  factory JewelryPieceModel.fromJson(Map<String, dynamic> json) {
    return JewelryPieceModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      categoria: json['categoria'] as String,
      modeloGlb: json['modelo_glb'] as String,
      foto: json['foto'] as String,
      dimensionesMm: (json['dimensiones_mm'] as Map).cast<String, dynamic>(),
      material: json['material'] as String?,
      descripcion: json['descripcion'] as String?,
    );
  }

  JewelryPiece toEntity() {
    double? asDouble(Object? v) => v == null ? null : (v as num).toDouble();
    return JewelryPiece(
      id: id,
      nombre: nombre,
      categoria: JewelryCategory.fromId(categoria),
      modeloGlb: modeloGlb,
      foto: foto,
      dimensionesMm: Dimensions(
        alto: asDouble(dimensionesMm['alto']) ?? 0,
        ancho: asDouble(dimensionesMm['ancho']) ?? 0,
        profundidad: asDouble(dimensionesMm['profundidad']) ?? 0,
        diametro: asDouble(dimensionesMm['diametro']),
        longitud: asDouble(dimensionesMm['longitud']),
      ),
      material: material,
      descripcion: descripcion,
    );
  }
}
