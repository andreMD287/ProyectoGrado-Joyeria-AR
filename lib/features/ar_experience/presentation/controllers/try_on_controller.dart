import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../tracking/domain/entities/anchor_pose.dart';

/// Estados de la experiencia de prueba virtual. Formaliza lo que en la fase de
/// validación previa era un enum ad hoc por pantalla.
sealed class TryOnState {
  const TryOnState();
}

class TryOnIdle extends TryOnState {
  const TryOnIdle();
}

class TryOnRequestingPermission extends TryOnState {
  const TryOnRequestingPermission();
}

class TryOnPermissionDenied extends TryOnState {
  const TryOnPermissionDenied();
}

class TryOnUnsupported extends TryOnState {
  final String reason;
  const TryOnUnsupported(this.reason);
}

/// Detectando y renderizando; [anchor] es la última pose de anclaje.
class TryOnActive extends TryOnState {
  final AnchorPose? anchor;
  final double fps;
  const TryOnActive({this.anchor, this.fps = 0});
}

class TryOnError extends TryOnState {
  final String message;
  const TryOnError(this.message);
}

/// Orquesta permiso → cámara → tracking → estado observable por la UI.
class TryOnController extends AutoDisposeNotifier<TryOnState> {
  StreamSubscription<AnchorPose>? _sub;

  @override
  TryOnState build() {
    final repo = ref.read(trackingRepositoryProvider);
    ref.onDispose(() {
      _sub?.cancel();
      // No se puede `await` en onDispose; se libera la cámara sin esperar a
      // que termine. `stop()` es seguro de invocar aunque ya esté liberada.
      repo.stop();
    });
    return const TryOnIdle();
  }

  Future<void> start(JewelryCategory category) async {
    state = const TryOnRequestingPermission();
    final granted = await ref.read(permissionServiceProvider).ensureCamera();
    if (!granted) {
      state = const TryOnPermissionDenied();
      return;
    }
    final repo = ref.read(trackingRepositoryProvider);
    state = const TryOnActive();
    _sub = repo.anchorPoseStream(category).listen(
      (pose) => state = TryOnActive(anchor: pose),
      onError: (Object e) => state = TryOnError('$e'),
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await ref.read(trackingRepositoryProvider).stop();
    state = const TryOnIdle();
  }
}

final tryOnControllerProvider =
    AutoDisposeNotifierProvider<TryOnController, TryOnState>(
        TryOnController.new);
