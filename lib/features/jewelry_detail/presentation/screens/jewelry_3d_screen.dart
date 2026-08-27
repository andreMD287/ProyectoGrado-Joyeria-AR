import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../catalog/domain/entities/jewelry_piece.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';

class Jewelry3dScreen extends ConsumerStatefulWidget {
  final String pieceId;

  const Jewelry3dScreen({
    super.key,
    required this.pieceId,
  });

  @override
  ConsumerState<Jewelry3dScreen> createState() =>
      _Jewelry3dScreenState();
}

class _Jewelry3dScreenState
    extends ConsumerState<Jewelry3dScreen> {
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

    return Scaffold(
      backgroundColor: const Color(0xFF0E0C09),
      body: catalog.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD2AE6C),
          ),
        ),
        error: (error, _) => Center(
          child: Text(
            '$error',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (pieces) {
          final piece = _findPiece(pieces);

          if (piece == null) {
            return const Center(
              child: Text(
                'Joya no encontrada.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: ModelViewer(
                  key: ValueKey(_viewerVersion),

                  // TEMPORAL hasta agregar los GLB definitivos.
                  src: 'assets/models/_placeholder.glb',

                  alt: piece.nombre,

                  ar: false,

                  autoRotate: false,

                  cameraControls: true,

                  disableZoom: false,

                  backgroundColor: const Color(0xFF0E0C09),
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    20,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _DarkControlButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => context.pop(),
                          ),

                          Expanded(
                            child: Text(
                              piece.nombre,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Georgia',
                                fontSize: 24,
                              ),
                            ),
                          ),

                          _DarkControlButton(
                            icon: Icons.refresh_rounded,
                            onTap: () {
                              setState(() {
                                _viewerVersion++;
                              });
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFD1AE69)
                                    .withValues(alpha: 0.18),
                            borderRadius:
                                BorderRadius.circular(17),
                            border: Border.all(
                              color:
                                  const Color(0xFFD1AE69)
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Text(
                            '360°',
                            style: TextStyle(
                              color: Color(0xFFD8B66F),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      SizedBox(
                        width: double.infinity,
                        height: 62,
                        child: FilledButton(
                          onPressed: () {
                            context.push(
                              '/try-on/${piece.id}',
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFD1AE69),
                            foregroundColor:
                                const Color(0xFF17130E),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_camera_outlined,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Probar virtualmente',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
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
    );
  }
}

class _DarkControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DarkControlButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF24201B),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}