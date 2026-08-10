import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/domain/entities/jewelry_piece.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';
import '../controllers/try_on_controller.dart';

/// Experiencia de prueba virtual de una pieza. En este scaffolding muestra la
/// pieza y el estado del flujo; el render AR se integra en los sprints
/// (ar_flutter_plugin_2 + anclaje estabilizado).
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
          const Spacer(),
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
          const SizedBox(height: 8),
          const Text(
            'Render AR pendiente de integración en los sprints '
            '(colocación con ar_flutter_plugin_2 + anclaje estabilizado).',
            style: TextStyle(fontSize: 12, color: Colors.grey),
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
