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
    this.neckDropFactor = 0.06,
  });

  @override
  JewelryCategory get category => JewelryCategory.necklace;

  @override
  DetectorKind get detectorKind => DetectorKind.pose;

  @override
  void reset() {}

  @override
  AnchorPose? computeAnchor(List<Landmark> landmarks) {
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
    final width = math.sqrt(dx * dx + dy * dy);
    final anchorY = midY + neckDropFactor * width;
    final roll = math.atan2(dy, dx);

    return AnchorPose(
      position: Vec3(midX, anchorY, midZ),
      rollRadians: roll,
      confidence: math.min(lv, rv),
    );
  }
}
