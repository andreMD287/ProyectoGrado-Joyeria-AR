/// Lo que se vio del antebrazo **en la imagen**, cuando se pudo ver.
///
/// Ningún detector disponible entrega el antebrazo (ADR-17): MediaPipe Hands
/// acaba en la muñeca. Hasta ahora su eje se extrapolaba desde la mano, y con
/// la muñeca desviada eso inclina la pieza y la corre a un lado. Esta
/// observación sale de buscar los bordes del brazo en el propio frame, justo
/// debajo de la muñeca (ver `forearm_probe.dart`).
///
/// Todo va en el espacio **isótropo** del frame vertical: `x` normalizado al
/// ancho, `y` dividido por el aspecto, de modo que una unidad mide lo mismo en
/// los dos ejes (fracciones del ancho del frame).
class ForearmObservation {
  /// Punto de la línea media del brazo a la altura de la muñeca.
  final double originX, originY;

  /// Dirección unitaria de la línea media, de la muñeca hacia el codo.
  final double dirX, dirY;

  /// Ancho del brazo perpendicular a su eje, en fracciones del ancho del frame.
  final double width;

  /// Líneas de exploración que encontraron los dos bordes.
  final int validScans;

  const ForearmObservation({
    required this.originX,
    required this.originY,
    required this.dirX,
    required this.dirY,
    required this.width,
    required this.validScans,
  });

  /// Punto de la línea media a [distance] de la muñeca, en el mismo espacio.
  ({double x, double y}) pointAt(double distance) =>
      (x: originX + dirX * distance, y: originY + dirY * distance);
}
