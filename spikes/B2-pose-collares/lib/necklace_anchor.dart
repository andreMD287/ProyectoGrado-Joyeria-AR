import 'dart:math' as math;

/// Landmark de pose normalizado (x, y ∈ [0,1]; z profundidad relativa;
/// `visibility` = likelihood [0,1] que entrega ML Kit Pose).
class PoseLandmark {
  final double x, y, z;
  final double visibility;
  const PoseLandmark(this.x, this.y, this.z, {this.visibility = 1.0});
}

/// Punto de anclaje estimado para el collar.
class NecklaceAnchor {
  final double x, y, z; // posición de anclaje (normalizada)
  final double rollRadians; // inclinación de la línea de hombros
  final double shoulderWidth; // ancho de hombros → calibración de escala
  final double confidence;
  const NecklaceAnchor({
    required this.x,
    required this.y,
    required this.z,
    required this.rollRadians,
    required this.shoulderWidth,
    required this.confidence,
  });

  @override
  String toString() =>
      'anchor(x=${x.toStringAsFixed(3)}, y=${y.toStringAsFixed(3)}, '
      'roll=${(rollRadians * 180 / math.pi).toStringAsFixed(1)}°, '
      'width=${shoulderWidth.toStringAsFixed(3)}, conf=${confidence.toStringAsFixed(2)})';
}

/// Índices de hombros en el modelo de pose (coinciden con MediaPipe/BlazePose y
/// con el enum de ML Kit: leftShoulder = 11, rightShoulder = 12).
const int kLeftShoulder = 11;
const int kRightShoulder = 12;

/// Estima el punto de anclaje del collar a partir de los landmarks de pose.
///
/// El collar reposa bajo la línea de hombros: el anclaje es el punto medio entre
/// los hombros desplazado hacia abajo una fracción [neckDropFactor] del ancho de
/// hombros (y crece hacia abajo en coordenadas de imagen). La inclinación
/// (`roll`) se toma de la línea de hombros, y el ancho sirve para calibrar la
/// escala de la pieza.
///
/// Devuelve `null` si faltan los hombros o su confianza es menor a
/// [minConfidence].
NecklaceAnchor? estimateNecklaceAnchor(
  List<PoseLandmark> landmarks, {
  double minConfidence = 0.5,
  double neckDropFactor = 0.2,
}) {
  if (landmarks.length <= kRightShoulder) return null;
  final l = landmarks[kLeftShoulder];
  final r = landmarks[kRightShoulder];
  if (l.visibility < minConfidence || r.visibility < minConfidence) return null;

  final midX = (l.x + r.x) / 2;
  final midY = (l.y + r.y) / 2;
  final midZ = (l.z + r.z) / 2;
  final dx = r.x - l.x;
  final dy = r.y - l.y;
  final width = math.sqrt(dx * dx + dy * dy);
  final anchorY = midY + neckDropFactor * width;
  final roll = math.atan2(dy, dx);
  final confidence = math.min(l.visibility, r.visibility);

  return NecklaceAnchor(
    x: midX,
    y: anchorY,
    z: midZ,
    rollRadians: roll,
    shoulderWidth: width,
    confidence: confidence,
  );
}
