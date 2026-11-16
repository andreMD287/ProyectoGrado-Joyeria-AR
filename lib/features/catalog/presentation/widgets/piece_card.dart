import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/jewelry_category.dart';
import '../../domain/entities/jewelry_piece.dart';
import 'jewelry_artwork.dart';
import '../controllers/favorites_controller.dart';

class PieceCard extends ConsumerWidget {
  final JewelryPiece piece;
  final VoidCallback onTap;

  const PieceCard({super.key, required this.piece, required this.onTap});

  String get _categoryLabel => switch (piece.categoria) {
    JewelryCategory.earring => 'ARETES',
    JewelryCategory.bracelet => 'PULSERAS',
    JewelryCategory.necklace => 'COLLARES',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved =
        ref.watch(favoritesProvider).valueOrNull?.contains(piece.id) ?? false;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 0.88,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: JewelryArtwork(piece: piece, photoFit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 9,
                    top: 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: JoyeriaPalette.surface.withValues(alpha: .95),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        tooltip: saved
                            ? 'Quitar de mi joyero'
                            : 'Guardar en mi joyero',
                        onPressed: () {
                          ref.read(favoritesProvider.notifier).toggle(piece.id);
                        },
                        icon: Icon(
                          saved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 20,
                          color: JoyeriaPalette.rose,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 38,
                        ),
                        padding: const EdgeInsets.all(7),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  if (piece.modeloGlb.isNotEmpty &&
                      (piece.id != 'collar-circonita-foto-01' ||
                          (piece.dimensionesMm.longitud ?? 0) > 0))
                    Positioned(
                      left: 9,
                      bottom: 9,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: JoyeriaPalette.surface.withValues(alpha: .96),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.center_focus_strong,
                                size: 12,
                                color: JoyeriaPalette.rose,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'AR',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: JoyeriaPalette.rose,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              piece.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 16,
                height: 1.12,
                color: JoyeriaPalette.espresso,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              piece.material ?? _categoryLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: JoyeriaPalette.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
