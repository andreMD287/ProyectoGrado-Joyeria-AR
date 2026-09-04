import 'dart:math' as math;

import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../../core/math/geometry.dart';
import '../entities/anchor_pose.dart';
import '../entities/landmark.dart';
import 'tracking_strategy.dart';

/// Collares: ancla bajo la línea de hombros (landmarks 11 y 12 de
/// MediaPipe/ML Kit Pose). Validado en el spike B2.
///
/// El anclaje es el punto medio entre los hombros desplazado ligeramente hacia
/// abajo una fracción [neckDropFactor] del ancho de hombros (base del cuello /
/// clavícula, no el pecho). La inclinación (`roll`) se toma de la línea de
/// hombros. Devuelve `null` si la confianza de algún hombro es menor a
/// [minConfidence].
class NecklaceStrategy implements TrackingStrategy {
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;

  final double minConfidence;
  final double neckDropFactor;

  const NecklaceStrategy({
    this.minConfidence = 0.5,
    this.neckDropFactor = 0.02,
  });

  @override
  JewelryCategory get category => JewelryCategory.necklace;

  @override
  DetectorKind get detectorKind => DetectorKind.pose;

  @override
  void reset() {}

  @override
  AnchorPose? computeAnchor(
    List<Landmark> landmarks, {
    double imageAspect = 1.0,
  }) {
    if (landmarks.length <= rightShoulder) return null;
    final l = landmarks[leftShoulder];
    final r = landmarks[rightShoulder];
    final lv = l.visibility ?? 1.0;
    final rv = r.visibility ?? 1.0;
    if (lv < minConfidence || rv < minConfidence) return null;

    final midX = (l.x + r.x) / 2;
    final midY = (l.y + r.y) / 2;
    final midZ = (l.z + r.z) / 2;
    final dx = r.x - l.x;
    final dy = r.y - l.y;
    // Ancho de hombros medido en pantalla, corregido por aspecto: sin esto,
    // una foto vertical/horizontal medirian distinto el mismo ancho real.
    final width = _screenDistance(dx, dy, imageAspect);
    final anchorY = midY + neckDropFactor * width;
    // Eje de los hombros: su inclinación no depende del sentido en que se
    // recorra, y con la cámara frontal el vector viene invertido.
    final roll = normalizeAxisAngle(math.atan2(dy, dx));

    return AnchorPose(
      position: Vec3(midX, anchorY, midZ),
      rollRadians: roll,
      // Proxy de escala con la distancia a la cámara, igual que
      // `BraceletStrategy.palmWidth`: antes de esto el collar se dibujaba
      // siempre al tamaño fijo de categoria (`_fallbackSize`), que con una
      // cadena de eslabones finos se veía como puntos sueltos en vez de una
      // cadena continua.
      scale: width,
      confidence: math.min(lv, rv),
    );
  }

  /// Longitud de un desplazamiento normalizado medida en pantalla, expresada
  /// en unidades del ancho del frame. Mismo criterio que
  /// `BraceletStrategy._screenDistance`.
  static double _screenDistance(double dx, double dy, double imageAspect) {
    final scaledY = dy / imageAspect;
    return math.sqrt(dx * dx + scaledY * scaledY);
  }
}
