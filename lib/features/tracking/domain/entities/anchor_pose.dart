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

  /// Giro fuera del plano de la imagen (pronación/supinación de la muñeca),
  /// en radianes. `null` cuando la estrategia no lo estima.
  ///
  /// A diferencia de [rollRadians] (que gira la imagen plana en pantalla),
  /// esto orienta el propio modelo 3D — sirve para que la pieza "se voltee"
  /// cuando el usuario gira la muñeca, no solo cuando inclina el brazo.
  /// Signo y magnitud son una aproximación 2D (sin profundidad real): ver
  /// `BraceletStrategy._estimateYaw`.
  final double? yawRadians;

  /// Eje del miembro que sostiene la pieza, **en 3D y unitario**, expresado en
  /// el espacio métrico de la cámara ya enderezado (x a la derecha, y hacia
  /// abajo, z alejándose).
  ///
  /// A diferencia de [rollRadians] y [yawRadians], que son aproximaciones
  /// medidas sobre la imagen, esto viene de la reconstrucción métrica del
  /// detector: es la orientación real del antebrazo en el espacio. Con ella el
  /// render puede orientar la pieza de verdad en vez de girar una imagen plana.
  ///
  /// `null` cuando el detector no entrega reconstrucción métrica.
  final Vec3? axis3D;

  /// Medida real, **en metros**, de la misma distancia anatómica que [scale]
  /// reporta en fracciones del ancho del frame.
  ///
  /// Las dos juntas dan la distancia a la cámara —una es el tamaño real y la
  /// otra el aparente—, pero hace falta además el campo de visión del objetivo,
  /// que es cosa de quien renderiza y no de la estrategia. Por eso aquí se
  /// entrega el dato crudo y no la profundidad ya calculada.
  ///
  /// `null` cuando el detector no entrega reconstrucción métrica.
  final double? metricWidth;

  final double confidence;

  const AnchorPose({
    required this.position,
    this.rollRadians = 0,
    this.scale,
    this.yawRadians,
    this.axis3D,
    this.metricWidth,
    this.confidence = 1,
  });
}
