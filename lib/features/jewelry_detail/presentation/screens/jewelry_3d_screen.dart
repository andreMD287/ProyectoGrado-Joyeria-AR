import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../app/theme.dart';
import '../../../../core/assets/resolved_model_asset.dart';
import '../../../../core/widgets/current_route_only.dart';
import '../../../catalog/domain/entities/jewelry_piece.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';

/// Visor 3D ampliado: la joya es la protagonista.
/// Fondo negro cálido para el modelo, controles con la paleta de Jewelry AR.
class Jewelry3dScreen extends ConsumerStatefulWidget {
  final String pieceId;

  const Jewelry3dScreen({super.key, required this.pieceId});

  @override
  ConsumerState<Jewelry3dScreen> createState() => _Jewelry3dScreenState();
}

class _Jewelry3dScreenState extends ConsumerState<Jewelry3dScreen> {
  static const Color _viewerBackground = Color(0xFF0E0C09);
  static const Color _ivory = JoyeriaPalette.background;
  int _viewerVersion = 0;

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

    // Texto e iconos blancos en la barra de estado sobre el fondo oscuro.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _viewerBackground,
        body: catalog.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: JoyeriaPalette.gold),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _ivory),
              ),
            ),
          ),
          data: (pieces) {
            final piece = _findPiece(pieces);
            if (piece == null) {
              return const Center(
                child: Text(
                  'Joya no encontrada.',
                  style: TextStyle(color: _ivory),
                ),
              );
            }

            return Stack(
              children: [
                // No se altera el motor, las dimensiones ni los modelos GLB.
                Positioned.fill(
                  child: ref
                      .watch(resolvedModelAssetProvider(piece.modeloGlb))
                      .when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: JoyeriaPalette.gold,
                          ),
                        ),
                        error: (error, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No se pudo cargar el modelo 3D.\n$error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _ivory),
                            ),
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
                            backgroundColor: _viewerBackground,
                          ),
                        ),
                      ),
                ),

                // Solo se superponen controles en los extremos de la pantalla:
                // el centro permanece libre para girar y ampliar la joya.
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ViewerControlButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              tooltip: 'Volver al detalle',
                              onTap: () => context.pop(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                children: [
                                  const SizedBox(height: 3),
                                  const Text(
                                    'VISTA 3D',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: JoyeriaPalette.mutedRose,
                                      letterSpacing: 3,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    piece.nombre,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Georgia',
                                      color: _ivory,
                                      fontSize: 22,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ViewerControlButton(
                              icon: Icons.refresh_rounded,
                              tooltip: 'Restablecer vista',
                              onTap: () {
                                setState(() {
                                  _viewerVersion++;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: JoyeriaPalette.gold.withValues(
                                  alpha: 0.11,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: JoyeriaPalette.gold.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 8,
                                ),
                                child: Text(
                                  '360°',
                                  style: TextStyle(
                                    color: Color(0xFFD5B17C),
                                    fontSize: 13,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF37272D,
                              ).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: JoyeriaPalette.rose.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_outlined,
                                  size: 16,
                                  color: JoyeriaPalette.mutedRose,
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Arrastra para girar · Pellizca para acercar',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: JoyeriaPalette.blush,
                                      fontSize: 12,
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
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ViewerControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ViewerControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF38262E),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: JoyeriaPalette.blush, size: 22),
          ),
        ),
      ),
    );
  }
}
