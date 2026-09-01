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
/// **Android:** corrige el intercambio de ejes con rotación 90°/270° (mismo
/// criterio con el que el collar quedó bien). Espejo frontal solo en 0°/180°.
///
/// **iOS:** división simple `pixelX/width`, `pixelY/height` (sin cambios).
///
/// Nota: no se aplica espejo frontal en 90° — eso desalineó el overlay del
/// preview y hacía “flotar” el anclaje por toda la pantalla.
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

  if (isIOS) {
    return NormalizedPoint(pixelX / w, pixelY / h);
  }

  final rotation = ((rotationDegrees % 360) + 360) % 360;

  return switch (rotation) {
    90 => NormalizedPoint(pixelX / h, pixelY / w),
    270 => NormalizedPoint(1.0 - pixelX / h, pixelY / w),
    _ => NormalizedPoint(
        isFrontCamera ? 1.0 - pixelX / w : pixelX / w,
        pixelY / h,
      ),
  };
}

/// Cómo queda un frame de cámara dentro del área donde se dibuja, cuando se
/// muestra con `BoxFit.cover`: la escala aplicada y el desplazamiento del
/// origen (negativo en el eje que se recorta).
///
/// Hace falta porque el overlay AR y la vista previa tienen que compartir el
/// mismo sistema de coordenadas. `BoxFit.cover` **escala y recorta**, así que
/// multiplicar un landmark normalizado por el tamaño del área da un punto
/// desplazado: coincide en el centro y se desvía hacia los bordes del eje
/// recortado.
class PreviewFit {
  /// Píxeles de pantalla por píxel de imagen.
  final double scale;

  /// Origen de la imagen renderizada, relativo al área de dibujo.
  final double dx, dy;

  final double imageWidth, imageHeight;

  const PreviewFit({
    required this.scale,
    required this.dx,
    required this.dy,
    required this.imageWidth,
    required this.imageHeight,
  });

  /// Coordenada horizontal en el área, para un x normalizado del frame.
  double xOf(double normalizedX) => dx + normalizedX * imageWidth * scale;

  /// Coordenada vertical en el área, para un y normalizado del frame.
  double yOf(double normalizedY) => dy + normalizedY * imageHeight * scale;

  /// Longitud en píxeles de pantalla de una medida expresada en fracciones del
  /// ancho del frame (la unidad que usa `AnchorPose.scale`).
  double lengthOf(double widthFraction) => widthFraction * imageWidth * scale;
}

/// Calcula la [PreviewFit] de un frame dibujado con `BoxFit.cover`.
///
/// [imageWidth] y [imageHeight] son los del frame **ya rotado a vertical**,
/// que es como se dibuja el preview y como vienen normalizados los landmarks.
PreviewFit coverFit({
  required double imageWidth,
  required double imageHeight,
  required double areaWidth,
  required double areaHeight,
}) {
  if (imageWidth <= 0 || imageHeight <= 0) {
    return PreviewFit(
      scale: 1,
      dx: 0,
      dy: 0,
      imageWidth: areaWidth,
      imageHeight: areaHeight,
    );
  }
  final scale = (areaWidth / imageWidth) > (areaHeight / imageHeight)
      ? areaWidth / imageWidth
      : areaHeight / imageHeight;
  return PreviewFit(
    scale: scale,
    dx: (areaWidth - imageWidth * scale) / 2,
    dy: (areaHeight - imageHeight * scale) / 2,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
}
