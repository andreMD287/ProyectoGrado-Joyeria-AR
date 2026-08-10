import '../../../catalog/domain/entities/jewelry_category.dart';
import '../entities/anchor_pose.dart';

/// Frontera hacia la capa de datos del tracking. Oculta la selección de
/// detector (según plataforma), el isolate de detección y la estabilización.
abstract interface class TrackingRepository {
  /// Emite poses de anclaje estabilizadas para la categoría dada, a partir del
  /// stream de cámara.
  Stream<AnchorPose> anchorPoseStream(JewelryCategory category);

  /// Detiene la detección y libera la cámara.
  Future<void> stop();
}
