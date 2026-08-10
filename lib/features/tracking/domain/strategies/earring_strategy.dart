import '../../../catalog/domain/entities/jewelry_category.dart';
import '../entities/anchor_pose.dart';
import '../entities/landmark.dart';
import 'tracking_strategy.dart';

/// Aretes: ancla en el/los lóbulo(s) de la oreja. El índice exacto del landmark
/// depende del resultado del spike B3 (ML Kit Face Detection vs. Face Mesh),
/// por eso `computeAnchor` queda pendiente de definir con esa evidencia.
class EarringStrategy implements TrackingStrategy {
  const EarringStrategy();

  @override
  JewelryCategory get category => JewelryCategory.earring;

  @override
  DetectorKind get detectorKind => DetectorKind.face;

  @override
  AnchorPose? computeAnchor(List<Landmark> landmarks) {
    // TODO(B3/C1): mapear el/los landmark(s) de lóbulo una vez definido el
    // detector facial (ML Kit o Face Mesh) y validada su precisión.
    return null;
  }
}
