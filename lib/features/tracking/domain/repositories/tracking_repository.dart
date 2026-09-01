import '../../../catalog/domain/entities/jewelry_category.dart';
import '../entities/tracking_frame.dart';

/// Frontera hacia la capa de datos del tracking. Oculta la selección de
/// detector (según plataforma), el isolate de detección y la estabilización.
abstract interface class TrackingRepository {
  /// Emite un [TrackingFrame] por cada frame procesado de la categoría dada:
  /// con la pose de anclaje estabilizada, o con `anchor` en `null` cuando se
  /// pierde el tracking.
  Stream<TrackingFrame> trackingStream(JewelryCategory category);

  /// Detiene la detección y libera la cámara.
  Future<void> stop();
}
