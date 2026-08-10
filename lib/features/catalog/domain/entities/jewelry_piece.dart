import 'jewelry_category.dart';

/// Dimensiones reales de la pieza en milímetros (insumo de calibración de
/// escala). `diametro` aplica a aretes/pulseras; `longitud` a collares.
class Dimensions {
  final double alto;
  final double ancho;
  final double profundidad;
  final double? diametro;
  final double? longitud;

  const Dimensions({
    required this.alto,
    required this.ancho,
    required this.profundidad,
    this.diametro,
    this.longitud,
  });
}

/// Pieza de joyería del catálogo. Entidad de dominio (sin dependencias de
/// framework). El esquema de metadatos está en `docs/D3_ESTRUCTURA_CATALOGO.md`.
class JewelryPiece {
  final String id;
  final String nombre;
  final JewelryCategory categoria;
  final String modeloGlb;
  final String foto;
  final Dimensions dimensionesMm;
  final String? material;
  final String? descripcion;

  const JewelryPiece({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.modeloGlb,
    required this.foto,
    required this.dimensionesMm,
    this.material,
    this.descripcion,
  });
}
