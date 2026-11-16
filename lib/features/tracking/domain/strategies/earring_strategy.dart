import 'dart:math' as math;

import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../../core/math/geometry.dart';
import '../../../../core/math/head_geometry.dart';
import '../entities/anchor_pose.dart';
import '../entities/head_observation.dart';
import '../entities/landmark.dart';
import '../entities/landmark_frame.dart';
import 'tracking_strategy.dart';

/// Aretes: ancla en el lóbulo.
///
/// Hay dos caminos según lo que entregue el detector:
///
/// - **Cabeza medida con la malla facial** ([LandmarkFrame.head], Android):
///   ver [_fromHead]. Da la pose de toda la cabeza, y el render cuelga de ella
///   los dos aretes y su oclusión.
/// - **ML Kit Face** (iOS): lo que sigue, sin cambios.
///
/// De frente, los landmarks de oreja de ML Kit son inestables (aparecen /
/// desaparecen) y alternar izq/der hace que el modelo salte por toda la cara.
/// Por eso el anclaje primario son los puntos derivados del **bounding box**
/// del rostro (índices 6 y 7), con un lado **bloqueado** durante la sesión:
/// solo cambia si el lado contrario sostiene una señal lateral clara varios
/// frames seguidos (giro real de cabeza, no ruido puntual del bbox).
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

  /// Frames consecutivos con señal lateral clara hacia el lado contrario al
  /// bloqueado. Solo se cambia de lado tras sostenerlo [_minFramesToSwitch]
  /// frames seguidos — un giro real de cabeza, no ruido puntual del bbox.
  int _switchFrames = 0;
  static const int _minFramesToSwitch = 6;

  /// Lado elegido por el usuario en la pantalla de preparación (0 = izquierdo,
  /// 1 = derecho, `null` = automático). A diferencia de [_lockedSide], no lo
  /// toca [reset]: es una preferencia de sesión, no un resultado del tracking.
  int? _forcedSide;

  EarringStrategy();

  @override
  JewelryCategory get category => JewelryCategory.earring;

  /// `head`: en Android la malla facial de MediaPipe y en iOS ML Kit Face,
  /// igual que antes (ver `createLandmarkDetector`).
  @override
  DetectorKind get detectorKind => DetectorKind.head;

  /// Fuerza el lado a anclar (0 = izquierdo, 1 = derecho), o vuelve al modo
  /// automático con `null`. Mientras hay un lado forzado, [_resolveSide]
  /// ignora el auto-lock y el punto de anclaje se calcula solo con ese lado.
  void setPreferredSide(int? side) {
    _forcedSide = side;
  }

  @override
  void reset() {
    _lockedSide = null;
    _missFrames = 0;
    _switchFrames = 0;
  }

  bool _present(Landmark lm) => (lm.visibility ?? 0) > 0;

  @override
  AnchorPose? computeAnchor(
    LandmarkFrame frame, {
    double imageAspect = 1.0,
  }) {
    final head = frame.head;
    if (head != null) return _fromHead(head, imageAspect);

    // ML Kit Face no entrega reconstruccion metrica, asi que esta estrategia
    // solo usa los landmarks de imagen.
    final landmarks = frame.landmarks;
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
    final headAngles = frame.headEulerAnglesDeg;

    return AnchorPose(
      position: Vec3(
        lobe.point.x + outward,
        lobe.point.y + down,
        lobe.point.z,
      ),
      rollRadians: roll,
      // Distancia interocular como medida de referencia: a diferencia de la
      // muñeca o los hombros, la cara no tiene reconstrucción métrica, pero
      // esta sí encoge y crece en pantalla con la distancia real, así que
      // sirve para escalar el tamaño aparente del arete (antes fijo).
      scale: interocular,
      yawRadians: headAngles == null ? null : _toYawRadians(headAngles.y),
      pitchRadians: headAngles == null ? null : _toPitchRadians(headAngles.x),
      confidence: lobe.point.visibility ?? 1,
    );
  }

  /// Pose de la cabeza a partir de la malla facial.
  ///
  /// - **Posición ([AnchorPose.position]):** el punto medio entre las mejillas
  ///   234 y 454, que es el origen de la cabeza invisible (`HeadModel`).
  /// - **Escala ([AnchorPose.scale]):** la distancia entre ellas **en 3D**, en
  ///   fracciones del ancho del frame: no se encoge al girar la cabeza.
  /// - **Orientación ([AnchorPose.headAxes]):** el eje x va de mejilla a
  ///   mejilla por los puntos medidos, y la vertical sale de la matriz de
  ///   transformación facial (o, si no llegó o no cuadra, del mentón a la
  ///   frente). Así los lóbulos, que cuelgan de las mejillas, quedan atados a
  ///   lo que se ve en la imagen.
  ///
  /// Es la regla de ADR-14: las direcciones del modelo 3D, los tamaños de la
  /// imagen. De la matriz solo se toma la rotación: su traslación supone el
  /// campo de visión de MediaPipe, no el de la cámara.
  ///
  /// Se dibujan los dos aretes y la oclusión decide cuál se ve, así que no hay
  /// lado que bloquear. El lado elegido en la pantalla de preparación deja
  /// solo ese.
  AnchorPose? _fromHead(HeadObservation head, double imageAspect) {
    final neg = head.negativeSide;
    final pos = head.positiveSide;
    if (neg == null || pos == null || imageAspect <= 0) return null;

    Vec3 escena(Landmark p) => imageToScene(Vec3(p.x, p.y, p.z), imageAspect);
    final deMejillaAMejilla = escena(pos) - escena(neg);
    final ancho = deMejillaAMejilla.length;
    if (ancho <= 0) return null;

    final axes = _headAxes(head, deMejillaAMejilla, escena);
    if (axes == null) return null;

    // Para el overlay de diagnóstico: inclinación del eje x en pantalla (la y
    // de la pantalla crece hacia abajo) y giro de la cara alrededor de la
    // vertical, positivo hacia la derecha de la pantalla.
    final roll = math.atan2(-axes.x.y, axes.x.x);
    final cara = axes.z;
    final yaw = math.atan2(cara.x, cara.z);

    // Cada lóbulo, en el espacio de la cabeza, sobre el contorno medido de su
    // lado (ver `HeadModel.lobeAlongContour`), corregido por el cabeceo
    // (`HeadModel.lobePitchGain`): positivo mirando hacia abajo.
    final origen = (escena(neg) + escena(pos)) * 0.5;
    final pitch = math.atan2(-cara.y, math.sqrt(cara.x * cara.x + cara.z * cara.z));
    final porCabeceo = Vec3(0, HeadModel.lobePitchGain * pitch, 0);
    // Con la cabeza girada el contorno se ubica peor y se pasa poco a poco al
    // lóbulo atado a las mejillas (ver `HeadModel.rigidLobeBlendStartDeg`).
    final hacia = _smoothstep(
      HeadModel.rigidLobeBlendStartDeg * math.pi / 180,
      HeadModel.rigidLobeBlendEndDeg * math.pi / 180,
      yaw.abs(),
    );
    Vec3 lobulo(int side) {
      final rigido = HeadModel.lobeFor(side) + porCabeceo;
      final contorno = head.contourFor(side);
      if (contorno == null || hacia >= 1) return rigido;
      final (arriba, abajo) = contorno;
      final a = escena(arriba), b = escena(abajo);
      final punto = a + (b - a) * HeadModel.lobeAlongContour;
      final d = (punto - origen) * (1 / ancho);
      final sobreContorno = Vec3(d.dot(axes.x), d.dot(axes.y), d.dot(axes.z)) +
          HeadModel.lobeOffsetFor(side) +
          porCabeceo;
      return sobreContorno + (rigido - sobreContorno) * hacia;
    }

    final forced = _forcedSide;
    return AnchorPose(
      position: Vec3(
        (neg.x + pos.x) / 2,
        (neg.y + pos.y) / 2,
        (neg.z + pos.z) / 2,
      ),
      rollRadians: roll,
      scale: ancho,
      yawRadians: yaw,
      headAxes: axes,
      earringSide: forced == null
          ? null
          // 0 = izquierda, 1 = derecha, de la persona.
          : (forced == 0 ? head.leftEarSide : -head.leftEarSide),
      lobeNegative: lobulo(-1),
      lobePositive: lobulo(1),
      confidence: 1,
    );
  }

  /// Ejes de la cabeza: x de mejilla a mejilla con los puntos medidos, y la
  /// vertical de la matriz si cuadra con ellos o, si no, del mentón a la
  /// frente.
  ///
  /// **Por qué la x no sale de la matriz.** Con la cabeza girada, la matriz y
  /// los puntos no coinciden en el giro: medido en dispositivo (2026-11-08),
  /// la matriz daba 32° y el botón, colgado del lóbulo según ella, quedaba
  /// ~9 mm hacia la nuca, fuera de donde la malla ponía la mejilla de ese
  /// lado. Con la x por los puntos, el ±0,5 del modelo cae exactamente en las
  /// mejillas medidas y el lóbulo se cuelga de ellas.
  ///
  /// La comprobación protege de una matriz con otra convención de ejes: su x
  /// tiene que ir, como mucho a unos 45°, en el mismo sentido que la línea de
  /// mejilla a mejilla.
  static HeadAxes? _headAxes(
    HeadObservation head,
    Vec3 deMejillaAMejilla,
    Vec3 Function(Landmark) escena,
  ) {
    final deMatriz = head.axes;
    final x = deMejillaAMejilla.normalized();
    if (deMatriz != null && deMatriz.x.dot(x) > _minMatrixAgreement) {
      return HeadAxes.orthonormal(x, deMatriz.y);
    }
    final frente = head.points[HeadObservation.forehead];
    final menton = head.points[HeadObservation.chin];
    if (frente == null || menton == null) return null;
    return HeadAxes.orthonormal(x, escena(frente) - escena(menton));
  }

  /// Coseno mínimo entre el eje x de la matriz y la línea de mejilla a
  /// mejilla (unos 45°).
  static const double _minMatrixAgreement = 0.7;

  /// 0 hasta [a], 1 desde [b] y una curva suave entre los dos: el lóbulo no
  /// salta al pasar de un cálculo al otro.
  static double _smoothstep(double a, double b, double v) {
    final t = ((v - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// `headEulerAngleY` (giro lateral de cabeza) a radianes, para que el arete
  /// gire con la cabeza en vez de quedarse plano.
  ///
  /// **Signo sin verificar en dispositivo.** ML Kit mide sobre la imagen
  /// frontal tal cual se la pasa el plugin (espejada), el mismo motivo por el
  /// que el lado bloqueado (ver `_awayFromCenter`) no puede fiarse de las
  /// etiquetas izquierda/derecha de ML Kit. Si el arete gira al revés del
  /// giro real de la cabeza, invertir este signo.
  static double _toYawRadians(double headEulerAngleYDeg) =>
      -headEulerAngleYDeg * _headRotationDamping * math.pi / 180;

  /// `headEulerAngleX` (cabeceo) a radianes. Mismo aviso de signo que
  /// [_toYawRadians]: pendiente de confirmar en dispositivo.
  static double _toPitchRadians(double headEulerAngleXDeg) =>
      headEulerAngleXDeg * _headRotationDamping * math.pi / 180;

  /// Cuánto del ángulo de cabeza real se le pasa al arete, en vez del 1:1.
  ///
  /// Un arete real no gira solidario con la cabeza como una pieza rígida
  /// atornillada — cuelga del lóbulo y se balancea mucho menos de lo que gira
  /// la cabeza. Aplicado en 1:1 (visto en dispositivo) se veía exagerado.
  /// Constante a seguir ajustando en dispositivo.
  static const double _headRotationDamping = 0.35;

  /// Diferencia lateral mínima antes de confiar en el bbox como señal de
  /// giro real. El bbox es simétrico por definición alrededor de su propio
  /// centro, así que de frente casi siempre empata (o casi) — por debajo de
  /// este umbral no hay señal real, solo ruido de detección.
  static const double _lateralThreshold = 0.01;

  int? _resolveSide(List<Landmark> landmarks) {
    if (_forcedSide != null) return _forcedSide;

    final hasL = landmarks.length > leftBBoxLobe &&
        _present(landmarks[leftBBoxLobe]);
    final hasR = landmarks.length > rightBBoxLobe &&
        _present(landmarks[rightBBoxLobe]);

    if (_lockedSide != null) {
      _maybeSwitchLockedSide(landmarks, hasL, hasR);
      return _lockedSide;
    }

    // Preferir el lado cuyo lóbulo bbox existe; si ambos, usar hacia dónde se
    // desplazó la caja completa (ver [_lateralCandidate]) para inferir cuál
    // oreja se expuso.
    if (hasL && hasR) {
      return _lateralCandidate(landmarks) ??
          _earPresenceFallback(landmarks) ??
          0; // sin señal real: izquierdo por defecto.
    }
    if (hasL) return 0;
    if (hasR) return 1;

    // Fallback: oreja ML Kit.
    if (_present(landmarks[leftEar])) return 0;
    if (_present(landmarks[rightEar])) return 1;
    return null;
  }

  /// Lado sugerido por la posición lateral del bbox, o `null` si de frente
  /// (bbox empatado, sin señal real de giro).
  ///
  /// Verificado en dispositivo: al girar la cabeza, la caja **completa** se
  /// desplaza hacia el lado al que se gira (no se estira hacia el lado que
  /// se expone). Si giras para mostrar tu oreja derecha, toda la caja se
  /// corre hacia la izquierda de la pantalla, así que es `leftBBoxLobe` el
  /// que se aleja más del centro — no `rightBBoxLobe`. Por eso el lado
  /// elegido es el **contrario** al lóbulo más lateral.
  int? _lateralCandidate(List<Landmark> landmarks) {
    final ld = (landmarks[leftBBoxLobe].x - 0.5).abs();
    final rd = (landmarks[rightBBoxLobe].x - 0.5).abs();
    if ((ld - rd).abs() <= _lateralThreshold) return null;
    return ld >= rd ? 1 : 0;
  }

  /// Desempate de frente: a diferencia del bbox (que siempre existe), la
  /// oreja cruda de ML Kit solo se reporta cuando de verdad se ve, así que sí
  /// varía lado a lado.
  int? _earPresenceFallback(List<Landmark> landmarks) {
    final earL = _present(landmarks[leftEar]);
    final earR = _present(landmarks[rightEar]);
    if (earL && !earR) return 0;
    if (earR && !earL) return 1;
    return null;
  }

  /// Con un lado ya bloqueado, solo cambia al contrario tras sostener una
  /// señal lateral clara por [_minFramesToSwitch] frames seguidos — un giro
  /// real de cabeza, no ruido puntual de un frame del bbox.
  void _maybeSwitchLockedSide(
    List<Landmark> landmarks,
    bool hasL,
    bool hasR,
  ) {
    if (!hasL || !hasR) {
      _switchFrames = 0;
      return;
    }
    final candidate = _lateralCandidate(landmarks);
    if (candidate != null && candidate != _lockedSide) {
      _switchFrames++;
      if (_switchFrames >= _minFramesToSwitch) {
        _lockedSide = candidate;
        _switchFrames = 0;
      }
    } else {
      _switchFrames = 0;
    }
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
