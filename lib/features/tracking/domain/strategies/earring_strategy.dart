import 'dart:math' as math;

import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../../core/math/geometry.dart';
import '../entities/anchor_pose.dart';
import '../entities/landmark.dart';
import 'tracking_strategy.dart';

/// Aretes: ancla en el lóbulo.
///
/// De frente, los landmarks de oreja de ML Kit son inestables (aparecen /
/// desaparecen) y alternar izq/der hace que el modelo salte por toda la cara.
/// Por eso el anclaje primario son los puntos derivados del **bounding box**
/// del rostro (índices 6 y 7), con un lado **bloqueado** durante la sesión.
///
/// Orden del `FaceDetectorDataSource`:
/// 0–1 orejas · 2–3 ojos · 4–5 mejillas · 6–7 lóbulos bbox.
class EarringStrategy implements TrackingStrategy {
  static const int leftEar = 0;
  static const int rightEar = 1;
  static const int leftEye = 2;
  static const int rightEye = 3;
  static const int leftCheek = 4;
  static const int rightCheek = 5;
  static const int leftBBoxLobe = 6;
  static const int rightBBoxLobe = 7;

  /// 0 = izquierdo (bbox/oreja izq de ML Kit), 1 = derecho. Null = aún no fijado.
  int? _lockedSide;
  int _missFrames = 0;
  static const int _maxMissBeforeUnlock = 8;

  EarringStrategy();

  @override
  JewelryCategory get category => JewelryCategory.earring;

  @override
  DetectorKind get detectorKind => DetectorKind.face;

  @override
  void reset() {
    _lockedSide = null;
    _missFrames = 0;
  }

  bool _present(Landmark lm) => (lm.visibility ?? 0) > 0;

  @override
  AnchorPose? computeAnchor(
    List<Landmark> landmarks, {
    double imageAspect = 1.0, // esta estrategia aun no estima escala ni roll
  }) {
    if (landmarks.length <= rightEye) return null;
    final le = landmarks[leftEye];
    final re = landmarks[rightEye];
    if (!_present(le) || !_present(re)) return null;

    final dx = re.x - le.x;
    final dy = re.y - le.y;
    final interocular = math.sqrt(dx * dx + dy * dy);
    if (interocular <= 0) return null;
    final roll = math.atan2(dy, dx);

    final side = _resolveSide(landmarks);
    if (side == null) return null;

    final lobe = _lobeForSide(landmarks, side);
    if (lobe == null) {
      _missFrames++;
      if (_missFrames >= _maxMissBeforeUnlock) {
        _lockedSide = null;
        _missFrames = 0;
      }
      return null;
    }
    _missFrames = 0;
    _lockedSide = side;

    // Empuje ligero hacia afuera + un poco más abajo (centro oreja → lóbulo).
    final outward = (side == 0 ? -1.0 : 1.0) * 0.08 * interocular;
    final down = 0.04 * interocular;

    return AnchorPose(
      position: Vec3(lobe.x + outward, lobe.y + down, lobe.z),
      rollRadians: roll,
      confidence: lobe.visibility ?? 1,
    );
  }

  int? _resolveSide(List<Landmark> landmarks) {
    if (_lockedSide != null) return _lockedSide;

    // Preferir el lado cuyo lóbulo bbox existe; si ambos, el de mayor |x-0.5|
    // (más lateral = oreja más visible).
    final hasL = landmarks.length > leftBBoxLobe &&
        _present(landmarks[leftBBoxLobe]);
    final hasR = landmarks.length > rightBBoxLobe &&
        _present(landmarks[rightBBoxLobe]);
    if (hasL && hasR) {
      final ld = (landmarks[leftBBoxLobe].x - 0.5).abs();
      final rd = (landmarks[rightBBoxLobe].x - 0.5).abs();
      return ld >= rd ? 0 : 1;
    }
    if (hasL) return 0;
    if (hasR) return 1;

    // Fallback: oreja ML Kit.
    if (_present(landmarks[leftEar])) return 0;
    if (_present(landmarks[rightEar])) return 1;
    return null;
  }

  Landmark? _lobeForSide(List<Landmark> landmarks, int side) {
    final bboxIdx = side == 0 ? leftBBoxLobe : rightBBoxLobe;
    if (landmarks.length > bboxIdx && _present(landmarks[bboxIdx])) {
      return landmarks[bboxIdx];
    }
    // Refinar con mejilla si el bbox falta: mejilla + empuje afuera.
    final cheekIdx = side == 0 ? leftCheek : rightCheek;
    final eyeIdx = side == 0 ? leftEye : rightEye;
    if (landmarks.length > cheekIdx &&
        _present(landmarks[cheekIdx]) &&
        _present(landmarks[eyeIdx])) {
      final cheek = landmarks[cheekIdx];
      final eye = landmarks[eyeIdx];
      final inter = math.sqrt(
        math.pow(landmarks[rightEye].x - landmarks[leftEye].x, 2) +
            math.pow(landmarks[rightEye].y - landmarks[leftEye].y, 2),
      );
      final out = (side == 0 ? -1.0 : 1.0) * 0.45 * inter;
      return Landmark(cheek.x + out, eye.y + 0.35 * inter, 0, visibility: 1);
    }
    final earIdx = side == 0 ? leftEar : rightEar;
    if (_present(landmarks[earIdx])) return landmarks[earIdx];
    return null;
  }
}
