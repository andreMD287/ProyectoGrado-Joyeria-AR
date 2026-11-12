import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/jewelry_piece.dart';
import '../controllers/catalog_controller.dart';
import '../widgets/jewelry_bottom_nav.dart';

/// Inicio público de Jewelry AR. El catálogo y la AR siguen usando sus rutas.
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
    return ListView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
              'Jewelry AR',
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
          'DETALLES PARA CADA ESTILO',
          style: TextStyle(
            color: JoyeriaPalette.muted,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Joyas que hablan de ti',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 29,
            color: JoyeriaPalette.espresso,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          textInputAction: TextInputAction.search,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                context.push('/catalog');
              },
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
        const Row(
          children: [
            _CategoryShortcut(label: 'Todas'),
            _CategoryShortcut(label: 'Collares', category: 'collar'),
            _CategoryShortcut(label: 'Aretes', category: 'arete'),
            _CategoryShortcut(label: 'Pulseras', category: 'pulsera'),
          ],
        ),
        const SizedBox(height: 26),
        GestureDetector(
          onTap: () => context.push('/catalog?category=pulsera'),
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
                  right: 9,
                  top: 10,
                  bottom: 10,
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/jewelry_home/06_pulsera_tipo_cartier.jpg',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
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
            height: 238,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _editorialPhotos.length,
              separatorBuilder: (context, index) => const SizedBox(width: 15),
              itemBuilder: (context, index) => SizedBox(
                width: 155,
                child: _EditorialPhotoCard(photo: _editorialPhotos[index]),
              ),
            ),
          ),
      ],
    );
  }
}

/// Fotografías de referencia para el inicio, sin relacionarlas con GLB.
/// Las fichas reales y sus modelos se consultan desde /catalog.
class _EditorialPhoto {
  final String asset;
  final String label;
  final String category;
  const _EditorialPhoto(this.asset, this.label, this.category);
}

const _editorialPhotos = <_EditorialPhoto>[
  _EditorialPhoto(
    'assets/jewelry_home/05_aretes_circulares_circonita.jpg',
    'Aretes circulares con circonita',
    'arete',
  ),
  _EditorialPhoto(
    'assets/jewelry_home/07_pulsera_de_perlas.jpg',
    'Pulsera de perlas',
    'pulsera',
  ),
  _EditorialPhoto(
    'assets/jewelry_home/03_collar_resina_azul.jpg',
    'Collar piedra de resina azul',
    'collar',
  ),
  _EditorialPhoto(
    'assets/jewelry_home/06_pulsera_tipo_cartier.jpg',
    'Pulsera tipo Cartier',
    'pulsera',
  ),
  _EditorialPhoto(
    'assets/jewelry_home/01_collar_piedra_circonita.jpg',
    'Collar piedra de circonita',
    'collar',
  ),
  _EditorialPhoto(
    'assets/jewelry_home/02_cadena_de_plata.jpg',
    'Cadena de plata',
    'collar',
  ),
  _EditorialPhoto(
    'assets/jewelry_home/04_arete_de_perla.jpg',
    'Arete de perla',
    'arete',
  ),
];

class _EditorialPhotoCard extends StatelessWidget {
  final _EditorialPhoto photo;
  const _EditorialPhotoCard({required this.photo});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/catalog?category=${photo.category}'),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                color: JoyeriaPalette.surface,
                child: Image.asset(
                  photo.asset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.diamond_outlined,
                      color: JoyeriaPalette.rose,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            photo.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 16,
              color: JoyeriaPalette.espresso,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Explorar categoría',
            style: TextStyle(fontSize: 11, color: JoyeriaPalette.muted),
          ),
        ],
      ),
    );
  }
}

class _CategoryShortcut extends StatelessWidget {
  final String label;
  final String? category;
  const _CategoryShortcut({required this.label, this.category});

  String? get _iconAsset {
    switch (category) {
      case 'collar':
        return 'assets/jewelry_icons/collar.png';
      case 'arete':
        return 'assets/jewelry_icons/arete.png';
      case 'pulsera':
        return 'assets/jewelry_icons/pulsera.png';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _iconAsset;
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
                color: Colors.white,
                border: Border.all(color: JoyeriaPalette.stroke),
              ),
              child: Center(
                child: asset == null
                    ? const Icon(
                        Icons.grid_view_rounded,
                        color: Color(0xFF763D46),
                        size: 24,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(7),
                        child: Image.asset(
                          asset,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.diamond_outlined,
                                color: Color(0xFF763D46),
                              ),
                        ),
                      ),
              ),
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
