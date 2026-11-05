import 'landmark.dart';

/// Lo que se midió de la cara y del cuello para colgar un collar.
///
/// Todo va normalizado al frame **ya rotado y espejado como la vista previa**
/// (x al ancho, y al alto), igual que los landmarks del resto de detectores.
///
/// Viene de dos fuentes con ritmos distintos (ver `NeckTracker` en Android):
/// la cara en cada frame y el cuello cuando termina la segmentación, unas
/// cuatro veces por segundo. Por eso [neck] trae la cara **del frame en que se
/// midió** ([NeckShape.refChin], [NeckShape.refFaceWidth]): la forma del
/// cuello se traslada a la cara actual en vez de usarse donde estaba.
class NeckObservation {
  /// Punta del mentón. `z` es la profundidad relativa de la malla facial, en
  /// la escala de `x`.
  final Landmark chin;

  /// Mejillas a la izquierda y a la derecha **de la pantalla**.
  final Landmark cheekLeft;
  final Landmark cheekRight;

  final Landmark nose;

  /// Ancho de la cara de mejilla a mejilla, en 3D y en fracciones del ancho
  /// del frame: no se encoge al girar la cabeza.
  final double faceWidth;

  /// Forma del cuello, o `null` si la segmentación aún no la midió o la
  /// última medida es vieja.
  final NeckShape? neck;

  const NeckObservation({
    required this.chin,
    required this.cheekLeft,
    required this.cheekRight,
    required this.nose,
    required this.faceWidth,
    this.neck,
  });
}

/// Forma del cuello medida sobre la segmentación.
class NeckShape {
  /// Dónde el borde del cuello toca la ropa a cada lado de la pantalla: por
  /// ahí sale la cadena de detrás del cuello.
  final double leftX, leftY, rightX, rightY;

  /// Centro delantero del escote (donde acaba la piel del cuello sobre la
  /// ropa), o `null` si no se vio: sin ropa debajo o con el cuello tapado.
  final double? frontX, frontY;

  /// Ancho de la columna del cuello por encima de la ropa, en fracciones del
  /// ancho del frame; 0 si la mandíbula la tapaba.
  final double narrowWidth;

  /// Centro de la columna del cuello por encima de la ropa, o `null` si la
  /// mandíbula la tapaba. Es el eje del cuello: de lado, la base incluye el
  /// trapecio de la nuca y su punto medio queda corrido hacia atrás.
  final double? columnX;

  /// Mentón y ancho de cara del frame en que se midió.
  final double refChinX, refChinY, refFaceWidth;

  const NeckShape({
    required this.leftX,
    required this.leftY,
    required this.rightX,
    required this.rightY,
    this.frontX,
    this.frontY,
    required this.narrowWidth,
    this.columnX,
    required this.refChinX,
    required this.refChinY,
    required this.refFaceWidth,
  });
}
