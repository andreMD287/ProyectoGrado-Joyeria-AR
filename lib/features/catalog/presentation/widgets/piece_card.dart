import 'package:flutter/material.dart';

import '../../domain/entities/jewelry_category.dart';
import '../../domain/entities/jewelry_piece.dart';

class PieceCard extends StatelessWidget {
  final JewelryPiece piece;
  final VoidCallback onTap;

  const PieceCard({
    super.key,
    required this.piece,
    required this.onTap,
  });

  IconData get _icon => switch (piece.categoria) {
        JewelryCategory.earring => Icons.diamond_outlined,
        JewelryCategory.bracelet => Icons.watch_outlined,
        JewelryCategory.necklace => Icons.favorite_border_rounded,
      };

  String get _categoryLabel => switch (piece.categoria) {
        JewelryCategory.earring => 'Arete',
        JewelryCategory.bracelet => 'Pulsera',
        JewelryCategory.necklace => 'Collar',
      };

  @override
  Widget build(BuildContext context) {
    const espresso = Color(0xFF3A2419);
    const gold = Color(0xFFB4895B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE7D7C3),
            ),
            boxShadow: [
              BoxShadow(
                color: espresso.withValues(alpha: 0.055),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF8EEE3),
                        Color(0xFFE8D5BF),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Container(
                          width: 105,
                          height: 105,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: gold.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(
                            _icon,
                            size: 54,
                            color: gold.withValues(alpha: 0.85),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFCF8)
                                .withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_border_rounded,
                            size: 17,
                            color: espresso,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    13,
                    14,
                    13,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _categoryLabel.toUpperCase(),
                        style: const TextStyle(
                          color: gold,
                          fontSize: 8.5,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        piece.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: espresso,
                          fontFamily: 'Georgia',
                          fontSize: 16,
                          height: 1.08,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        piece.material ?? 'Joyería fina',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8C796A),
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Row(
                        children: [
                          Icon(
                            Icons.view_in_ar_outlined,
                            size: 15,
                            color: gold,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Probar',
                            style: TextStyle(
                              color: gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
