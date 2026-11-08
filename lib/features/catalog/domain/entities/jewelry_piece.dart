import 'earring_type.dart';
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

  /// Corrección de giro (eje vertical, grados) para modelos exportados con el
  /// frente hacia atrás. 0 = sin corrección. Ver `orientacion_yaw_deg` en
  /// `catalog.json` / D3.
  final double orientacionYawDeg;

  /// Solo aretes: cómo se sujeta al lóbulo (`tipo_arete`). `null` si el
  /// catálogo no lo dice; entonces se deduce de la forma del modelo.
  final EarringType? tipoArete;

  /// Solo aretes: punto del modelo que va en el lóbulo (`punto_sujecion`), en
  /// unidades del GLB y ya con [orientacionYawDeg] aplicado. `null` si no se
  /// indicó; entonces se busca un nodo `sujecion` en el GLB y, si tampoco hay,
  /// se deduce de la forma (ver D1).
  final List<double>? puntoSujecion;

  const JewelryPiece({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.modeloGlb,
    required this.foto,
    required this.dimensionesMm,
    this.material,
    this.descripcion,
    this.orientacionYawDeg = 0,
    this.tipoArete,
    this.puntoSujecion,
  });
}
