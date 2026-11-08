import '../../../../core/math/head_geometry.dart';
import 'landmark.dart';

/// La cabeza medida con MediaPipe Face Landmarker para colgar los aretes
/// (Android, ver `NeckTracker` en modo `head`).
///
/// Todo va en el espacio de la vista previa: normalizado al frame ya rotado a
/// vertical y espejado como se ve en pantalla.
class HeadObservation {
  /// Mejilla derecha **de la persona**, delante de su oreja derecha.
  static const int rightFaceSide = 234;

  /// Mejilla izquierda de la persona, delante de su oreja izquierda.
  static const int leftFaceSide = 454;

  static const int forehead = 10;
  static const int chin = 152;

  /// Puntos de la malla por su índice de MediaPipe. La `z` es la profundidad
  /// relativa de la malla, en la escala de `x`, y crece al alejarse.
  final Map<int, Landmark> points;

  /// Orientación de la cabeza que da la matriz de transformación facial, ya
  /// llevada al espacio de la vista previa. `null` si no llegó; entonces se
  /// estima con los puntos.
  final HeadAxes? axes;

  /// Si la vista previa está espejada respecto a la imagen que vio MediaPipe.
  ///
  /// Decide qué mejilla queda en el +x local de [axes]: sin espejo, la
  /// izquierda de la persona, que es la que se ve a la derecha de la pantalla;
  /// con espejo, la derecha (ver `HeadAxes.mirrored`).
  final bool mirrored;

  const HeadObservation({
    required this.points,
    this.axes,
    required this.mirrored,
  });

  /// Lado local (+1 o -1 en x) de la oreja izquierda de la persona.
  int get leftEarSide => mirrored ? -1 : 1;

  /// Mejilla en el lado local -x.
  Landmark? get negativeSide =>
      points[mirrored ? leftFaceSide : rightFaceSide];

  /// Mejilla en el lado local +x.
  Landmark? get positiveSide =>
      points[mirrored ? rightFaceSide : leftFaceSide];
}
