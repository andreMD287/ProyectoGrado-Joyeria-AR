import 'dart:math' as math;

import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../../core/math/geometry.dart';
import '../entities/anchor_pose.dart';
import '../entities/landmark.dart';
import 'tracking_strategy.dart';

/// Aretes: ancla en el lóbulo, estimado a partir de los landmarks de rostro.
/// Validado en el spike B3.
///
/// ML Kit Face Detection no expone un landmark de lóbulo: entrega la posición de
/// la **oreja** y los ojos. El lóbulo se estima desplazando la oreja hacia abajo
/// —a lo largo del eje vertical del rostro (perpendicular a la línea de ojos)—
/// una fracción [dropFactor] de la distancia interocular.
///
/// El `FaceDetectorDataSource` entrega los landmarks en este orden fijo:
/// 0 = oreja izq · 1 = oreja der · 2 = ojo izq · 3 = ojo der.
///
/// La interfaz devuelve una sola [AnchorPose] (la oreja disponible); anclar
/// ambos aretes a la vez requerirá un resultado con múltiples anclajes (futuro).
class EarringStrategy implements TrackingStrategy {
  static const int leftEar = 0;
  static const int rightEar = 1;
  static const int leftEye = 2;
  static const int rightEye = 3;

  final double dropFactor;

  const EarringStrategy({this.dropFactor = 0.45});

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

    // Oreja disponible (se prioriza la izquierda como ancla determinista).
    final Landmark? ear = _present(landmarks[leftEar])
        ? landmarks[leftEar]
        : (_present(landmarks[rightEar]) ? landmarks[rightEar] : null);
    if (ear == null) return null;

    final dx = re.x - le.x;
    final dy = re.y - le.y;
    final interocular = math.sqrt(dx * dx + dy * dy);
    if (interocular <= 0) return null;

    final roll = math.atan2(dy, dx);
    final downX = -math.sin(roll);
    final downY = math.cos(roll);
    final drop = dropFactor * interocular;

    return AnchorPose(
      position: Vec3(ear.x + downX * drop, ear.y + downY * drop, ear.z),
      rollRadians: roll,
      confidence: 1,
    );
  }
}
