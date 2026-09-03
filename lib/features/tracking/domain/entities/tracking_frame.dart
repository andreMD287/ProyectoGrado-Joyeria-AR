import 'anchor_pose.dart';
import 'landmark.dart';

/// Lo que el pipeline de tracking emite por cada frame procesado.
///
/// Existe para poder comunicar dos cosas que un `AnchorPose` suelto no podía:
///
/// - **La pérdida de tracking.** Antes, si el detector no encontraba la mano,
///   el repositorio simplemente no emitía nada y la UI se quedaba dibujando la
///   última pose indefinidamente, con la joya flotando en el aire. Ahora se
///   emite un frame con [anchor] en `null`.
/// - **Los landmarks crudos**, que el overlay de depuración necesita para
///   dibujar los 21 puntos y verificar el mapeo de coordenadas en dispositivo.
class TrackingFrame {
  /// Pose de anclaje estabilizada, o `null` si se perdió el tracking.
  final AnchorPose? anchor;

  /// Landmarks del detector, sin filtrar, en coordenadas normalizadas del
  /// frame ya rotado a vertical. Vacío cuando no hubo detección.
  final List<Landmark> landmarks;

  const TrackingFrame({
    this.anchor,
    this.landmarks = const [],
  });

  /// Frame sin detección: la UI debe ocultar la joya y pedir que se reencuadre.
  const TrackingFrame.lost()
      : anchor = null,
        landmarks = const [];

  bool get hasAnchor => anchor != null;
}
