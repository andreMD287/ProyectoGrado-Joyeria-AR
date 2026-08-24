import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../../core/math/geometry.dart';
import '../entities/anchor_pose.dart';
import '../entities/landmark.dart';
import 'tracking_strategy.dart';

/// Pulseras: ancla en la muñeca (landmark 0 / WRIST de MediaPipe Hands).
class BraceletStrategy implements TrackingStrategy {
  static const int wristLandmark = 0;

  const BraceletStrategy();

  @override
  JewelryCategory get category => JewelryCategory.bracelet;

  @override
  DetectorKind get detectorKind => DetectorKind.hand;

  @override
  void reset() {}

  @override
  AnchorPose? computeAnchor(List<Landmark> landmarks) {
    if (landmarks.length <= wristLandmark) return null;
    final w = landmarks[wristLandmark];
    return AnchorPose(
      position: Vec3(w.x, w.y, w.z),
      confidence: w.visibility ?? 1.0,
    );
  }
}
