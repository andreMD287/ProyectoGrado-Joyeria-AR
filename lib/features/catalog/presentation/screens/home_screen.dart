import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/jewelry_category.dart';
import '../../domain/entities/jewelry_piece.dart';
import '../controllers/catalog_controller.dart';
import '../widgets/jewelry_artwork.dart';
import '../widgets/jewelry_bottom_nav.dart';
import '../widgets/piece_card.dart';

/// Inicio público de Joyería AR. No muestra perfil, login ni registro.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogControllerProvider);
    return Scaffold(
      backgroundColor: JoyeriaPalette.background,
      bottomNavigationBar: const JewelryBottomNav(isHome: true),
      body: SafeArea(
        bottom: false,
        child: catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Text(
                'No fue posible cargar las joyas.\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (pieces) => _buildHome(context, pieces),
        ),
      ),
    );
  }

  Widget _buildHome(BuildContext context, List<JewelryPiece> pieces) {
    final featured = pieces
        .where((p) => p.categoria == JewelryCategory.necklace)
        .toList();
    final heroPiece = featured.isNotEmpty
        ? featured.first
        : (pieces.isEmpty ? null : pieces.first);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              color: JoyeriaPalette.gold,
              size: 22,
            ),
            Text(
              'Joyería AR',
              style: TextStyle(
                fontSize: 25,
                fontFamily: 'Georgia',
                color: JoyeriaPalette.espresso,
              ),
            ),
            Icon(Icons.diamond_outlined, color: JoyeriaPalette.rose, size: 23),
          ],
        ),
        const SizedBox(height: 34),
        const Text(
          'EXPLORA SIN REGISTRO',
          style: TextStyle(
            color: JoyeriaPalette.muted,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          '¿Qué joya te pruebas hoy?',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 29,
            color: JoyeriaPalette.espresso,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => context.push(
            Uri(
              path: '/catalog',
              queryParameters: {'search': value},
            ).toString(),
          ),
          decoration: InputDecoration(
            hintText: 'Buscar collares, aretes...',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: JoyeriaPalette.muted,
            ),
            prefixIcon: const Icon(Icons.search, color: JoyeriaPalette.muted),
            suffixIcon: IconButton(
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: JoyeriaPalette.rose,
              ),
              onPressed: () => context.push('/catalog'),
            ),
            fillColor: JoyeriaPalette.surface,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40),
              borderSide: const BorderSide(color: JoyeriaPalette.stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40),
              borderSide: const BorderSide(color: JoyeriaPalette.rose),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _CategoryShortcut(
              label: 'Collares',
              icon: Icons.favorite_border,
              category: 'collar',
            ),
            _CategoryShortcut(
              label: 'Aretes',
              icon: Icons.diamond_outlined,
              category: 'arete',
            ),
            _CategoryShortcut(
              label: 'Pulseras',
              icon: Icons.watch_outlined,
              category: 'pulsera',
            ),
            const _CategoryShortcut(
              label: 'Todas',
              icon: Icons.grid_view_rounded,
            ),
          ],
        ),
        const SizedBox(height: 26),
        if (heroPiece != null)
          GestureDetector(
            onTap: () => context.push('/piece/${heroPiece.id}'),
            child: Container(
              height: 186,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: JoyeriaPalette.mutedRose,
                borderRadius: BorderRadius.circular(23),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -8,
                    top: 9,
                    bottom: 8,
                    width: 172,
                    child: JewelryArtwork(piece: heroPiece, showPhoto: false),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(17, 22, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NUEVA COLECCIÓN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Elegancia\nnatural',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Georgia',
                              fontSize: 25,
                              height: 1.04,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: JoyeriaPalette.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Descubrir  ›',
                              style: TextStyle(
                                fontSize: 12,
                                color: JoyeriaPalette.rose,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Destacadas',
              style: TextStyle(
                color: JoyeriaPalette.espresso,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/catalog'),
              child: const Text('Ver todo'),
            ),
          ],
        ),
        if (pieces.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('La colección todavía no tiene piezas.'),
          ),
        if (pieces.isNotEmpty)
          SizedBox(
            height: 228,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pieces.length,
              separatorBuilder: (_, __) => const SizedBox(width: 15),
              itemBuilder: (context, index) => SizedBox(
                width: 155,
                child: PieceCard(
                  piece: pieces[index],
                  onTap: () => context.push('/piece/${pieces[index].id}'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryShortcut extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? category;
  const _CategoryShortcut({
    required this.label,
    required this.icon,
    this.category,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => context.push(
          category == null ? '/catalog' : '/catalog?category=$category',
        ),
        borderRadius: BorderRadius.circular(17),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: JoyeriaPalette.surface,
                border: Border.all(color: JoyeriaPalette.stroke),
              ),
              child: Icon(icon, color: JoyeriaPalette.rose, size: 22),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: const TextStyle(
                color: JoyeriaPalette.espresso,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
