import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/theme.dart';
import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../catalog/domain/entities/jewelry_piece.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';

/// Preparación corta: cuatro consejos según la categoría y acción fija abajo.
/// La autorización de cámara solo se solicita al tocar el botón inferior.
class TryOnPrepareScreen extends ConsumerStatefulWidget {
  final String pieceId;

  const TryOnPrepareScreen({super.key, required this.pieceId});

  @override
  ConsumerState<TryOnPrepareScreen> createState() => _TryOnPrepareScreenState();
}

class _TryOnPrepareScreenState extends ConsumerState<TryOnPrepareScreen> {
  bool _openingCamera = false;
  String _selectedEar = 'automatic';

  JewelryPiece? _findPiece(List<JewelryPiece> pieces) {
    for (final piece in pieces) {
      if (piece.id == widget.pieceId) {
        return piece;
      }
    }
    return null;
  }

  List<String> _tips(JewelryCategory category) => switch (category) {
    JewelryCategory.bracelet => const [
      'Sostén el celular a unos 40 cm de tu mano, con la mano y parte del antebrazo dentro del cuadro.',
      'Pon el brazo frente a un fondo liso que contraste con tu piel (una pared o tela de otro color) y deja la muñeca sin manga.',
      'Busca buena luz, sin sombras fuertes sobre la mano.',
      'Espera 2 o 3 segundos a que detecte tu muñeca y mueve el brazo despacio.',
    ],
    JewelryCategory.earring => const [
      'Ponte frente a la luz, que te ilumine la cara sin dejar sombras en las orejas.',
      'Recoge el cabello detrás de la oreja y mantén tu rostro completo dentro del cuadro.',
      'Sostén el celular a la altura de los ojos, a un brazo de distancia.',
      'Mira de frente unos segundos y luego gira la cabeza despacio para ver el arete de lado.',
    ],
    JewelryCategory.necklace => const [
      'Busca buena luz de frente, sin sombras sobre el cuello.',
      'Usa una prenda que deje el cuello descubierto (evita cuello alto) y echa el cabello hacia atrás.',
      'Aleja el celular hasta que se vean tu cara, tu cuello y tus hombros completos.',
      'Quédate quieto 2 o 3 segundos para que mida tu cuello y luego muévete despacio.',
    ],
  };

  String _categoryLabel(JewelryCategory category) => switch (category) {
    JewelryCategory.bracelet => 'PULSERAS',
    JewelryCategory.earring => 'ARETES',
    JewelryCategory.necklace => 'COLLARES',
  };

  Future<void> _startCamera(JewelryPiece piece) async {
    if (_openingCamera) {
      return;
    }
    setState(() => _openingCamera = true);
    try {
      var permission = await Permission.camera.status;
      if (!permission.isGranted) {
        permission = await Permission.camera.request();
      }
      if (!mounted) {
        return;
      }
      if (permission.isGranted) {
        final earQuery = _selectedEar == 'automatic'
            ? ''
            : '?ear=$_selectedEar';
        context.push('/try-on/${piece.id}$earQuery');
      } else {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Necesitamos tu cámara'),
            content: const Text(
              'Para visualizar la joya sobre ti, permite el acceso a la cámara. '
              'Puedes habilitarlo en los ajustes de tu iPhone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Ahora no'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  openAppSettings();
                },
                child: const Text('Abrir ajustes'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la cámara: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _openingCamera = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogControllerProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: JoyeriaPalette.background,
        body: SafeArea(
          child: catalog.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: JoyeriaPalette.rose),
            ),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudo cargar la joya. $error'),
              ),
            ),
            data: (pieces) {
              final piece = _findPiece(pieces);
              if (piece == null) {
                return const Center(child: Text('No encontramos esta joya.'));
              }
              return Column(
                children: [
                  _header(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                      child: _content(piece),
                    ),
                  ),
                  _bottomAction(piece),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Regresar',
            onPressed: () => context.pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: JoyeriaPalette.espresso,
              size: 21,
            ),
          ),
          const Expanded(
            child: Text(
              'Prueba virtual',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 24,
                color: JoyeriaPalette.espresso,
              ),
            ),
          ),
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _content(JewelryPiece piece) {
    final tips = _tips(piece.categoria);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ANTES DE COMENZAR',
          style: TextStyle(
            color: JoyeriaPalette.rose,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Prepara tu prueba AR',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 30,
            height: 1.13,
            color: JoyeriaPalette.espresso,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sigue estos consejos para una mejor detección.',
          style: TextStyle(fontSize: 14.5, color: JoyeriaPalette.muted),
        ),
        const SizedBox(height: 22),
        _pieceSummary(piece),
        const SizedBox(height: 22),
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              color: JoyeriaPalette.gold,
              size: 19,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Consejos para tu prueba',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: JoyeriaPalette.espresso,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              '4 PASOS',
              style: TextStyle(
                color: JoyeriaPalette.mutedRose.withValues(alpha: 0.95),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: JoyeriaPalette.surface,
            border: Border.all(color: JoyeriaPalette.stroke),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              for (var i = 0; i < tips.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 33,
                        height: 33,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: JoyeriaPalette.blush,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '${i + 1}'.padLeft(2, '0'),
                          style: const TextStyle(
                            color: JoyeriaPalette.rose,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          tips[i],
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: JoyeriaPalette.espresso,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < tips.length - 1)
                  const Divider(
                    height: 1,
                    indent: 52,
                    endIndent: 13,
                    color: JoyeriaPalette.stroke,
                  ),
              ],
            ],
          ),
        ),
        if (piece.categoria == JewelryCategory.earring) ...[
          const SizedBox(height: 12),
          _earOptions(piece),
        ],
      ],
    );
  }

  Widget _pieceSummary(JewelryPiece piece) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: JoyeriaPalette.blush.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 78,
              width: 78,
              child: piece.foto.isNotEmpty
                  ? Image.asset(
                      piece.foto,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.diamond_outlined,
                        color: JoyeriaPalette.rose,
                      ),
                    )
                  : const Icon(
                      Icons.diamond_outlined,
                      color: JoyeriaPalette.rose,
                    ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _categoryLabel(piece.categoria),
                  style: const TextStyle(
                    color: JoyeriaPalette.rose,
                    letterSpacing: 1.5,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  piece.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: JoyeriaPalette.espresso,
                    fontFamily: 'Georgia',
                    fontSize: 19,
                    height: 1.08,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _earLabel(String option) => switch (option) {
    'left' => 'izquierda',
    'right' => 'derecha',
    _ => 'automática',
  };

  Future<void> _chooseEar() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: JoyeriaPalette.surface,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 5, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Qué oreja prefieres?',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 25,
                color: JoyeriaPalette.espresso,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Selecciona el lado sin salir de esta pantalla.',
              style: TextStyle(color: JoyeriaPalette.muted, fontSize: 14),
            ),
            const SizedBox(height: 14),
            for (final option in const ['automatic', 'left', 'right'])
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                title: Text(
                  option == 'automatic'
                      ? 'Detección automática'
                      : 'Oreja ${_earLabel(option)}',
                  style: const TextStyle(
                    color: JoyeriaPalette.espresso,
                    fontSize: 16,
                  ),
                ),
                subtitle: option == 'automatic'
                    ? const Text(
                        'El sistema elige la oreja visible.',
                        style: TextStyle(color: JoyeriaPalette.muted),
                      )
                    : null,
                leading: Icon(
                  option == 'automatic'
                      ? Icons.auto_awesome
                      : Icons.hearing_outlined,
                  color: JoyeriaPalette.rose,
                ),
                trailing: _selectedEar == option
                    ? const Icon(Icons.check_circle, color: JoyeriaPalette.rose)
                    : const Icon(
                        Icons.circle_outlined,
                        color: JoyeriaPalette.stroke,
                      ),
                onTap: () => Navigator.pop(sheetContext, option),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) {
      return;
    }
    setState(() => _selectedEar = choice);
  }

  Widget _earOptions(JewelryPiece piece) {
    assert(piece.categoria == JewelryCategory.earring);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: JoyeriaPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JoyeriaPalette.stroke),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.face_retouching_natural,
            color: JoyeriaPalette.rose,
            size: 25,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selección de oreja',
                  style: TextStyle(
                    color: JoyeriaPalette.espresso,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Oreja ${_earLabel(_selectedEar)}',
                  style: const TextStyle(
                    color: JoyeriaPalette.muted,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _chooseEar,
            child: const Text(
              'Cambiar',
              style: TextStyle(color: JoyeriaPalette.rose, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomAction(JewelryPiece piece) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      decoration: BoxDecoration(
        color: JoyeriaPalette.background,
        border: Border(
          top: BorderSide(color: JoyeriaPalette.stroke.withValues(alpha: 0.85)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              onPressed: _openingCamera ? null : () => _startCamera(piece),
              style: FilledButton.styleFrom(
                backgroundColor: JoyeriaPalette.rose,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              icon: _openingCamera
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.camera_alt_outlined, size: 20),
              label: Text(
                _openingCamera
                    ? 'Preparando cámara...'
                    : 'Activar cámara y probar',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'El permiso se solicitará al continuar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: JoyeriaPalette.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
