import '../../../../core/math/geometry.dart';

/// Resultado agnóstico de plataforma que consume el render AR: el punto de
/// anclaje (ya estabilizado), una orientación estimada y el tamaño aparente
/// de la pieza.
///
/// La orientación se modela por ahora como un ángulo de rotación en el plano
/// (`rollRadians`); se ampliará a una orientación 3D completa cuando las
/// estrategias estimen el eje de la pieza.
class AnchorPose {
  /// Punto de anclaje en coordenadas normalizadas del frame ya rotado a
  /// vertical (x, y ∈ [0,1]); z es profundidad relativa.
  final Vec3 position;

  /// Rotación de la pieza en el plano de la imagen, en radianes, medida desde
  /// el eje +x de la pantalla y creciendo en sentido horario (y crece hacia
  /// abajo). Cada estrategia documenta qué eje anatómico representa.
  final double rollRadians;

  /// Tamaño aparente de la pieza, expresado como fracción del **ancho** del
  /// frame. Permite que el overlay escale el modelo con la distancia sin
  /// conocer la anatomía: `pixeles = scale * anchoRenderizado * factorPieza`.
  ///
  /// `null` cuando la estrategia todavía no estima escala (aretes, collares):
  /// el overlay cae a su tamaño fijo por categoría.
  final double? scale;

  final double confidence;

  const AnchorPose({
    required this.position,
    this.rollRadians = 0,
    this.scale,
    this.confidence = 1,
  });
}
