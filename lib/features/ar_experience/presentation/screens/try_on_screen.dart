import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../core/di/providers.dart';
import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../catalog/domain/entities/jewelry_piece.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';
import '../../../tracking/domain/entities/anchor_pose.dart';
import '../controllers/try_on_controller.dart';

/// Modelo de referencia usado cuando el GLB real de la pieza (D2, catálogo)
/// todavía no existe en el repositorio, para poder validar el pipeline de
/// render sobre el punto de anclaje sin esperar al modelado final.
const _placeholderModelAsset = 'assets/models/_placeholder.glb';

final _resolvedModelAssetProvider =
    FutureProvider.family<String, String>((ref, assetPath) async {
  try {
    await rootBundle.load(assetPath);
    return assetPath;
  } catch (_) {
    return _placeholderModelAsset;
  }
});

/// Experiencia de prueba virtual de una pieza: cámara en vivo con el modelo
/// 3D superpuesto en el punto de anclaje que entrega el pipeline de tracking.
class TryOnScreen extends ConsumerWidget {
  final String pieceId;
  const TryOnScreen({super.key, required this.pieceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Prueba virtual')),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pieces) {
          JewelryPiece? piece;
          for (final p in pieces) {
            if (p.id == pieceId) {
              piece = p;
              break;
            }
          }
          if (piece == null) {
            return const Center(child: Text('Pieza no encontrada.'));
          }
          return _TryOnBody(piece: piece);
        },
      ),
    );
  }
}

class _TryOnBody extends ConsumerWidget {
  final JewelryPiece piece;
  const _TryOnBody({required this.piece});

  String _statusLabel(TryOnState s) => switch (s) {
        TryOnIdle() => 'Listo para iniciar',
        TryOnRequestingPermission() => 'Solicitando permiso de cámara…',
        TryOnPermissionDenied() => 'Permiso de cámara denegado',
        TryOnUnsupported(:final reason) => 'No disponible: $reason',
        TryOnActive(:final anchor) =>
          anchor == null ? 'Detectando…' : 'Anclado: ${anchor.position}',
        TryOnError(:final message) => 'Error: $message',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tryOnControllerProvider);
    final controller = ref.read(tryOnControllerProvider.notifier);
    final active = state is TryOnActive || state is TryOnRequestingPermission;
    final anchor = switch (state) {
      TryOnActive(:final anchor) => anchor,
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(piece.nombre,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Categoría: ${piece.categoria.id}'),
          Text('Anclaje: ${piece.categoria.anchorType.name}'),
          if (piece.descripcion != null) ...[
            const SizedBox(height: 8),
            Text(piece.descripcion!),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: active
                ? _CameraOverlay(piece: piece, anchor: anchor)
                : _IdlePreview(reason: state is TryOnUnsupported ? state.reason : null),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.view_in_ar),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_statusLabel(state))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: active
                ? controller.stop
                : () => controller.start(piece.categoria),
            icon: Icon(active ? Icons.stop : Icons.play_arrow),
            label: Text(active ? 'Detener' : 'Iniciar prueba'),
          ),
        ],
      ),
    );
  }
}

class _IdlePreview extends StatelessWidget {
  final String? reason;
  const _IdlePreview({this.reason});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_in_ar,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 8),
            Text(reason ?? 'Inicia la prueba para activar la cámara.'),
          ],
        ),
      ),
    );
  }
}

/// Vista previa de cámara con el modelo 3D superpuesto en el punto de
/// anclaje. El controlador de cámara se observa de forma reactiva porque
/// queda listo antes de que llegue la primera detección.
class _CameraOverlay extends ConsumerWidget {
  final JewelryPiece piece;
  final AnchorPose? anchor;
  const _CameraOverlay({required this.piece, required this.anchor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraService = ref.watch(cameraServiceProvider);
    return ValueListenableBuilder<CameraController?>(
      valueListenable: cameraService.controllerNotifier,
      builder: (context, camController, _) {
        if (camController == null || !camController.value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1 / camController.value.aspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(camController),
                  if (anchor != null)
                    _ModelOverlay(
                      piece: piece,
                      anchor: anchor!,
                      areaSize: constraints.biggest,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pieza 3D posicionada sobre el punto de anclaje normalizado (x, y ∈ [0,1]
/// en el espacio del frame de cámara, igual que el widget de vista previa).
/// El tamaño del overlay es por categoría. Los aretes se anclan por el **punto
/// superior** del widget (como un piercing); pulsera/collar usan el centro.
class _ModelOverlay extends ConsumerWidget {
  final JewelryPiece piece;
  final AnchorPose anchor;
  final Size areaSize;

  const _ModelOverlay({
    required this.piece,
    required this.anchor,
    required this.areaSize,
  });

  double get _size => switch (piece.categoria) {
        JewelryCategory.earring => 44,
        JewelryCategory.necklace => 64,
        JewelryCategory.bracelet => 72,
      };

  /// Aretes: el anclaje es el punto de perforación; el modelo cuelga hacia abajo.
  bool get _anchorAtTop => piece.categoria == JewelryCategory.earring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsset = ref.watch(_resolvedModelAssetProvider(piece.modeloGlb));
    final size = _size;
    final maxLeft = math.max(0.0, areaSize.width - size);
    final maxTop = math.max(0.0, areaSize.height - size);
    final anchorX = anchor.position.x * areaSize.width;
    final anchorY = anchor.position.y * areaSize.height;
    final left = (anchorX - size / 2).clamp(0.0, maxLeft);
    final top = (_anchorAtTop ? anchorY : anchorY - size / 2).clamp(0.0, maxTop);

    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: modelAsset.when(
        loading: () => const SizedBox.shrink(),
        error: (error, stack) => const SizedBox.shrink(),
        data: (src) => IgnorePointer(
          child: ModelViewer(
            key: ValueKey('model-${piece.categoria.id}-$size'),
            src: src,
            backgroundColor: Colors.transparent,
            cameraControls: false,
            disableZoom: true,
            disablePan: true,
            disableTap: true,
            autoRotate: false,
          ),
        ),
      ),
    );
  }
}
