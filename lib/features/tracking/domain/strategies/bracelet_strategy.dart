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

  const BraceletStrategy({
    this.forearmOffset = 0.45,
    this.minPalmWidth = 0.04,
  });

  @override
  JewelryCategory get category => JewelryCategory.bracelet;

  @override
  DetectorKind get detectorKind => DetectorKind.hand;

  @override
  void reset() {}

  @override
  AnchorPose? computeAnchor(
    List<Landmark> landmarks, {
    double imageAspect = 1.0,
  }) {
    if (landmarks.length <= pinkyMcpLandmark) return null;

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
    if (palmWidth < minPalmWidth) return null;

    // Eje del antebrazo, de la palma hacia el codo, en espacio normalizado.
    final axisX = wrist.x - palmX;
    final axisY = wrist.y - palmY;
    final axisZ = wrist.z - palmZ;

    final axisLength = _screenDistance(axisX, axisY, imageAspect);
    if (axisLength <= 0) return null;

    // El desplazamiento se hace en espacio normalizado: escalar un vector
    // normalizado equivale a escalar su versión en píxeles, así que aquí no
    // hace falta corregir por aspecto (a diferencia de longitudes y ángulos).
    final position = Vec3(
      wrist.x + axisX * forearmOffset,
      wrist.y + axisY * forearmOffset,
      wrist.z + axisZ * forearmOffset,
    );

    return AnchorPose(
      position: position,
      rollRadians: math.atan2(axisY / imageAspect, axisX),
      scale: palmWidth,
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
}
