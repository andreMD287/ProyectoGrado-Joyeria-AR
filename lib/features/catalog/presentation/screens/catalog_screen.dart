import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/jewelry_category.dart';
import '../../domain/entities/jewelry_piece.dart';
import '../controllers/catalog_controller.dart';
import '../widgets/piece_card.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  JewelryCategory? _selectedCategory;
  String _query = '';

  static const _background = Color(0xFFFBF7F2);
  static const _espresso = Color(0xFF3A2419);
  static const _gold = Color(0xFFB4895B);
  static const _champagne = Color(0xFFE7D7C3);
  static const _softSurface = Color(0xFFFFFCF8);

  List<JewelryPiece> _filterPieces(List<JewelryPiece> pieces) {
    final query = _query.trim().toLowerCase();

    return pieces.where((piece) {
      final categoryMatches =
          _selectedCategory == null || piece.categoria == _selectedCategory;

      final queryMatches =
          query.isEmpty ||
          piece.nombre.toLowerCase().contains(query) ||
          (piece.material?.toLowerCase().contains(query) ?? false) ||
          (piece.descripcion?.toLowerCase().contains(query) ?? false);

      return categoryMatches && queryMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogControllerProvider);

    return Scaffold(
      backgroundColor: _background,
      body: catalog.when(
        loading: () => const _LuxuryLoading(),
        error: (error, _) => _CatalogError(error: error),
        data: (pieces) {
          final filteredPieces = _filterPieces(pieces);

          return Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(
                  painter: _CatalogBackgroundPainter(),
                ),
              ),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                        child: _buildHeader(),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                        child: _buildSearchBar(),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                        child: _buildCategories(),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                        child: _buildSectionTitle(),
                      ),
                    ),

                    if (filteredPieces.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 70),
                          child: _EmptyCatalog(),
                        ),
                      )
                    else ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _FeaturedPieceCard(
                            piece: filteredPieces.first,
                            onTap: () => context.push(
                              '/try-on/${filteredPieces.first.id}',
                            ),
                          ),
                        ),
                      ),

                      if (filteredPieces.length > 1)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 130),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final piece = filteredPieces[index + 1];

                                return PieceCard(
                                  piece: piece,
                                  onTap: () => context.push(
                                    '/try-on/${piece.id}',
                                  ),
                                );
                              },
                              childCount: filteredPieces.length - 1,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.64,
                            ),
                          ),
                        )
                      else
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 130),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const _LuxuryBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'B I E N V E N I D A',
                style: TextStyle(
                  color: _gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.4,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Descubre tu\npróxima joya',
                style: TextStyle(
                  color: _espresso,
                  fontSize: 43,
                  height: 1.05,
                  letterSpacing: -1.2,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: _softSurface,
            shape: BoxShape.circle,
            border: Border.all(
              color: _champagne,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: _espresso.withValues(alpha: 0.07),
                blurRadius: 20,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.view_in_ar_outlined,
                color: _gold,
                size: 24,
              ),
              SizedBox(height: 2),
              Text(
                'AR',
                style: TextStyle(
                  color: _gold,
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _champagne.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: _espresso.withValues(alpha: 0.055),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _query = value;
          });
        },
        cursorColor: _gold,
        style: const TextStyle(
          color: _espresso,
          fontSize: 15,
        ),
        decoration: const InputDecoration(
          hintText: 'Busca tu joya ideal...',
          hintStyle: TextStyle(
            color: Color(0xFFAA9687),
            fontSize: 14,
            letterSpacing: 0.3,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Color(0xFF806D5E),
            size: 27,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            vertical: 17,
            horizontal: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Row(
      children: [
        Expanded(
          child: _CategoryChip(
            label: 'Pulseras',
            icon: Icons.watch_outlined,
            selected: _selectedCategory == JewelryCategory.bracelet,
            onTap: () {
              setState(() {
                _selectedCategory =
                    _selectedCategory == JewelryCategory.bracelet
                        ? null
                        : JewelryCategory.bracelet;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CategoryChip(
            label: 'Aretes',
            icon: Icons.diamond_outlined,
            selected: _selectedCategory == JewelryCategory.earring,
            onTap: () {
              setState(() {
                _selectedCategory =
                    _selectedCategory == JewelryCategory.earring
                        ? null
                        : JewelryCategory.earring;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CategoryChip(
            label: 'Collares',
            icon: Icons.favorite_border_rounded,
            selected: _selectedCategory == JewelryCategory.necklace,
            onTap: () {
              setState(() {
                _selectedCategory =
                    _selectedCategory == JewelryCategory.necklace
                        ? null
                        : JewelryCategory.necklace;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle() {
    return const Row(
      children: [
        Icon(
          Icons.auto_awesome,
          size: 19,
          color: _gold,
        ),
        SizedBox(width: 10),
        Text(
          'Colección destacada',
          style: TextStyle(
            color: _espresso,
            fontSize: 22,
            fontFamily: 'Georgia',
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFB4895B);
    const espresso = Color(0xFF3A2419);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 59,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF8A6243)
                : const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: selected
                  ? const Color(0xFF8A6243)
                  : const Color(0xFFE7D7C3),
            ),
            boxShadow: [
              BoxShadow(
                color: espresso.withValues(alpha: 0.045),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: selected ? Colors.white : gold,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : espresso,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedPieceCard extends StatelessWidget {
  final JewelryPiece piece;
  final VoidCallback onTap;

  const _FeaturedPieceCard({
    required this.piece,
    required this.onTap,
  });

  IconData get _icon => switch (piece.categoria) {
        JewelryCategory.bracelet => Icons.watch_outlined,
        JewelryCategory.earring => Icons.diamond_outlined,
        JewelryCategory.necklace => Icons.favorite_border_rounded,
      };

  String get _categoryLabel => switch (piece.categoria) {
        JewelryCategory.bracelet => 'Pulsera',
        JewelryCategory.earring => 'Arete',
        JewelryCategory.necklace => 'Collar',
      };

  @override
  Widget build(BuildContext context) {
    const espresso = Color(0xFF3A2419);
    const gold = Color(0xFFB4895B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 230,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFE7D7C3),
            ),
            boxShadow: [
              BoxShadow(
                color: espresso.withValues(alpha: 0.07),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 23, 12, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7EDE2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _categoryLabel.toUpperCase(),
                          style: const TextStyle(
                            color: gold,
                            fontSize: 9,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        piece.nombre,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: espresso,
                          fontFamily: 'Georgia',
                          fontSize: 23,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 35,
                        height: 1,
                        color: gold,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        piece.material ?? 'Joyería fina',
                        style: const TextStyle(
                          color: Color(0xFF837062),
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      const Row(
                        children: [
                          Text(
                            'Probar en AR',
                            style: TextStyle(
                              color: gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: gold,
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 11,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF6EBDD),
                        Color(0xFFE8D4BD),
                      ],
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        width: 190,
                        height: 190,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: gold.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        _icon,
                        size: 82,
                        color: gold.withValues(alpha: 0.82),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LuxuryBottomNav extends StatelessWidget {
  const _LuxuryBottomNav();

  @override
  Widget build(BuildContext context) {
    const espresso = Color(0xFF3A2419);
    const gold = Color(0xFFB4895B);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        border: const Border(
          top: BorderSide(
            color: Color(0xFFE9DDCF),
            width: 0.7,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: espresso.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Inicio',
                selected: true,
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.diamond_outlined,
                label: 'Catálogo',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Ya estás viendo el catálogo.',
                      ),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              _NavItem(
                icon: Icons.favorite_border_rounded,
                label: 'Favoritos',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Favoritos estará disponible próximamente.',
                      ),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Perfil',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Perfil estará disponible próximamente.',
                      ),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    const espresso = Color(0xFF3A2419);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 38 : 32,
              height: selected ? 38 : 32,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF805A3E)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 23,
                color: selected
                    ? Colors.white
                    : const Color(0xFF78675A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? espresso
                    : const Color(0xFF8F7E71),
                fontSize: 10,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LuxuryLoading extends StatelessWidget {
  const _LuxuryLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFFBF7F2),
      child: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFB4895B),
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  final Object error;

  const _CatalogError({
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFBF7F2),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Color(0xFFB4895B),
              ),
              const SizedBox(height: 14),
              const Text(
                'No pudimos cargar la colección.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  color: Color(0xFF3A2419),
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8F7E71),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(
          Icons.diamond_outlined,
          size: 45,
          color: Color(0xFFB4895B),
        ),
        SizedBox(height: 14),
        Text(
          'No encontramos joyas',
          style: TextStyle(
            fontFamily: 'Georgia',
            color: Color(0xFF3A2419),
            fontSize: 21,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Prueba otra búsqueda o categoría.',
          style: TextStyle(
            color: Color(0xFF8F7E71),
          ),
        ),
      ],
    );
  }
}

class _CatalogBackgroundPainter extends CustomPainter {
  const _CatalogBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD8BE9A).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final center = Offset(
      size.width * 1.08,
      size.height * 0.17,
    );

    canvas.drawCircle(
      center,
      size.width * 0.52,
      paint,
    );

    canvas.drawCircle(
      center,
      size.width * 0.72,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}