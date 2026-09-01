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
  ///
  /// [imageAspect] es el ancho/alto en píxeles del frame **ya rotado a
  /// vertical**, el mismo marco en el que están normalizados los landmarks.
  /// Hace falta para medir distancias y ángulos reales: en coordenadas
  /// normalizadas un desplazamiento de 0.1 en x y uno de 0.1 en y no miden lo
  /// mismo en pantalla salvo que el frame sea cuadrado. Las estrategias que no
  /// estiman escala ni orientación pueden ignorarlo.
  AnchorPose? computeAnchor(
    List<Landmark> landmarks, {
    double imageAspect,
  });

  /// Limpia estado de sesión (p. ej. lado bloqueado en aretes).
  void reset();
}
