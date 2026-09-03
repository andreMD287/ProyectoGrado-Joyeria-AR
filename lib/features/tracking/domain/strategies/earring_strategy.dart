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
    // Eje de los ojos: su inclinación no depende del sentido en que se
    // recorra, y con la cámara frontal el vector viene invertido.
    final roll = normalizeAxisAngle(math.atan2(dy, dx));

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

    // El sentido del ajuste se decide por dónde cae el punto respecto al
    // centro de la cara **en la imagen**, no por el índice de lado de ML Kit.
    //
    // La cámara frontal entrega la imagen espejada, así que el lóbulo que ML
    // Kit llama derecho aparece a la izquierda. Usando el índice, el ajuste
    // salía invertido y alejaba el ancla de la cara en vez de acercarla
    // (visto en dispositivo: el ancla se iba al fondo, fuera de la cabeza).
    final faceCenterX = (le.x + re.x) / 2;
    final outward = _awayFromCenter(lobe.point.x, faceCenterX) *
        _outwardFactor(lobe.source) *
        interocular;
    final down = 0.04 * interocular;

    return AnchorPose(
      position: Vec3(
        lobe.point.x + outward,
        lobe.point.y + down,
        lobe.point.z,
      ),
      rollRadians: roll,
      confidence: lobe.point.visibility ?? 1,
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

  /// Cuánto se separa el punto hacia afuera de la cara, en fracciones de la
  /// distancia interocular. **Negativo = hacia adentro.** Constantes a
  /// calibrar en dispositivo.
  ///
  /// Cada fuente cae en un sitio distinto y necesita el ajuste en un sentido:
  ///
  /// - **Bounding box:** ML Kit lo dibuja con margen alrededor de la cara
  ///   (incluye pelo y algo de aire), así que su borde queda *por fuera* de
  ///   la oreja y hay que meterlo. Medido de frente en un Galaxy A15: el
  ///   borde caía a un 20% de la distancia interocular por fuera del lóbulo.
  /// - **Oreja y mejilla:** el landmark de oreja de ML Kit cae en el centro
  ///   de la oreja, así que ahí sí hay que separarse hacia el lóbulo.
  static double _outwardFactor(_LobeSource source) => switch (source) {
        _LobeSource.boundingBox => -0.20,
        _LobeSource.cheek || _LobeSource.ear => 0.08,
      };

  /// +1 si [x] queda del lado exterior respecto a [centerX], -1 si del
  /// interior. Sustituye al índice de lado de ML Kit, que no sobrevive al
  /// espejo de la cámara frontal.
  static double _awayFromCenter(double x, double centerX) =>
      x >= centerX ? 1.0 : -1.0;

  _Lobe? _lobeForSide(List<Landmark> landmarks, int side) {
    final bboxIdx = side == 0 ? leftBBoxLobe : rightBBoxLobe;
    if (landmarks.length > bboxIdx && _present(landmarks[bboxIdx])) {
      return _Lobe(landmarks[bboxIdx], _LobeSource.boundingBox);
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
      final centerX = (landmarks[leftEye].x + landmarks[rightEye].x) / 2;
      final out = _awayFromCenter(cheek.x, centerX) * 0.45 * inter;
      return _Lobe(
        Landmark(cheek.x + out, eye.y + 0.35 * inter, 0, visibility: 1),
        _LobeSource.cheek,
      );
    }
    final earIdx = side == 0 ? leftEar : rightEar;
    if (_present(landmarks[earIdx])) {
      return _Lobe(landmarks[earIdx], _LobeSource.ear);
    }
    return null;
  }
}

/// De dónde se obtuvo el punto de lóbulo. El ajuste fino depende de la
/// fuente: cada una cae en un sitio distinto de la oreja.
enum _LobeSource { boundingBox, cheek, ear }

class _Lobe {
  final Landmark point;
  final _LobeSource source;
  const _Lobe(this.point, this.source);
}
