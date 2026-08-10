import 'dart:math' as math;

/// Punto 2D del rostro en coordenadas normalizadas [0,1].
class FacePoint {
  final double x, y;
  const FacePoint(this.x, this.y);
}

/// Landmarks de rostro relevantes para aretes. ML Kit Face Detection entrega la
/// posición de la **oreja** (no del lóbulo) y ambos ojos; el lóbulo se estima.
class FaceSample {
  final FacePoint? leftEar, rightEar, leftEye, rightEye;
  final double confidence; // confianza de detección del rostro [0,1]
  const FaceSample({
    this.leftEar,
    this.rightEar,
    this.leftEye,
    this.rightEye,
    this.confidence = 1.0,
  });
}

/// Anclaje estimado de un arete sobre un lóbulo.
class EarringAnchor {
  final String side; // 'left' | 'right'
  final double x, y;
  final double rollRadians;
  final double confidence;
  const EarringAnchor({
    required this.side,
    required this.x,
    required this.y,
    required this.rollRadians,
    required this.confidence,
  });

  @override
  String toString() =>
      '$side(x=${x.toStringAsFixed(3)}, y=${y.toStringAsFixed(3)}, '
      'roll=${(rollRadians * 180 / math.pi).toStringAsFixed(1)}°, '
      'conf=${confidence.toStringAsFixed(2)})';
}

/// Estima los anclajes de arete (lóbulos) a partir de los landmarks de rostro.
///
/// ML Kit no expone un landmark de lóbulo: se estima **desplazando la posición
/// de la oreja hacia abajo**, a lo largo del eje vertical del rostro
/// (perpendicular a la línea de ojos), una fracción [dropFactor] de la distancia
/// interocular. La distancia interocular da la escala; la línea de ojos da la
/// inclinación (`roll`).
///
/// Requiere ambos ojos (para escala e inclinación). Devuelve un anclaje por
/// oreja disponible; lista vacía si falta información o la confianza es baja.
List<EarringAnchor> estimateEarringAnchors(
  FaceSample face, {
  double dropFactor = 0.45,
  double minConfidence = 0.5,
}) {
  final le = face.leftEye;
  final re = face.rightEye;
  if (le == null || re == null || face.confidence < minConfidence) {
    return const [];
  }

  final dx = re.x - le.x;
  final dy = re.y - le.y;
  final interocular = math.sqrt(dx * dx + dy * dy);
  if (interocular <= 0) return const [];

  final roll = math.atan2(dy, dx);
  // Eje "hacia abajo" del rostro (perpendicular a la línea de ojos).
  final downX = -math.sin(roll);
  final downY = math.cos(roll);
  final drop = dropFactor * interocular;

  final anchors = <EarringAnchor>[];
  void addEar(String side, FacePoint? ear) {
    if (ear == null) return;
    anchors.add(EarringAnchor(
      side: side,
      x: ear.x + downX * drop,
      y: ear.y + downY * drop,
      rollRadians: roll,
      confidence: face.confidence,
    ));
  }

  addEar('left', face.leftEar);
  addEar('right', face.rightEar);
  return anchors;
}
