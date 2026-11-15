import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../core/assets/resolved_model_asset.dart';
import '../../../../core/widgets/current_route_only.dart';
import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../catalog/domain/entities/jewelry_piece.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';
import '../../../catalog/presentation/controllers/favorites_controller.dart';

class JewelryDetailScreen extends ConsumerStatefulWidget {
  final String pieceId;

  const JewelryDetailScreen({super.key, required this.pieceId});

  @override
  ConsumerState<JewelryDetailScreen> createState() =>
      _JewelryDetailScreenState();
}

class _JewelryDetailScreenState extends ConsumerState<JewelryDetailScreen> {
  int _viewerVersion = 0;

  static const _background = Color(0xFFF8F0EE);
  static const _espresso = Color(0xFF432B31);
  static const _gold = Color(0xFFA35F70);

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
          child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
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
            return const Center(child: Text('No encontramos esta joya.'));
          }

          return _buildContent(piece);
        },
      ),
    );
  }

  Widget _buildContent(JewelryPiece piece) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Normal iPhone: everything visible, without vertical scrolling.
          // Short screens / large accessibility text: preserve all content.
          final fallback =
              constraints.maxHeight < 720 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final details = _buildInformation(piece);
          final actions = _buildActions(piece);

          if (fallback) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildHeader(piece),
                  const SizedBox(height: 8),
                  SizedBox(height: 270, child: _buildViewer(piece)),
                  const SizedBox(height: 14),
                  details,
                  const SizedBox(height: 14),
                  actions,
                  const SizedBox(height: 12),
                ],
              ),
            );
          }

          final viewerHeight = (constraints.maxHeight * 0.47)
              .clamp(270.0, 390.0)
              .toDouble();
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeader(piece),
                SizedBox(height: viewerHeight, child: _buildViewer(piece)),
                details,
                actions,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(JewelryPiece piece) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: IconButton(
              tooltip: 'Volver',
              padding: EdgeInsets.zero,
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: _espresso),
            ),
          ),
          const Expanded(
            child: Text(
              'DETALLE DE JOYA',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _espresso,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: IconButton(
              tooltip:
                  ref
                          .watch(favoritesProvider)
                          .valueOrNull
                          ?.contains(piece.id) ??
                      false
                  ? 'Quitar de mi joyero'
                  : 'Guardar en mi joyero',
              onPressed: () {
                ref.read(favoritesProvider.notifier).toggle(piece.id);
              },
              icon: Icon(
                ref.watch(favoritesProvider).valueOrNull?.contains(piece.id) ??
                        false
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewer(JewelryPiece piece) {
    // Para una foto sin modelo confirmado, nunca mostramos un GLB de otra joya.
    if (piece.modeloGlb.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: const Color(0xFFF0DEDA),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              piece.foto,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => const Center(
                child: Icon(Icons.diamond_outlined, size: 54, color: _gold),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.93),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'FOTOGRAFÍA',
                    style: TextStyle(
                      color: _espresso,
                      letterSpacing: 1,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Text(
                'Modelo 3D pendiente de verificar',
                textAlign: TextAlign.center,
                style: TextStyle(color: _espresso, fontSize: 11),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: const Color(0xFFF0DEDA),
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
                  colors: [Color(0xFFF8EEEE), Color(0xFFE9D3D1)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(3, 35, 3, 25),
              child: ref
                  .watch(resolvedModelAssetProvider(piece.modeloGlb))
                  .when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: _gold,
                        strokeWidth: 2,
                      ),
                    ),
                    error: (_, _) => const Center(
                      child: CircularProgressIndicator(
                        color: _gold,
                        strokeWidth: 2,
                      ),
                    ),
                    data: (src) => CurrentRouteOnly(
                      child: ModelViewer(
                        key: ValueKey('$_viewerVersion-$src'),
                        src: src,
                        alt: piece.nombre,
                        orientation: piece.orientacionYawDeg == 0
                            ? null
                            : '0deg 0deg ${piece.orientacionYawDeg}deg',
                        ar: false,
                        autoRotate: false,
                        cameraControls: true,
                        disableZoom: false,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
            ),
          ),
          Positioned(
            left: 18,
            top: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AE68),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                '360°',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
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
                    context.push('/piece/${piece.id}/3d');
                  },
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 15,
                  color: Color(0xFF8D7766),
                ),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Arrastra para girar · Pellizca para acercar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Color(0xFF8D7766)),
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
    // Diseño editorial: especificaciones de solo lectura, no son botones.
    final measureTitle = switch (piece.categoria) {
      JewelryCategory.bracelet =>
        piece.dimensionesMm.diametro != null ? 'DIÁMETRO' : 'MEDIDA',
      JewelryCategory.necklace =>
        piece.dimensionesMm.longitud != null ? 'LONGITUD' : 'MEDIDA',
      JewelryCategory.earring => 'ALTURA',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _categoryLabel(piece.categoria).toUpperCase(),
          style: const TextStyle(
            color: _gold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          piece.nombre,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _espresso,
            fontFamily: 'Georgia',
            fontSize: 27,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          piece.descripcion ??
              'Una pieza diseñada para complementar tu estilo.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF8B7768),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE5CFCB)),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.layers_outlined,
                label: 'MATERIAL',
                value: piece.material ?? 'Por confirmar',
              ),
            ),
            const SizedBox(width: 9),
            Container(height: 45, width: 1, color: const Color(0xFFE5CFCB)),
            const SizedBox(width: 9),
            Expanded(
              child: _InfoCard(
                icon: Icons.straighten_rounded,
                label: measureTitle,
                value: _dimensionLabel(piece),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE5CFCB)),
      ],
    );
  }

  Widget _buildActions(JewelryPiece piece) {
    // Esta pieza ya tiene 3D, pero aún no dispone de medidas físicas para AR.
    if (piece.id == 'collar-circonita-foto-01' &&
        (piece.dimensionesMm.longitud ?? 0) <= 0) {
      return Container(
        width: double.infinity,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE8DCDA),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Text(
          'AR pendiente de calibración',
          style: TextStyle(fontSize: 13, color: _espresso),
        ),
      );
    }
    if (piece.modeloGlb.isEmpty) {
      return Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: const Color(0xFFE8DCDA),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.center_focus_strong, size: 20, color: _espresso),
            SizedBox(width: 10),
            Text(
              'Modelo AR todavía no disponible',
              style: TextStyle(fontSize: 13, color: _espresso),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => context.push('/try-on/${piece.id}/prepare'),
        icon: const Icon(Icons.center_focus_strong, size: 20),
        label: const Text('Probar con AR', style: TextStyle(fontSize: 15)),
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  String _categoryLabel(JewelryCategory category) {
    return switch (category) {
      JewelryCategory.bracelet => 'Pulseras',
      JewelryCategory.earring => 'Aretes',
      JewelryCategory.necklace => 'Collares',
    };
  }

  String _dimensionLabel(JewelryPiece piece) {
    if (piece.id == 'collar-circonita-foto-01' &&
        (piece.dimensionesMm.longitud ?? 0) <= 0) {
      return 'Por confirmar';
    }
    if (piece.modeloGlb.isEmpty) {
      return 'Por confirmar';
    }
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

  const _ViewerButton({required this.icon, required this.onTap});

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
          child: Icon(icon, color: const Color(0xFF9D7747), size: 22),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  // Texto informativo. Intencionalmente NO usa InkWell, GestureDetector,
  // ElevatedButton, Card ni superficies que parezcan pulsables.
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFFA35F70), size: 21),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF9B7976),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF432B31),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
