import 'package:flutter/material.dart';

import '../../domain/entities/jewelry_category.dart';
import '../../domain/entities/jewelry_piece.dart';

/// Tarjeta de una pieza en el catálogo.
class PieceCard extends StatelessWidget {
  final JewelryPiece piece;
  final VoidCallback onTap;

  const PieceCard({super.key, required this.piece, required this.onTap});

  IconData get _icon => switch (piece.categoria) {
        JewelryCategory.earring => Icons.diamond_outlined,
        JewelryCategory.bracelet => Icons.watch_outlined,
        JewelryCategory.necklace => Icons.favorite_border,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(_icon, size: 32),
        title: Text(piece.nombre),
        subtitle: Text(
          '${piece.categoria.id} · ${piece.material ?? "material n/d"}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
