import 'dart:math' as math;

import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../../core/math/geometry.dart';
import '../entities/anchor_pose.dart';
import '../entities/landmark.dart';
import 'tracking_strategy.dart';

/// Collares: ancla en el punto medio entre los hombros (landmarks 11 y 12 de
/// MediaPipe/ML Kit Pose). Ver spike B2.
class NecklaceStrategy implements TrackingStrategy {
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;

  const NecklaceStrategy();

  @override
  JewelryCategory get category => JewelryCategory.necklace;

  @override
  DetectorKind get detectorKind => DetectorKind.pose;

  @override
  AnchorPose? computeAnchor(List<Landmark> landmarks) {
    if (landmarks.length <= rightShoulder) return null;
    final l = landmarks[leftShoulder];
    final r = landmarks[rightShoulder];
    final mid = Vec3((l.x + r.x) / 2, (l.y + r.y) / 2, (l.z + r.z) / 2);
    // Inclinación de la línea de hombros → orientación del collar.
    final roll = math.atan2(r.y - l.y, r.x - l.x);
    final confidence =
        math.min(l.visibility ?? 1.0, r.visibility ?? 1.0).toDouble();
    return AnchorPose(position: mid, rollRadians: roll, confidence: confidence);
  }
}
