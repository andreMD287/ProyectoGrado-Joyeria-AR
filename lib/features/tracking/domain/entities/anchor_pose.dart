import '../../../../core/math/geometry.dart';

/// Resultado agnóstico de plataforma que consume el render AR: el punto de
/// anclaje (ya estabilizado) y una orientación estimada de la pieza.
///
/// La orientación se modela por ahora como un ángulo de rotación en el plano
/// (`rollRadians`); se ampliará a una orientación 3D completa cuando las
/// estrategias estimen el eje de la pieza.
class AnchorPose {
  final Vec3 position;
  final double rollRadians;
  final double confidence;

  const AnchorPose({
    required this.position,
    this.rollRadians = 0,
    this.confidence = 1,
  });
}
