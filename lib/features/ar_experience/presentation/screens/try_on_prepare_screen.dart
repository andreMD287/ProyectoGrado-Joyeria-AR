import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../catalog/domain/entities/jewelry_piece.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';

class TryOnPrepareScreen extends ConsumerWidget {
  final String pieceId;

  const TryOnPrepareScreen({
    super.key,
    required this.pieceId,
  });

  static const _background = Color(0xFFFBF7F2);
  static const _espresso = Color(0xFF3A2419);
  static const _gold = Color(0xFFB4895B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              'No se pudo cargar la joya.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _espresso,
              ),
            ),
          ),
        ),
        data: (pieces) {
          final piece = _findPiece(pieces);

          if (piece == null) {
            return const Center(
              child: Text(
                'No encontramos esta joya.',
                style: TextStyle(
                  color: _espresso,
                ),
              ),
            );
          }

          return _PrepareContent(piece: piece);
        },
      ),
    );
  }

  JewelryPiece? _findPiece(List<JewelryPiece> pieces) {
    for (final piece in pieces) {
      if (piece.id == pieceId) {
        return piece;
      }
    }

    return null;
  }
}

class _PrepareContent extends ConsumerWidget {
  final JewelryPiece piece;

  const _PrepareContent({
    required this.piece,
  });

  static const _espresso = Color(0xFF3A2419);
  static const _muted = Color(0xFF8B7768);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instructions = _instructionsFor(piece.categoria);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _buildHeader(context),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                24,
                34,
                24,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Prepárate para\nla prueba virtual',
                    style: TextStyle(
                      color: _espresso,
                      fontFamily: 'Georgia',
                      fontSize: 42,
                      height: 1.05,
                      letterSpacing: -1,
                    ),
                  ),

                  const SizedBox(height: 17),

                  const Text(
                    'Usaremos la cámara para posicionar la joya sobre ti.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 30),

                  _JewelryPreviewCard(
                    piece: piece,
                  ),

                  const SizedBox(height: 22),

                  for (final instruction in instructions) ...[
                    _InstructionCard(
                      icon: instruction.icon,
                      text: instruction.text,
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (piece.categoria == JewelryCategory.earring) ...[
                    const _EarSideSelector(),
                    const SizedBox(height: 14),
                  ],

                  const SizedBox(height: 4),

                  const _PrivacyCard(),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: FilledButton(
                      onPressed: () async {
                        final granted = await ref
                            .read(permissionServiceProvider)
                            .ensureCamera();

                        if (!context.mounted) return;

                        if (granted) {
                          context.push('/try-on/${piece.id}');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Necesitamos acceso a la cámara para realizar la prueba virtual.',
                              ),
                            ),
                          );
                        }
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
                            color: Color(0xFFD4AE68),
                            size: 27,
                          ),
                          SizedBox(width: 13),
                          Text(
                            'Permitir cámara',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
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

Widget _buildHeader(BuildContext context) {
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
                onTap: () => context.pop(),
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

          // Espacio invisible para que el título quede
          // perfectamente centrado respecto a la flecha.
          const SizedBox(
            width: 46,
            height: 46,
          ),
        ],
      ),
    ),
  );
}

  List<_InstructionData> _instructionsFor(
    JewelryCategory category,
  ) {
    switch (category) {
      case JewelryCategory.bracelet:
        return const [
          _InstructionData(
            icon: Icons.lightbulb_outline_rounded,
            text: 'Busca un lugar con buena iluminación.',
          ),
          _InstructionData(
            icon: Icons.visibility_outlined,
            text: 'Mantén tu muñeca visible.',
          ),
          _InstructionData(
            icon: Icons.motion_photos_on_outlined,
            text:
                'Muévete lentamente para obtener una mejor visualización.',
          ),
        ];

      case JewelryCategory.earring:
        return const [
          _InstructionData(
            icon: Icons.lightbulb_outline_rounded,
            text: 'Busca un lugar con buena iluminación.',
          ),
          _InstructionData(
            icon: Icons.face_outlined,
            text: 'Mantén tu rostro completamente visible.',
          ),
          _InstructionData(
            icon: Icons.motion_photos_on_outlined,
            text:
                'Mira de frente y muévete lentamente para mejorar la detección.',
          ),
        ];

      case JewelryCategory.necklace:
        return const [
          _InstructionData(
            icon: Icons.lightbulb_outline_rounded,
            text: 'Busca un lugar con buena iluminación.',
          ),
          _InstructionData(
            icon: Icons.accessibility_new_rounded,
            text: 'Mantén cuello y hombros visibles.',
          ),
          _InstructionData(
            icon: Icons.motion_photos_on_outlined,
            text:
                'Mantente de frente y evita movimientos bruscos.',
          ),
        ];
    }
  }
}

class _JewelryPreviewCard extends StatelessWidget {
  final JewelryPiece piece;

  const _JewelryPreviewCard({
    required this.piece,
  });

  static const _espresso = Color(0xFF3A2419);
  static const _gold = Color(0xFFB4895B);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE2CDAF),
        ),
        boxShadow: [
          BoxShadow(
            color: _espresso.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF4E2D5),
                  Color(0xFFE7C7B4),
                ],
              ),
            ),
            child: Icon(
              _categoryIcon(piece.categoria),
              size: 44,
              color: _gold,
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  piece.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _espresso,
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    height: 1.1,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  _categoryLabel(piece.categoria),
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(JewelryCategory category) {
    return switch (category) {
      JewelryCategory.bracelet => Icons.watch_outlined,
      JewelryCategory.earring => Icons.diamond_outlined,
      JewelryCategory.necklace => Icons.favorite_border_rounded,
    };
  }

  String _categoryLabel(JewelryCategory category) {
    return switch (category) {
      JewelryCategory.bracelet => 'Pulseras',
      JewelryCategory.earring => 'Aretes',
      JewelryCategory.necklace => 'Collares',
    };
  }
}

class _InstructionCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InstructionCard({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      // CORREGIDO:
      constraints: const BoxConstraints(
        minHeight: 92,
      ),

      padding: const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE2CDAF),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A2419)
                .withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E9),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE8D6B8),
              ),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFBE8F37),
              size: 27,
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF3E352E),
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EDE2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE2CDAF),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            color: Color(0xFFBE8F37),
            size: 40,
          ),

          SizedBox(width: 18),

          Expanded(
            child: Text(
              'Esta app requiere acceso a tu cámara para la experiencia '
              'de realidad aumentada. Tus datos no son almacenados.',
              style: TextStyle(
                color: Color(0xFF8B7768),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Deja elegir en qué oreja anclar el arete antes de empezar: la estrategia
/// por defecto bloquea el lado más visible en el primer frame, pero para
/// probar/calibrar un lado específico conviene poder forzarlo.
class _EarSideSelector extends ConsumerWidget {
  const _EarSideSelector();

  static const _espresso = Color(0xFF3A2419);
  static const _muted = Color(0xFF8B7768);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(earringPreferredSideProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2CDAF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿En qué oreja quieres probarlo?',
            style: TextStyle(
              color: _espresso,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Automático deja que la app elija la oreja más visible.',
            style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SideOption(
                label: 'Automático',
                selected: selected == null,
                onTap: () =>
                    ref.read(earringPreferredSideProvider.notifier).state =
                        null,
              ),
              const SizedBox(width: 10),
              _SideOption(
                label: 'Izquierda',
                selected: selected == 0,
                onTap: () =>
                    ref.read(earringPreferredSideProvider.notifier).state = 0,
              ),
              const SizedBox(width: 10),
              _SideOption(
                label: 'Derecha',
                selected: selected == 1,
                onTap: () =>
                    ref.read(earringPreferredSideProvider.notifier).state = 1,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _espresso = Color(0xFF3A2419);
  static const _gold = Color(0xFFB4895B);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? const Color(0xFFFFF7E9) : const Color(0xFFF4ECE2),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _gold : Colors.transparent,
                width: 1.4,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? _espresso : const Color(0xFF8B7768),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InstructionData {
  final IconData icon;
  final String text;

  const _InstructionData({
    required this.icon,
    required this.text,
  });
}