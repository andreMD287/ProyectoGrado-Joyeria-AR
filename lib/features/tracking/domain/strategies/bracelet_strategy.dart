import 'dart:math' as math;

import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../../core/math/geometry.dart';
import '../entities/anchor_pose.dart';
import '../entities/landmark.dart';
import '../entities/landmark_frame.dart';
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
  /// longitud palma→muñeca.
  ///
  /// **Conviene que sea corto, y no solo por anatomía.** La dirección hacia la
  /// que se avanza es el eje de la *mano* prolongado, porque ningún detector
  /// disponible ve el antebrazo: MediaPipe Hands termina en la muñeca, ML Kit
  /// Pose encaja un cuerpo entero dentro de la mano —con confianza 0,99 sobre
  /// puntos que caen en los dedos— y la segmentación no distingue el brazo del
  /// escritorio. Todo eso se comprobó en dispositivo.
  ///
  /// Como la muñeca se dobla, esa dirección trae error angular: medido sobre
  /// captura, el eje estimado apuntaba 95° mientras el antebrazo real bajaba
  /// hacia la derecha. El desvío lateral que produce es **proporcional a esta
  /// constante**, porque es el brazo de palanca del error. Valía 0,45; se baja
  /// a 0,20, que además es donde se lleva de verdad una pulsera: justo pasado
  /// el hueso de la muñeca, no a media palma de distancia.
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
    this.forearmOffset = 0.20,
    this.minPalmWidth = 0.04,
  });

  /// Cuanto se conserva de la componente de profundidad del eje. Ver
  /// [_fromWorldLandmarks]: es la senal menos fiable del detector.
  static const double _depthDamping = 0.25;

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
    LandmarkFrame frame, {
    double imageAspect = 1.0,
  }) {
    final landmarks = frame.landmarks;
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

    final metrico = _fromWorldLandmarks(frame.worldLandmarks);

    // El yaw se calcula antes que el tamano: actualiza _maxWidthToAxisRatio,
    // del que el tamano estable depende cuando no hay datos metricos.
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
    // Ancho de la palma "de frente", que es lo que fija el tamano de la pieza.
    //
    // Se obtiene multiplicando el largo del antebrazo **en la imagen** por la
    // proporcion anatomica medida en 3D. Funciona porque ninguno de los dos se
    // escorza al girar la muneca: el largo del antebrazo es el propio eje de
    // giro, y la proporcion es un cociente de distancias reales.
    //
    // Antes esa proporcion se calibraba con el **maximo visto en la sesion**,
    // y ese heuristico se descalibraba en cuanto cambiaba el angulo de camara:
    // la pieza cambiaba de tamano y de sitio al mover el telefono, que es el
    // problema reportado en dispositivo. Sin datos metricos se cae a el.
    // Tamano aparente de la pieza: se mide **sobre la imagen**, que es la unica
    // senal estable.
    //
    // Se intento derivarlo de la reconstruccion metrica, primero por escala
    // absoluta y despues por proporciones, y las dos veces salio peor. Medido
    // en dispositivo (2026-09-19, 302 muestras en dos poses): el ancho metrico
    // de la palma pasa de 7,3 cm con la palma hacia arriba a 4,4 cm con la
    // palma hacia abajo, un 65% de diferencia en una distancia 3D que es una
    // propiedad fisica de la mano y no puede cambiar. MediaPipe reconstruye mal
    // la pose pronada. En esas mismas muestras el ancho en imagen solo varia un
    // 4%.
    //
    // La regla que deja esto, y que ya se habia insinuado con la profundidad:
    // de la reconstruccion metrica sirven **las direcciones**, no las
    // distancias — ni absolutas ni en cociente.
    final stableWidth = palmWidth;

    return AnchorPose(
      position: position,
      rollRadians: math.atan2(axisY / imageAspect, axisX),
      scale: stableWidth,
      yawRadians: yawRadians,
      axis3D: metrico?.axis,
      palmNormal3D: metrico?.normal,
      metricWidth: metrico?.palmWidth,
      confidence: wrist.visibility ?? 1.0,
    );
  }

  /// Eje real del antebrazo y ancho real de la palma, a partir de la
  /// reconstrucción métrica del detector.
  ///
  /// Es el mismo cálculo que arriba se hace sobre la imagen, pero sobre puntos
  /// en metros: aquí el eje **sí** es una dirección en el espacio, no una
  /// proyección, y el ancho está en unidades reales en vez de fracciones del
  /// frame. Eso permite al render orientar y dimensionar la pieza por
  /// geometría en vez de por constantes calibradas a ojo.
  ///
  /// Devuelve `null` si el detector no entrega puntos métricos (hoy, todo lo
  /// que no sea MediaPipe manos en Android).
  ({Vec3 axis, Vec3 normal, double palmWidth, double widthToAxis})?
      _fromWorldLandmarks(
    List<Vec3> world,
  ) {
    if (world.length <= pinkyMcpLandmark) return null;

    final wrist = world[wristLandmark];
    final indexMcp = world[indexMcpLandmark];
    final pinkyMcp = world[pinkyMcpLandmark];

    final palm = Vec3(
      (indexMcp.x + pinkyMcp.x) / 2,
      (indexMcp.y + pinkyMcp.y) / 2,
      (indexMcp.z + pinkyMcp.z) / 2,
    );

    final axis = Vec3(
      wrist.x - palm.x,
      wrist.y - palm.y,
      wrist.z - palm.z,
    );
    final largo = math.sqrt(
      axis.x * axis.x + axis.y * axis.y + axis.z * axis.z,
    );
    if (largo <= 0) return null;

    final ancho = math.sqrt(
      math.pow(indexMcp.x - pinkyMcp.x, 2) +
          math.pow(indexMcp.y - pinkyMcp.y, 2) +
          math.pow(indexMcp.z - pinkyMcp.z, 2),
    );
    if (ancho <= 0) return null;

    // La profundidad se amortigua antes de normalizar. Medido en dispositivo
    // con el brazo inmovil (2026-09-18, 110 muestras): la `z` del eje tiene
    // desviacion 0,228 y recorre un rango de 0,89 —practicamente todo el que
    // puede—, mientras que la `y` se queda en 0,048. El eje entero oscilaba
    // 11 grados de media y hasta 33, y eso se ve como temblor de la pieza.
    //
    // No se arregla filtrando: el ruido no es de alta frecuencia sino deriva
    // lenta entre interpretaciones de profundidad igual de plausibles para el
    // detector, y un pasa-bajos solo le quito un 17%. Amortiguarla conserva la
    // direccion en el plano de la imagen, que si es fiable, y deja una
    // inclinacion fuera de plano modesta pero estable.
    final z = axis.z / largo * _depthDamping;
    final x = axis.x / largo;
    final y = axis.y / largo;
    final renorm = math.sqrt(x * x + y * y + z * z);

    // Normal del plano de la palma: perpendicular a los dos vectores que van
    // de la muñeca a cada nudillo. Es lo que dice si la palma mira arriba o
    // abajo, que el eje del antebrazo por si solo no distingue.
    final v1 = Vec3(
      indexMcp.x - wrist.x,
      indexMcp.y - wrist.y,
      indexMcp.z - wrist.z,
    );
    final v2 = Vec3(
      pinkyMcp.x - wrist.x,
      pinkyMcp.y - wrist.y,
      pinkyMcp.z - wrist.z,
    );
    final nx = v1.y * v2.z - v1.z * v2.y;
    final ny = v1.z * v2.x - v1.x * v2.z;
    final nz = v1.x * v2.y - v1.y * v2.x;
    final nLargo = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (nLargo <= 0) return null;

    return (
      axis: Vec3(x / renorm, y / renorm, z / renorm),
      normal: Vec3(nx / nLargo, ny / nLargo, nz / nLargo),
      palmWidth: ancho,
      // Proporcion anatomica del usuario, medida entre dos distancias reales:
      // no se escorza, porque un cociente de distancias 3D no depende de como
      // se mire la mano. Es lo unico de la reconstruccion metrica que se puede
      // usar con confianza, igual que las direcciones.
      widthToAxis: ancho / largo,
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
