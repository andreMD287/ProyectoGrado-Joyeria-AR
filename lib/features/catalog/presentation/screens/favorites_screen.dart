import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../controllers/catalog_controller.dart';
import '../controllers/favorites_controller.dart';
import '../widgets/piece_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogControllerProvider);
    final favorites = ref.watch(favoritesProvider);
    return Scaffold(
      backgroundColor: JoyeriaPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 22, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Volver',
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: JoyeriaPalette.espresso,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Mi joyero',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 28,
                        color: JoyeriaPalette.espresso,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.diamond_outlined,
                    color: JoyeriaPalette.rose,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'TUS JOYAS FAVORITAS',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                    color: JoyeriaPalette.rose,
                  ),
                ),
              ),
            ),
            Expanded(
              child: favorites.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Error al cargar favoritos: $error')),
                data: (ids) => catalog.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Center(child: Text('Error al cargar catálogo: $error')),
                  data: (pieces) {
                    final selected = pieces
                        .where((p) => ids.contains(p.id))
                        .toList();
                    if (selected.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.favorite_border_rounded,
                                size: 54,
                                color: JoyeriaPalette.rose,
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Tu joyero te espera',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 25,
                                  color: JoyeriaPalette.espresso,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Marca el corazón de tus joyas favoritas para guardarlas aquí.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: JoyeriaPalette.muted,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 22),
                              FilledButton(
                                onPressed: () => context.go('/catalog'),
                                child: const Text('Explorar catálogo'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                            child: Text(
                              '${selected.length} joyas guardadas',
                              style: const TextStyle(
                                color: JoyeriaPalette.muted,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                          sliver: SliverGrid.builder(
                            itemCount: selected.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 18,
                                  crossAxisSpacing: 15,
                                  // Igual que en catalog_screen.dart: con .67
                                  // la celda no alcanzaba para un nombre de 2
                                  // líneas ("Collar con dije transparente"
                                  // etc.), desbordaba ~11px abajo.
                                  childAspectRatio: 0.64,
                                ),
                            itemBuilder: (context, index) => PieceCard(
                              piece: selected[index],
                              onTap: () =>
                                  context.push('/piece/${selected[index].id}'),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
