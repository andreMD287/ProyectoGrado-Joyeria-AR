import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../catalog/domain/entities/jewelry_category.dart';
import '../../../catalog/domain/entities/jewelry_piece.dart';
import '../../../catalog/presentation/controllers/catalog_controller.dart';
import '../../../../core/permissions/permission_service.dart';

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

class _PrepareContent extends StatelessWidget {
  final JewelryPiece piece;

  const _PrepareContent({
    required this.piece,
  });

  static const _surface = Color(0xFFFFFCF8);
  static const _espresso = Color(0xFF3A2419);
  static const _gold = Color(0xFFB4895B);
  static const _champagne = Color(0xFFE7D7C3);
  static const _muted = Color(0xFF8B7768);

  @override
  Widget build(BuildContext context) {
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

                  const SizedBox(height: 4),

                  const _PrivacyCard(),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: FilledButton(
                     onPressed: () async {
  const permissionService = PermissionService();

  final granted = await permissionService.ensureCamera();

  if (!context.mounted) return;

  if (granted) {
    context.push(
      '/try-on/${piece.id}',
    );
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
    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(
          bottom: BorderSide(
            color: _champagne,
            width: 0.8,
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 10,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: _gold,
                size: 29,
              ),
            ),
          ),
          const Text(
            'Prueba virtual',
            style: TextStyle(
              color: _espresso,
              fontFamily: 'Georgia',
              fontSize: 25,
            ),
          ),
        ],
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

class _InstructionData {
  final IconData icon;
  final String text;

  const _InstructionData({
    required this.icon,
    required this.text,
  });
}