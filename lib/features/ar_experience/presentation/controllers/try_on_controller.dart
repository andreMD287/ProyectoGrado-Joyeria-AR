import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../tracking/domain/entities/anchor_pose.dart';
import '../../../tracking/domain/entities/landmark.dart';
import '../../../tracking/domain/entities/tracking_frame.dart';
import '../../../tracking/domain/strategies/earring_strategy.dart';

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

/// Detectando y renderizando.
///
/// [anchor] es la última pose de anclaje, o `null` si se perdió el tracking:
/// la UI debe ocultar la joya en ese caso, no seguir dibujando la última pose.
class TryOnActive extends TryOnState {
  final AnchorPose? anchor;

  /// Landmarks crudos del último frame, para el overlay de depuración.
  final List<Landmark> landmarks;

  /// Frecuencia de detección medida, en Hz. Es el número que dice si el
  /// pipeline va lento; el render corre aparte, a la tasa de la pantalla.
  final double fps;

  const TryOnActive({
    this.anchor,
    this.landmarks = const [],
    this.fps = 0,
  });
}

class TryOnError extends TryOnState {
  final String message;
  const TryOnError(this.message);
}

/// Orquesta permiso → cámara → tracking → estado observable por la UI.
class TryOnController extends AutoDisposeNotifier<TryOnState> {
  StreamSubscription<TrackingFrame>? _sub;
  int _lastFrameMs = 0;
  double _fps = 0;

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
    if (category == JewelryCategory.earring) {
      final strategy = ref.read(trackingStrategiesProvider)[category];
      if (strategy is EarringStrategy) {
        strategy.setPreferredSide(ref.read(earringPreferredSideProvider));
      }
    }
    final repo = ref.read(trackingRepositoryProvider);
    state = const TryOnActive();
    _lastFrameMs = 0;
    _fps = 0;
    _sub = repo.trackingStream(category).listen(
      _onFrame,
      onError: (Object e) => state = TryOnError('$e'),
    );
  }

  void _onFrame(TrackingFrame frame) {
    state = TryOnActive(
      anchor: frame.anchor,
      landmarks: frame.landmarks,
      fps: _measureFps(),
    );
  }

  /// Media exponencial de la frecuencia de emisión, para que el número del HUD
  /// no salte con cada frame perdido.
  double _measureFps() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastFrameMs > 0) {
      final dt = now - _lastFrameMs;
      if (dt > 0) {
        final instant = 1000.0 / dt;
        _fps = _fps == 0 ? instant : _fps * 0.8 + instant * 0.2;
      }
    }
    _lastFrameMs = now;
    return _fps;
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
