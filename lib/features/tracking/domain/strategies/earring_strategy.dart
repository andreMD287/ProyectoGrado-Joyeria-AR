import 'dart:math' as math;

import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../../core/math/geometry.dart';
import '../entities/anchor_pose.dart';
import '../entities/landmark.dart';
import 'tracking_strategy.dart';

/// Aretes: ancla en el lóbulo, estimado a partir de los landmarks de rostro.
///
/// ML Kit no expone lóbulo: entrega la **oreja** (cerca del tragus) y los ojos.
/// El lóbulo se estima en **espacio del preview de cámara** (y crece hacia
/// abajo), no en el eje “abajo” del rostro: en Android portrait ese eje puede
/// apuntar hacia arriba en pantalla y dejar el modelo sobre la oreja.
///
/// - [dropFactor]: hacia abajo en el preview (+Y).
/// - [outwardFactor]: hacia afuera en X (oreja izq → −X, oreja der → +X).
///
/// Orden fijo del `FaceDetectorDataSource`:
/// 0 = oreja izq · 1 = oreja der · 2 = ojo izq · 3 = ojo der.
class EarringStrategy implements TrackingStrategy {
  static const int leftEar = 0;
  static const int rightEar = 1;
  static const int leftEye = 2;
  static const int rightEye = 3;

  final double dropFactor;
  final double outwardFactor;

  const EarringStrategy({
    this.dropFactor = 0.32,
    this.outwardFactor = 0.28,
  });

  @override
  JewelryCategory get category => JewelryCategory.earring;

  @override
  DetectorKind get detectorKind => DetectorKind.face;

  bool _present(Landmark lm) => (lm.visibility ?? 0) > 0;

  @override
  AnchorPose? computeAnchor(List<Landmark> landmarks) {
    if (landmarks.length <= rightEye) return null;
    final le = landmarks[leftEye];
    final re = landmarks[rightEye];
    if (!_present(le) || !_present(re)) return null;

    final bool useLeft = _present(landmarks[leftEar]);
    final Landmark? ear = useLeft
        ? landmarks[leftEar]
        : (_present(landmarks[rightEar]) ? landmarks[rightEar] : null);
    if (ear == null) return null;

    final dx = re.x - le.x;
    final dy = re.y - le.y;
    final interocular = math.sqrt(dx * dx + dy * dy);
    if (interocular <= 0) return null;

    final roll = math.atan2(dy, dx);
    final drop = dropFactor * interocular;
    final out = outwardFactor * interocular;
    final outwardX = useLeft ? -out : out;

    return AnchorPose(
      position: Vec3(
        ear.x + outwardX,
        ear.y + drop,
        ear.z,
      ),
      rollRadians: roll,
      confidence: 1,
    );
  }
}
