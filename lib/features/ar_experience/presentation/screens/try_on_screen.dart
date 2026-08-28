import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../../core/assets/resolved_model_asset.dart';
import '../../../../core/di/providers.dart';
import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../catalog/domain/entities/jewelry_piece.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';
import '../../../tracking/domain/entities/anchor_pose.dart';
import '../controllers/try_on_controller.dart';

class TryOnScreen extends ConsumerWidget {
  final String pieceId;

  const TryOnScreen({
    super.key,
    required this.pieceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F2),
      body: catalog.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFB4895B),
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
          JewelryPiece? piece;

          for (final currentPiece in pieces) {
            if (currentPiece.id == pieceId) {
              piece = currentPiece;
              break;
            }
          }

          if (piece == null) {
            return const Center(
              child: Text('Pieza no encontrada.'),
            );
          }

          return _TryOnBody(piece: piece);
        },
      ),
    );
  }
}

class _TryOnBody extends ConsumerStatefulWidget {
  final JewelryPiece piece;

  const _TryOnBody({
    required this.piece,
  });

  @override
  ConsumerState<_TryOnBody> createState() => _TryOnBodyState();
}

class _TryOnBodyState extends ConsumerState<_TryOnBody> {
  static const _background = Color(0xFFFBF7F2);
  static const _espresso = Color(0xFF3A2419);
  static const _gold = Color(0xFFB4895B);
  static const _muted = Color(0xFF8B7768);

  bool _started = false;

  JewelryPiece get piece => widget.piece;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startExperience();
    });
  }

  Future<void> _startExperience() async {
    if (_started || !mounted) return;

    _started = true;

    await ref
        .read(tryOnControllerProvider.notifier)
        .start(piece.categoria);
  }

  Future<void> _finishExperience() async {
    await ref.read(tryOnControllerProvider.notifier).stop();

    if (!mounted) return;

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tryOnControllerProvider);

    final active =
        state is TryOnActive ||
        state is TryOnRequestingPermission;

    final anchor = switch (state) {
      TryOnActive(:final anchor) => anchor,
      _ => null,
    };

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _buildHeader(),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                22,
                18,
                22,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    piece.nombre,
                    style: const TextStyle(
                      color: _espresso,
                      fontFamily: 'Georgia',
                      fontSize: 36,
                      height: 1.05,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    piece.descripcion ??
                        'Visualiza esta joya sobre ti en tiempo real.',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildCameraCard(
                    active: active,
                    anchor: anchor,
                  ),

                  const SizedBox(height: 18),

                  _TrackingStatusCard(
                    state: state,
                    category: piece.categoria,
                  ),

                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: FilledButton(
                      onPressed: _finishExperience,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFAA7410),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.stop_rounded,
                            size: 22,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Detener',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildHeader() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
    child: SizedBox(
      height: 58,
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Material(
              color: const Color(0xFFF4ECE2),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _finishExperience,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _espresso,
                  size: 21,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Text(
              'Prueba virtual',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _espresso,
                fontFamily: 'Georgia',
                fontSize: 24,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

          const SizedBox(width: 12),

          SizedBox(
            width: 46,
            height: 46,
            child: Material(
              color: const Color(0xFFF4ECE2),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Mantén la zona de la joya visible y muévete lentamente.',
                      ),
                    ),
                  );
                },
                child: const Icon(
                  Icons.question_mark_rounded,
                  color: _espresso,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCameraCard({
    required bool active,
    required AnchorPose? anchor,
  }) {
    return Container(
      width: double.infinity,
      height: 505,
      decoration: BoxDecoration(
        color: const Color(0xFFF0E5D8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFD9B87B),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _espresso.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: active
                ? _CameraOverlay(
                    piece: piece,
                    anchor: anchor,
                  )
                : const _CameraLoadingView(),
          ),

          const Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: _ViewModeSelector(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewModeSelector extends StatelessWidget {
  const _ViewModeSelector();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 202,
      height: 66,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF6)
            .withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(33),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFB98217),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB98217)
                        .withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 29,
              ),
            ),
          ),

          Container(
            width: 1,
            height: 31,
            margin: const EdgeInsets.symmetric(
              horizontal: 7,
            ),
            color: const Color(0xFFE3D9CD),
          ),

          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'La prueba desde una foto se agregará en el siguiente paso.',
                      ),
                    ),
                  );
                },
                child: const SizedBox.expand(
                  child: Icon(
                    Icons.image_rounded,
                    color: Color(0xFFBDB5AA),
                    size: 27,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingStatusCard extends StatelessWidget {
  final TryOnState state;
  final JewelryCategory category;

  const _TrackingStatusCard({
    required this.state,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final anchorFound =
        state is TryOnActive &&
        (state as TryOnActive).anchor != null;

    final title = _titleForState(anchorFound);
    final subtitle = _subtitleForState(anchorFound);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 112,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: const Color(0xFFE9D9C6),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A2419)
                .withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFF7EEDF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              anchorFound
                  ? Icons.diamond_outlined
                  : Icons.center_focus_weak_rounded,
              color: const Color(0xFFB98217),
              size: 31,
            ),
          ),

          const SizedBox(width: 17),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF34281F),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF887466),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: anchorFound
                  ? const Color(0xFF73935E)
                  : const Color(0xFFB98217),
              shape: BoxShape.circle,
            ),
            child: Icon(
              anchorFound
                  ? Icons.check_rounded
                  : Icons.circle,
              color: Colors.white,
              size: anchorFound ? 19 : 9,
            ),
          ),
        ],
      ),
    );
  }

  String _titleForState(bool anchorFound) {
    if (state is TryOnPermissionDenied) {
      return 'Permiso de cámara requerido';
    }

    if (state is TryOnUnsupported) {
      return 'Prueba no disponible';
    }

    if (state is TryOnError) {
      return 'No pudimos iniciar la prueba';
    }

    if (anchorFound) {
      return 'Joya posicionada';
    }

    return switch (category) {
      JewelryCategory.earring => 'Detectando oreja...',
      JewelryCategory.bracelet => 'Detectando muñeca...',
      JewelryCategory.necklace => 'Detectando cuello...',
    };
  }

  String _subtitleForState(bool anchorFound) {
    if (state is TryOnPermissionDenied) {
      return 'Activa el acceso a la cámara para continuar.';
    }

    if (state is TryOnUnsupported) {
      return 'Este dispositivo no es compatible con esta experiencia.';
    }

    if (state is TryOnError) {
      return 'Intenta regresar e iniciar nuevamente la prueba.';
    }

    if (anchorFound) {
      return 'Muévete lentamente para observar la joya desde distintos ángulos.';
    }

    return switch (category) {
      JewelryCategory.earring =>
        'Coloca tu rostro en el centro y muévete lentamente.',
      JewelryCategory.bracelet =>
        'Mantén tu muñeca visible y muévela lentamente.',
      JewelryCategory.necklace =>
        'Mantén cuello y hombros visibles frente a la cámara.',
    };
  }
}

class _CameraLoadingView extends StatelessWidget {
  const _CameraLoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF4E9DC),
            Color(0xFFE9D8C5),
          ],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFB4895B),
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _CameraOverlay extends ConsumerWidget {
  final JewelryPiece piece;
  final AnchorPose? anchor;

  const _CameraOverlay({
    required this.piece,
    required this.anchor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraService =
        ref.watch(cameraServiceProvider);

    return ValueListenableBuilder<CameraController?>(
      valueListenable:
          cameraService.controllerNotifier,
      builder: (
        context,
        camController,
        _,
      ) {
        if (camController == null ||
            !camController.value.isInitialized) {
          return const _CameraLoadingView();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width:
                        camController.value.previewSize?.height ??
                            constraints.maxWidth,
                    height:
                        camController.value.previewSize?.width ??
                            constraints.maxHeight,
                    child: CameraPreview(
                      camController,
                    ),
                  ),
                ),

                const _CameraGuide(),

                if (anchor != null)
                  _ModelOverlay(
                    piece: piece,
                    anchor: anchor!,
                    areaSize: constraints.biggest,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CameraGuide extends StatelessWidget {
  const _CameraGuide();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 220,
          height: 220,
          child: CustomPaint(
            painter: _CameraGuidePainter(),
          ),
        ),
      ),
    );
  }
}

class _CameraGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const corner = 34.0;

    final path = Path();

    path.moveTo(0, corner);
    path.lineTo(0, 0);
    path.lineTo(corner, 0);

    path.moveTo(size.width - corner, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, corner);

    path.moveTo(0, size.height - corner);
    path.lineTo(0, size.height);
    path.lineTo(corner, size.height);

    path.moveTo(
      size.width - corner,
      size.height,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(
      size.width,
      size.height - corner,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}

class _ModelOverlay extends ConsumerWidget {
  final JewelryPiece piece;
  final AnchorPose anchor;
  final Size areaSize;

  const _ModelOverlay({
    required this.piece,
    required this.anchor,
    required this.areaSize,
  });

  double get _size => switch (piece.categoria) {
        JewelryCategory.earring => 32,
        JewelryCategory.necklace => 64,
        JewelryCategory.bracelet => 72,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsset = ref.watch(
      resolvedModelAssetProvider(
        piece.modeloGlb,
      ),
    );

    final size = _size;

    final maxLeft =
        math.max(0.0, areaSize.width - size);

    final maxTop =
        math.max(0.0, areaSize.height - size);

    final anchorX =
        anchor.position.x * areaSize.width;

    final anchorY =
        anchor.position.y * areaSize.height;

    final left =
        (anchorX - size / 2).clamp(
      0.0,
      maxLeft,
    );

    final top =
        (anchorY - size / 2).clamp(
      0.0,
      maxTop,
    );

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: size,
          height: size,
          child: modelAsset.when(
            loading: () =>
                const SizedBox.shrink(),
            error: (_, _) =>
                const SizedBox.shrink(),
            data: (src) => IgnorePointer(
              child: ModelViewer(
                key: ValueKey(
                  'model-${piece.categoria.id}-$size',
                ),
                src: src,
                backgroundColor:
                    Colors.transparent,
                cameraControls: false,
                disableZoom: true,
                disablePan: true,
                disableTap: true,
                autoRotate: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
