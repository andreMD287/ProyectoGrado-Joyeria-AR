import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/catalog_controller.dart';
import '../widgets/piece_card.dart';

/// Pantalla principal: lista el catálogo de piezas. Al tocar una pieza navega a
/// la experiencia de prueba virtual.
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de joyería')),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudo cargar el catálogo.\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (pieces) => pieces.isEmpty
            ? const Center(child: Text('El catálogo está vacío.'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: pieces.length,
                itemBuilder: (context, i) {
                  final piece = pieces[i];
                  return PieceCard(
                    piece: piece,
                    onTap: () => context.push('/try-on/${piece.id}'),
                  );
                },
              ),
      ),
    );
  }
}
