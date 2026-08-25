import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../catalog/domain/entities/jewelry_piece.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';

class JewelryDetailScreen extends ConsumerStatefulWidget {
  final String pieceId;

  const JewelryDetailScreen({
    super.key,
    required this.pieceId,
  });

  @override
  ConsumerState<JewelryDetailScreen> createState() =>
      _JewelryDetailScreenState();
}

class _JewelryDetailScreenState
    extends ConsumerState<JewelryDetailScreen> {
  int _viewerVersion = 0;

  static const _background = Color(0xFFFBF7F2);
  static const _surface = Color(0xFFFFFCF8);
  static const _espresso = Color(0xFF3A2419);
  static const _gold = Color(0xFFB4895B);
  static const _champagne = Color(0xFFE7D7C3);

  JewelryPiece? _findPiece(List<JewelryPiece> pieces) {
    for (final piece in pieces) {
      if (piece.id == widget.pieceId) {
        return piece;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogControllerProvider);

    return Scaffold(
      backgroundColor: _background,
      body: catalog.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: _gold,
            strokeWidth: 2,
          ),
        ),
        error: (error, _) => Center(
          child: Text(
            'No se pudo cargar la joya.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
        data: (pieces) {
          final piece = _findPiece(pieces);

          if (piece == null) {
            return const Center(
              child: Text('No encontramos esta joya.'),
            );
          }

          return _buildContent(piece);
        },
      ),
    );
  }

  Widget _buildContent(JewelryPiece piece) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(piece),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: _buildViewer(piece),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 28, 26, 0),
              child: _buildInformation(piece),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
              child: _buildActions(piece),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(JewelryPiece piece) {
    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: _espresso,
                size: 29,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 70),
            child: Text(
              piece.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _espresso,
                fontFamily: 'Georgia',
                fontSize: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewer(JewelryPiece piece) {
    return Container(
      height: 430,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: const Color(0xFFF2E4D5),
        boxShadow: [
          BoxShadow(
            color: _espresso.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8EEE3),
                    Color(0xFFECD9C4),
                  ],
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                6,
                52,
                6,
                45,
              ),
              child: ModelViewer(
                key: ValueKey(_viewerVersion),

                // TEMPORAL:
                // cuando agreguemos los GLB reales,
                // cambiaremos esto por piece.modeloGlb.
                src: 'assets/models/_placeholder.glb',

                alt: piece.nombre,

                ar: false,

                autoRotate: false,

                cameraControls: true,

                disableZoom: false,

                backgroundColor: Colors.transparent,
              ),
            ),
          ),

          Positioned(
            left: 18,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AE68),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                '360°',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                _ViewerButton(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    setState(() {
                      _viewerVersion++;
                    });
                  },
                ),

                const SizedBox(height: 10),

                _ViewerButton(
                  icon: Icons.open_in_full_rounded,
                  onTap: () {
                    context.push(
                      '/piece/${piece.id}/3d',
                    );
                  },
                ),
              ],
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 17,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.pan_tool_alt_outlined,
                  color: Color(0xFF8D7766),
                  size: 18,
                ),
                const SizedBox(width: 7),
                const Text(
                  'Arrastra para girar',
                  style: TextStyle(
                    color: Color(0xFF8D7766),
                    fontSize: 12,
                  ),
                ),

                Container(
                  width: 1,
                  height: 20,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 13),
                  color: const Color(0xFFD4C1AD),
                ),

                const Icon(
                  Icons.pinch_outlined,
                  color: Color(0xFF8D7766),
                  size: 19,
                ),
                const SizedBox(width: 7),
                const Text(
                  'Pellizca para acercar',
                  style: TextStyle(
                    color: Color(0xFF8D7766),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformation(JewelryPiece piece) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          piece.nombre,
          style: const TextStyle(
            color: _espresso,
            fontFamily: 'Georgia',
            fontSize: 37,
            height: 1.05,
          ),
        ),

        const SizedBox(height: 13),

        Text(
          _categoryLabel(piece.categoria).toUpperCase(),
          style: const TextStyle(
            color: _gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.3,
          ),
        ),

        const SizedBox(height: 22),

        Text(
          piece.descripcion ??
              'Una pieza diseñada para complementar tu estilo.',
          style: const TextStyle(
            color: Color(0xFF8B7768),
            fontSize: 16,
            height: 1.55,
          ),
        ),

        const SizedBox(height: 26),

        Row(
          children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.diamond_outlined,
                label: 'MATERIAL',
                value: piece.material ?? 'No disponible',
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _InfoCard(
                icon: Icons.straighten_rounded,
                label: 'MEDIDA',
                value: _dimensionLabel(piece),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _InfoCard(
                icon: _categoryIcon(piece.categoria),
                label: 'TIPO',
                value: _categoryLabel(piece.categoria),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(JewelryPiece piece) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton(
            onPressed: () {
              context.push('/try-on/${piece.id}');
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF171512),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  size: 25,
                ),
                SizedBox(width: 13),
                Text(
                  'Probar virtualmente',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          height: 64,
          child: OutlinedButton(
            onPressed: () {
              context.push(
                '/piece/${piece.id}/3d',
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _gold,
              side: const BorderSide(
                color: _gold,
                width: 1.4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.view_in_ar_outlined,
                  size: 27,
                ),
                SizedBox(width: 13),
                Text(
                  'Ver en 3D',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _categoryLabel(JewelryCategory category) {
    return switch (category) {
      JewelryCategory.bracelet => 'Pulseras',
      JewelryCategory.earring => 'Aretes',
      JewelryCategory.necklace => 'Collares',
    };
  }

  IconData _categoryIcon(JewelryCategory category) {
    return switch (category) {
      JewelryCategory.bracelet => Icons.watch_outlined,
      JewelryCategory.earring => Icons.diamond_outlined,
      JewelryCategory.necklace => Icons.favorite_border_rounded,
    };
  }

  String _dimensionLabel(JewelryPiece piece) {
    final dimensions = piece.dimensionesMm;

    switch (piece.categoria) {
      case JewelryCategory.bracelet:
        if (dimensions.diametro != null) {
          return '${dimensions.diametro!.toStringAsFixed(0)} mm';
        }
        return '${dimensions.ancho.toStringAsFixed(0)} mm';

      case JewelryCategory.earring:
        return '${dimensions.alto.toStringAsFixed(0)} mm';

      case JewelryCategory.necklace:
        if (dimensions.longitud != null) {
          return '${dimensions.longitud!.toStringAsFixed(0)} mm';
        }
        return '${dimensions.alto.toStringAsFixed(0)} mm';
    }
  }
}

class _ViewerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ViewerButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            icon,
            color: const Color(0xFF9D7747),
            size: 27,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE7D7C3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: const Color(0xFFB4895B),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8F7B6C),
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF2C251F),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}