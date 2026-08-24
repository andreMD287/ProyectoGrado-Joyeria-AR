/// Vector 3D mínimo y puro (sin dependencias), usado por el dominio y los
/// filtros de estabilización. Compatible con las coordenadas (x, y, z) que
/// entregan los detectores de landmarks: x,y normalizados [0,1] y z como
/// profundidad relativa.
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  static const zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)}, ${z.toStringAsFixed(4)})';
}

/// Punto normalizado (x, y ∈ [0,1]) en el espacio del *preview* de cámara
/// (mismo sistema que usa el overlay de la prueba virtual).
class NormalizedPoint {
  final double x;
  final double y;
  const NormalizedPoint(this.x, this.y);
}

/// Traduce un landmark en píxeles de ML Kit al espacio normalizado del
/// `CameraPreview`.
///
/// **Android:** corrige el intercambio de ejes con rotación 90°/270° (bug que
/// producía coordenadas fuera de [0,1]) y el espejo de cámara frontal en 0°.
/// Sigue el `coordinates_translator` del ejemplo oficial de `google_ml_kit_flutter`.
///
/// **iOS:** conserva el comportamiento previo (`pixelX / width`,
/// `pixelY / height`), validado en dispositivo antes de este fix.
NormalizedPoint normalizeMlKitLandmarkToPreview({
  required double pixelX,
  required double pixelY,
  required int bufferWidth,
  required int bufferHeight,
  required int rotationDegrees,
  required bool isFrontCamera,
  required bool isIOS,
}) {
  final w = bufferWidth.toDouble();
  final h = bufferHeight.toDouble();

  // iOS: sin corrección de rotación/espejo (ya validado en iPhone).
  if (isIOS) {
    return NormalizedPoint(pixelX / w, pixelY / h);
  }

  final rotation = ((rotationDegrees % 360) + 360) % 360;

  switch (rotation) {
    case 90:
      return NormalizedPoint(pixelX / h, pixelY / w);
    case 270:
      return NormalizedPoint(
        1.0 - pixelX / h,
        pixelY / w,
      );
    case 180:
    case 0:
    default:
      final x = isFrontCamera ? 1.0 - pixelX / w : pixelX / w;
      return NormalizedPoint(x, pixelY / h);
  }
}
