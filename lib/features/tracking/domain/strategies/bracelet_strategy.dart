import 'dart:math' as math;

import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../../core/math/geometry.dart';
import '../entities/anchor_pose.dart';
import '../entities/landmark.dart';
import 'tracking_strategy.dart';

/// Pulseras: ancla en el antebrazo, un poco más allá de la muñeca.
///
/// El landmark 0 de MediaPipe (WRIST) **no** es donde se lleva una pulsera:
/// cae en la base de la palma, así que anclar ahí deja la joya montada sobre
/// la mano. Aquí se usa el eje de la palma para extrapolar hacia el antebrazo:
///
/// ```
///   palma = punto medio(MCP índice, MCP meñique)
///   eje   = muñeca - palma            (apunta de la palma hacia el codo)
///   ancla = muñeca + eje * forearmOffset
/// ```
///
/// Ese mismo eje da la orientación de la pieza, y la distancia entre los dos
/// MCP da el ancho aparente de la mano, que es el proxy de escala con la
/// distancia a la cámara.
///
/// Promediar tres landmarks en vez de leer uno solo también reduce el jitter
/// antes de que actúe el estabilizador.
class BraceletStrategy implements TrackingStrategy {
  /// Índices de MediaPipe Hands.
  static const int wristLandmark = 0;
  static const int thumbTipLandmark = 4;
  static const int indexMcpLandmark = 5;
  static const int pinkyMcpLandmark = 17;

  /// Cuánto se avanza desde la muñeca hacia el codo, como fracción de la
  /// longitud palma→muñeca. Es la constante principal a calibrar en
  /// dispositivo: si la pulsera queda sobre la mano, subirla; si se va al
  /// antebrazo, bajarla.
  final double forearmOffset;

  /// Ancho de palma mínimo (en fracción del ancho del frame) para dar la
  /// detección por buena. Descarta manos diminutas al borde del encuadre, que
  /// es donde MediaPipe alucina.
  final double minPalmWidth;

  /// Mayor relación ancho de palma / longitud de antebrazo vista en la
  /// sesión — usada como referencia de "palma de frente" para [_estimateYaw].
  /// Ya no puede ser `const` por este estado mutable; el resto de la clase no
  /// cambió, y sigue instanciándose una sola vez por sesión de tracking, con
  /// [reset] limpiándola igual que hace `EarringStrategy` con su lado
  /// bloqueado.
  double _maxWidthToAxisRatio = 0;

  /// Signo de yaw confirmado, y cuántos frames seguidos pide el lado
  /// contrario antes de aceptarlo — mismo patrón de histéresis que
  /// `EarringStrategy._lockedSide`/`_switchFrames`. Hace falta porque cerca
  /// de la muñeca "de canto" (palma hacia abajo) el pulgar pasa justo por el
  /// eje del antebrazo, y ahí el ruido de detección hace que el signo crudo
  /// alterne frame a frame — verificado en dispositivo (2026-09-05): temblor
  /// fuerte justo en esa posición.
  double _lastSign = 1.0;
  int _sameSignFrames = 0;
  static const int _minFramesToFlipSign = 3;

  /// Frames seguidos sin mano detectable (cualquiera de los `return null` de
  /// abajo). Al superar [_missFramesBeforeRecalibrate] se asume que la mano
  /// salió del encuadre — no solo un parpadeo puntual del detector — y el
  /// siguiente frame válido recalibra [_maxWidthToAxisRatio] desde cero, en
  /// vez de seguir arrastrando lo que se vio antes de que la mano
  /// desapareciera.
  int _missedFrames = 0;
  static const int _missFramesBeforeRecalibrate = 3;

  BraceletStrategy({
    this.forearmOffset = 0.45,
    this.minPalmWidth = 0.04,
  });

  @override
  JewelryCategory get category => JewelryCategory.bracelet;

  @override
  DetectorKind get detectorKind => DetectorKind.hand;

  @override
  void reset() {
    _maxWidthToAxisRatio = 0;
    _lastSign = 1.0;
    _sameSignFrames = 0;
    _missedFrames = 0;
  }

  @override
  AnchorPose? computeAnchor(
    List<Landmark> landmarks, {
    double imageAspect = 1.0,
  }) {
    if (landmarks.length <= pinkyMcpLandmark) {
      _missedFrames++;
      return null;
    }

    final wrist = landmarks[wristLandmark];
    final indexMcp = landmarks[indexMcpLandmark];
    final pinkyMcp = landmarks[pinkyMcpLandmark];

    // Centro de la palma: punto medio entre los nudillos de índice y meñique.
    final palmX = (indexMcp.x + pinkyMcp.x) / 2;
    final palmY = (indexMcp.y + pinkyMcp.y) / 2;
    final palmZ = (indexMcp.z + pinkyMcp.z) / 2;

    // Ancho de la palma medido en pantalla, en unidades del ancho del frame.
    final palmWidth = _screenDistance(
      indexMcp.x - pinkyMcp.x,
      indexMcp.y - pinkyMcp.y,
      imageAspect,
    );
    if (palmWidth < minPalmWidth) {
      _missedFrames++;
      return null;
    }

    // Eje del antebrazo, de la palma hacia el codo, en espacio normalizado.
    final axisX = wrist.x - palmX;
    final axisY = wrist.y - palmY;
    final axisZ = wrist.z - palmZ;

    final axisLength = _screenDistance(axisX, axisY, imageAspect);
    if (axisLength <= 0) {
      _missedFrames++;
      return null;
    }

    // La mano estuvo fuera de encuadre varios frames seguidos: lo calibrado
    // antes de que desapareciera ya no aplica (pudo alejarse, acercarse o
    // girar). El siguiente frame válido recalibra desde cero, igual que si
    // fuera el primero de la sesión.
    if (_missedFrames >= _missFramesBeforeRecalibrate) {
      _maxWidthToAxisRatio = 0;
    }
    _missedFrames = 0;

    // El desplazamiento se hace en espacio normalizado: escalar un vector
    // normalizado equivale a escalar su versión en píxeles, así que aquí no
    // hace falta corregir por aspecto (a diferencia de longitudes y ángulos).
    final position = Vec3(
      wrist.x + axisX * forearmOffset,
      wrist.y + axisY * forearmOffset,
      wrist.z + axisZ * forearmOffset,
    );

    // El yaw se calcula antes que el tamano: actualiza _maxWidthToAxisRatio,
    // que el tamano estable de abajo tambien usa.
    final yawRadians = _estimateYaw(
      landmarks: landmarks,
      palmX: palmX,
      palmY: palmY,
      axisX: axisX,
      axisY: axisY,
      palmWidth: palmWidth,
      axisLength: axisLength,
    );

    // Tamano estable: `palmWidth` se encoge con el mismo giro que ya
    // representa `yawRadians` (es la señal que usamos para estimarlo). Si el
    // tamano del overlay tambien usara `palmWidth` tal cual, la pulsera se
    // encogeria dos veces por el mismo giro: una por la rotacion 3D real del
    // modelo, y otra porque el widget completo se dibuja mas chico. Se
    // reconstruye el ancho "de frente" con el largo de antebrazo actual (que
    // no cambia con este giro) y la relacion mas ancha vista en la sesion —
    // eso sigue la distancia a la camara sin heredar el encogimiento del yaw.
    final stableWidth = _maxWidthToAxisRatio > 0
        ? axisLength * _maxWidthToAxisRatio
        : palmWidth;

    return AnchorPose(
      position: position,
      rollRadians: math.atan2(axisY / imageAspect, axisX),
      scale: stableWidth,
      yawRadians: yawRadians,
      confidence: wrist.visibility ?? 1.0,
    );
  }

  /// Longitud de un desplazamiento normalizado medida en pantalla, expresada
  /// en unidades del ancho del frame. Sin la corrección por [imageAspect] una
  /// mano horizontal y una vertical medirían distinto con el mismo tamaño real.
  static double _screenDistance(double dx, double dy, double imageAspect) {
    final scaledY = dy / imageAspect;
    return math.sqrt(dx * dx + scaledY * scaledY);
  }

  /// Aproxima la pronación/supinación de la muñeca (el giro que muestra el
  /// dorso o la palma) **sin profundidad real** — ni MediaPipe en iOS (Apple
  /// Vision, `VNDetectHumanHandPoseRequest`) entrega `z`, a diferencia de
  /// Android. Es una aproximación geométrica 2D, pendiente de validar en
  /// dispositivo, no una medición.
  ///
  /// **Magnitud**, por foreshortening: al girar la muñeca sobre el eje del
  /// antebrazo, el ancho de palma proyectado (índice↔meñique) se encoge
  /// respecto al largo del antebrazo, que no cambia con este giro porque es
  /// aproximadamente el propio eje de rotación. Se compara la relación
  /// actual contra el máximo visto en la sesión (asumido como "de frente");
  /// si el usuario empieza ya de perfil, esa referencia queda mal calibrada
  /// hasta que muestre la palma más de frente.
  ///
  /// **Signo**, por el lado del pulgar: la posición del pulgar respecto al
  /// eje del antebrazo (producto cruz 2D) indica hacia qué lado gira. No
  /// distingue pronación de supinación más allá de ese signo relativo — es
  /// una heurística, no una derivación física.
  ///
  /// Cerca de la muñeca "de canto" (palma hacia abajo, el punto medio del
  /// giro) el pulgar pasa muy cerca del propio eje del antebrazo, así que el
  /// signo crudo del producto cruz es el más sensible al ruido de detección
  /// — es justo donde se vio temblor en dispositivo. Por eso el signo no se
  /// seguna cruda: hay una zona muerta ([_signDeadZone], normalizada por
  /// `axisLength²` para no depender de qué tan cerca está la mano) y un lado
  /// solo se acepta tras sostenerlo [_minFramesToFlipSign] frames seguidos —
  /// mismo patrón que el lock de lado de `EarringStrategy`.
  static const double _signDeadZone = 0.05;

  /// Cota de sanidad para `ratio`: una sola detección degenerada (típico
  /// justo en el borde del encuadre) puede disparar `palmWidth/axisLength`
  /// muy por encima de lo anatómicamente plausible. Sin tope, ese único
  /// frame infla [_maxWidthToAxisRatio] y agranda la pulsera para el resto
  /// de la sesión — visto en dispositivo (2026-09-05) al sacar la mano de
  /// cámara. Valor generoso, no calibrado: para una mano real de frente
  /// ratio ronda 1.0 en las pruebas actuales.
  static const double _maxPlausibleRatio = 2.0;

  double _estimateYaw({
    required List<Landmark> landmarks,
    required double palmX,
    required double palmY,
    required double axisX,
    required double axisY,
    required double palmWidth,
    required double axisLength,
  }) {
    final ratio = (palmWidth / axisLength).clamp(0.0, _maxPlausibleRatio);
    _maxWidthToAxisRatio = math.max(_maxWidthToAxisRatio, ratio);

    final cosYaw = _maxWidthToAxisRatio > 0
        ? (ratio / _maxWidthToAxisRatio).clamp(0.0, 1.0)
        : 1.0;
    final magnitude = math.acos(cosYaw);

    final thumbTip = landmarks[thumbTipLandmark];
    final thumbVecX = thumbTip.x - palmX;
    final thumbVecY = thumbTip.y - palmY;
    // Signo invertido en la primera prueba en dispositivo (2026-09-05,
    // iPhone sin LiDAR): giraba al lado contrario del real. Volteado aquí.
    final cross = axisX * thumbVecY - axisY * thumbVecX;
    final normalizedCross = cross / (axisLength * axisLength);

    if (normalizedCross.abs() >= _signDeadZone) {
      final candidate = normalizedCross >= 0 ? -1.0 : 1.0;
      if (candidate == _lastSign) {
        _sameSignFrames = 0;
      } else {
        _sameSignFrames++;
        if (_sameSignFrames >= _minFramesToFlipSign) {
          _lastSign = candidate;
          _sameSignFrames = 0;
        }
      }
    } else {
      _sameSignFrames = 0;
    }

    return magnitude * _lastSign;
  }
}
