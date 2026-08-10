import '../../../../core/filters/landmark_stabilizer.dart';
import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../domain/entities/anchor_pose.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/strategies/tracking_strategy.dart';
import '../datasources/hand_detector.dart';

/// Orquesta el pipeline de tracking: cámara → (isolate de detección) → detector
/// → estrategia de anclaje → estabilizador → [AnchorPose].
///
/// El detector se inyecta según la plataforma; la estrategia según la categoría.
///
/// TODO(C2/C3/B5): conectar `CameraService` + isolate de detección + detector
/// real; por cada frame, obtener landmarks, calcular la pose con la estrategia
/// y estabilizarla con [stabilizer] antes de emitirla.
class TrackingRepositoryImpl implements TrackingRepository {
  final HandDetector handDetector;
  final Map<JewelryCategory, TrackingStrategy> strategies;
  final LandmarkStabilizer stabilizer;

  TrackingRepositoryImpl({
    required this.handDetector,
    required this.strategies,
    LandmarkStabilizer? stabilizer,
  }) : stabilizer = stabilizer ?? OneEuroStabilizer();

  @override
  Stream<AnchorPose> anchorPoseStream(JewelryCategory category) {
    // Pendiente de implementación del pipeline en tiempo real.
    return const Stream<AnchorPose>.empty();
  }

  @override
  Future<void> stop() async {
    await handDetector.dispose();
    stabilizer.reset();
  }
}
