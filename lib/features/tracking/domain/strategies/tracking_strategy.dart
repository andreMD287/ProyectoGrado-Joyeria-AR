import '../../../catalog/domain/entities/jewelry_category.dart';
import '../entities/anchor_pose.dart';
import '../entities/landmark.dart';

/// Tipo de detector que requiere una estrategia.
enum DetectorKind { hand, face, pose }

/// Estrategia de anclaje por categoría (patrón Strategy). Cada categoría sabe
/// qué detector necesita y cómo transformar los landmarks crudos en el punto
/// y orientación de anclaje. Añadir una categoría = añadir una estrategia.
abstract interface class TrackingStrategy {
  JewelryCategory get category;
  DetectorKind get detectorKind;

  /// Calcula la pose de anclaje a partir de los landmarks; `null` si no hay
  /// datos suficientes.
  AnchorPose? computeAnchor(List<Landmark> landmarks);

  /// Limpia estado de sesión (p. ej. lado bloqueado en aretes).
  void reset();
}
