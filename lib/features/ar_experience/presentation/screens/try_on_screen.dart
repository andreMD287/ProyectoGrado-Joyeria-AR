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
import '../../../../core/math/geometry.dart';
import '../../../tracking/domain/entities/anchor_pose.dart';
import '../../../tracking/domain/entities/landmark.dart';
import '../../../tracking/domain/strategies/bracelet_strategy.dart';
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
  static const _espresso = Color(0xFF3A2419);
  static const _muted = Color(0xFF8B7768);

  bool _started = false;

  /// Overlay de diagnostico de landmarks. Se activa desde la propia
  /// pantalla para poder verificar el tracking en dispositivo sin
  /// recompilar ni depender del cable.
  bool _debugOverlay = false;

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

    final landmarks = switch (state) {
      TryOnActive(:final landmarks) => landmarks,
      _ => const <Landmark>[],
    };

    final fps = switch (state) {
      TryOnActive(:final fps) => fps,
      _ => 0.0,
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
                    landmarks: landmarks,
                    fps: fps,
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
    required List<Landmark> landmarks,
    required double fps,
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
                    landmarks: landmarks,
                    fps: fps,
                    showDebug: _debugOverlay,
                  )
                : const _CameraLoadingView(),
          ),

          Positioned(
            right: 12,
            top: 12,
            child: _DebugToggle(
              enabled: _debugOverlay,
              onPressed: () => setState(
                () => _debugOverlay = !_debugOverlay,
              ),
            ),
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

/// Boton discreto para activar el overlay de diagnostico de landmarks.
class _DebugToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _DebugToggle({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? const Color(0xFF35E07A).withValues(alpha: 0.9)
          : Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            Icons.my_location_rounded,
            size: 19,
            color: enabled ? const Color(0xFF11331F) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CameraOverlay extends ConsumerWidget {
  final JewelryPiece piece;
  final AnchorPose? anchor;
  final List<Landmark> landmarks;
  final double fps;
  final bool showDebug;

  const _CameraOverlay({
    required this.piece,
    required this.anchor,
    required this.landmarks,
    required this.fps,
    required this.showDebug,
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
            // El preview llega en horizontal y se dibuja rotado a vertical, el
            // mismo marco en el que vienen normalizados los landmarks: por eso
            // se intercambian ancho y alto.
            final previewSize = camController.value.previewSize;
            final imageWidth =
                previewSize?.height ?? constraints.maxWidth;
            final imageHeight =
                previewSize?.width ?? constraints.maxHeight;

            // Una sola transformacion compartida por la vista previa y el
            // overlay, para que joya y camara no se desalineen en los bordes.
            final fit = coverFit(
              imageWidth: imageWidth,
              imageHeight: imageHeight,
              areaWidth: constraints.maxWidth,
              areaHeight: constraints.maxHeight,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: imageWidth,
                    height: imageHeight,
                    child: CameraPreview(
                      camController,
                    ),
                  ),
                ),

                if (!showDebug) const _CameraGuide(),

                if (anchor != null)
                  _ModelOverlay(
                    piece: piece,
                    anchor: anchor!,
                    fit: fit,
                  ),

                if (showDebug)
                  _LandmarkDebugLayer(
                    landmarks: landmarks,
                    anchor: anchor,
                    fit: fit,
                    fps: fps,
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
  final PreviewFit fit;

  const _ModelOverlay({
    required this.piece,
    required this.anchor,
    required this.fit,
  });

  /// Tamano en pantalla cuando la estrategia todavia no estima escala
  /// (aretes y collares).
  double get _fallbackSize => switch (piece.categoria) {
        JewelryCategory.earring => 32,
        JewelryCategory.necklace => 64,
        JewelryCategory.bracelet => 72,
      };

  /// Tamano de la pieza como multiplo de la medida anatomica que reporta la
  /// estrategia. Para pulseras, multiplos del ancho de la palma: una pulsera
  /// es algo mas estrecha que la palma pero se ve mas ancha por el grosor.
  /// Constante a calibrar en dispositivo.
  double get _scaleFactor => switch (piece.categoria) {
        JewelryCategory.bracelet => 1.15,
        _ => 1.0,
      };

  /// Rotacion extra sobre el angulo que reporta la estrategia.
  ///
  /// `BraceletStrategy` entrega el angulo del **eje del antebrazo**, y una
  /// pulsera se lleva perpendicular a el, de ahi el cuarto de vuelta. Si en
  /// dispositivo la pieza sale girada 90 grados, este es el valor a tocar.
  double get _rollOffset => switch (piece.categoria) {
        JewelryCategory.bracelet => math.pi / 2,
        _ => 0,
      };

  /// Limites de seguridad: una deteccion mala no puede llenar la pantalla de
  /// joya ni encogerla hasta hacerla invisible.
  static const double _minSize = 24;
  static const double _maxSize = 320;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsset = ref.watch(
      resolvedModelAssetProvider(
        piece.modeloGlb,
      ),
    );

    final scale = anchor.scale;
    final size = scale == null
        ? _fallbackSize
        : (fit.lengthOf(scale) * _scaleFactor).clamp(_minSize, _maxSize);

    // El punto de anclaje se convierte con la misma transformacion `cover` que
    // usa la vista previa; multiplicar por el tamano del area desplazaba la
    // joya hacia los bordes del eje recortado.
    final centerX = fit.xOf(anchor.position.x);
    final centerY = fit.yOf(anchor.position.y);

    return Stack(
      children: [
        Positioned(
          left: centerX - size / 2,
          top: centerY - size / 2,
          width: size,
          height: size,
          child: modelAsset.when(
            loading: () =>
                const SizedBox.shrink(),
            error: (_, _) =>
                const SizedBox.shrink(),
            data: (src) => IgnorePointer(
              child: Transform.rotate(
                angle: anchor.rollRadians + _rollOffset,
                child: ModelViewer(
                  // El tamano NO entra en la key: con escala dinamica cambia
                  // en cada frame y recrearia el WebView del visor entero.
                  key: ValueKey(
                    'model-${piece.categoria.id}-${piece.id}',
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
        ),
      ],
    );
  }
}

/// Overlay de diagnostico: dibuja los 21 landmarks de la mano, el esqueleto,
/// el punto de anclaje calculado y la frecuencia de deteccion.
///
/// Existe para verificar en dispositivo el espacio de coordenadas que devuelve
/// el detector, que es lo unico que no se puede comprobar en el escritorio: si
/// los puntos salen espejados, con los ejes cambiados o desplazados respecto a
/// la mano real, se ve de inmediato en vez de deducirlo de donde queda la joya.
class _LandmarkDebugLayer extends StatelessWidget {
  final List<Landmark> landmarks;
  final AnchorPose? anchor;
  final PreviewFit fit;
  final double fps;

  const _LandmarkDebugLayer({
    required this.landmarks,
    required this.anchor,
    required this.fit,
    required this.fps,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _LandmarkPainter(
              landmarks: landmarks,
              anchor: anchor,
              fit: fit,
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                child: Text(
                  _debugText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _debugText() {
    final buffer = StringBuffer()
      ..writeln('pts ${landmarks.length}   ${fps.toStringAsFixed(1)} Hz')
      ..writeln(
        'img ${fit.imageWidth.toStringAsFixed(0)}'
        'x${fit.imageHeight.toStringAsFixed(0)}'
        '   x${fit.scale.toStringAsFixed(2)}',
      );
    final a = anchor;
    if (a == null) {
      buffer.write('sin ancla');
    } else {
      buffer
        ..writeln(
          'ancla ${a.position.x.toStringAsFixed(3)}, '
          '${a.position.y.toStringAsFixed(3)}',
        )
        ..write(
          'roll ${(a.rollRadians * 180 / math.pi).toStringAsFixed(0)}deg   '
          'esc ${a.scale?.toStringAsFixed(3) ?? "-"}',
        );
    }
    return buffer.toString();
  }
}

class _LandmarkPainter extends CustomPainter {
  final List<Landmark> landmarks;
  final AnchorPose? anchor;
  final PreviewFit fit;

  const _LandmarkPainter({
    required this.landmarks,
    required this.anchor,
    required this.fit,
  });

  /// Conexiones del esqueleto de MediaPipe Hands (palma y cinco dedos).
  static const List<List<int>> _bones = [
    [0, 1], [1, 2], [2, 3], [3, 4], // pulgar
    [0, 5], [5, 6], [6, 7], [7, 8], // indice
    [5, 9], [9, 10], [10, 11], [11, 12], // medio
    [9, 13], [13, 14], [14, 15], [15, 16], // anular
    [13, 17], [17, 18], [18, 19], [19, 20], // menique
    [0, 17], // borde de la palma
  ];

  Offset _project(Landmark lm) => Offset(fit.xOf(lm.x), fit.yOf(lm.y));

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isNotEmpty) {
      final bonePaint = Paint()
        ..color = const Color(0xFF35E07A)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      for (final bone in _bones) {
        if (bone[0] >= landmarks.length || bone[1] >= landmarks.length) {
          continue;
        }
        canvas.drawLine(
          _project(landmarks[bone[0]]),
          _project(landmarks[bone[1]]),
          bonePaint,
        );
      }

      final pointPaint = Paint()..color = const Color(0xFFFFFFFF);
      final keyPaint = Paint()..color = const Color(0xFF3FA9FF);

      for (var i = 0; i < landmarks.length; i++) {
        // Se destacan los tres puntos de los que sale el anclaje.
        final isKey = i == BraceletStrategy.wristLandmark ||
            i == BraceletStrategy.indexMcpLandmark ||
            i == BraceletStrategy.pinkyMcpLandmark;
        canvas.drawCircle(
          _project(landmarks[i]),
          isKey ? 5 : 3,
          isKey ? keyPaint : pointPaint,
        );
      }
    }

    final a = anchor;
    if (a == null) return;

    final center = Offset(fit.xOf(a.position.x), fit.yOf(a.position.y));
    final crossPaint = Paint()
      ..color = const Color(0xFFFF4D4D)
      ..strokeWidth = 2;
    const arm = 12.0;
    canvas.drawLine(
      center - const Offset(arm, 0),
      center + const Offset(arm, 0),
      crossPaint,
    );
    canvas.drawLine(
      center - const Offset(0, arm),
      center + const Offset(0, arm),
      crossPaint,
    );

    // Segmento en la direccion del eje reportado, para ver si el roll apunta a
    // donde debe antes de fiarse de como sale girada la joya.
    final scale = a.scale;
    if (scale == null) return;
    final length = fit.lengthOf(scale);
    canvas.drawLine(
      center,
      center +
          Offset(
            math.cos(a.rollRadians) * length,
            math.sin(a.rollRadians) * length,
          ),
      Paint()
        ..color = const Color(0xFFFFD166)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _LandmarkPainter oldDelegate) =>
      oldDelegate.landmarks != landmarks || oldDelegate.anchor != anchor;
}
