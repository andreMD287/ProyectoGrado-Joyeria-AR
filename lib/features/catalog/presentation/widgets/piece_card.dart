import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/jewelry_category.dart';
import '../../domain/entities/jewelry_piece.dart';
import 'jewelry_artwork.dart';

class PieceCard extends StatelessWidget {
  final JewelryPiece piece;
  final VoidCallback onTap;
  const PieceCard({super.key, required this.piece, required this.onTap});

  String get _categoryLabel => switch (piece.categoria) {
    JewelryCategory.earring => 'ARETES',
    JewelryCategory.bracelet => 'PULSERAS',
    JewelryCategory.necklace => 'COLLARES',
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: JewelryArtwork(piece: piece)),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: JoyeriaPalette.surface.withValues(alpha: .96),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.center_focus_strong,
                            size: 12,
                            color: JoyeriaPalette.rose,
                          ),
                          SizedBox(width: 4),
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
          const SizedBox(height: 10),
          Text(
            piece.nombre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 17,
              height: 1.05,
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
    );
  }
}
