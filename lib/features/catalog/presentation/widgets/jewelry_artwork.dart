import 'package:flutter/material.dart';

import '../../domain/entities/jewelry_category.dart';
import '../../domain/entities/jewelry_piece.dart';
import '../../../../app/theme.dart';

/// Muestra una foto del catálogo si existe; si no, dibuja una joya vectorial.
class JewelryArtwork extends StatelessWidget {
  final JewelryPiece piece;
  final bool showPhoto;
  const JewelryArtwork({super.key, required this.piece, this.showPhoto = true});

  @override
  Widget build(BuildContext context) {
    Widget illustration() => CustomPaint(
      painter: _JewelryPainter(piece.categoria),
      child: const SizedBox.expand(),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6E9E6), Color(0xFFEAD9D4)],
          ),
        ),
        child: showPhoto && piece.foto.isNotEmpty
            ? Image.asset(
                piece.foto,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => illustration(),
              )
            : illustration(),
      ),
    );
  }
}

class _JewelryPainter extends CustomPainter {
  final JewelryCategory category;
  const _JewelryPainter(this.category);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final gold = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8B6037), Color(0xFFE5C58B), Color(0xFF9F7448)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * .018).clamp(2.0, 4.0)
      ..strokeCap = StrokeCap.round;
    final gem = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFBBDCE3), Color(0xFF74A5B4)],
      ).createShader(Rect.fromCircle(center: center, radius: w * .26));
    final pearl = Paint()..color = const Color(0xFFFFFBF5);
    if (category == JewelryCategory.necklace) {
      final chain = Path()
        ..moveTo(w * .24, h * .16)
        ..cubicTo(w * .21, h * .64, w * .38, h * .73, w * .5, h * .78)
        ..cubicTo(w * .62, h * .73, w * .79, h * .64, w * .76, h * .16);
      canvas.drawPath(chain, gold);
      canvas.drawLine(Offset(w * .5, h * .78), Offset(w * .5, h * .83), gold);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * .5, h * .85),
          width: w * .17,
          height: w * .19,
        ),
        gold..strokeWidth = 3,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * .5, h * .85),
          width: w * .135,
          height: w * .15,
        ),
        gem,
      );
    } else if (category == JewelryCategory.bracelet) {
      final rect = Rect.fromCenter(
        center: Offset(w * .5, h * .52),
        width: w * .63,
        height: h * .46,
      );
      canvas.drawOval(rect, gold..strokeWidth = 4);
      canvas.drawOval(rect.deflate(7), gold..strokeWidth = 1.3);
      for (var i = 0; i < 12; i++) {
        final angle = i * 6.28318530718 / 12;
        final x = w * .5 + (w * .63 / 2) * _cos(angle);
        final y = h * .52 + (h * .46 / 2) * _sin(angle);
        canvas.drawCircle(Offset(x, y), w * .016, pearl);
      }
      canvas.drawCircle(
        Offset(w * .5, h * .75),
        w * .075,
        gold..style = PaintingStyle.fill,
      );
      canvas.drawCircle(Offset(w * .5, h * .75), w * .054, gem);
    } else {
      for (final x in [.36, .64]) {
        canvas.drawCircle(
          Offset(w * x, h * .28),
          w * .034,
          gold..style = PaintingStyle.fill,
        );
        canvas.drawLine(
          Offset(w * x, h * .3),
          Offset(w * x, h * .47),
          gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6,
        );
        final drop = Path()
          ..moveTo(w * x, h * .46)
          ..cubicTo(
            w * (x - .085),
            h * .61,
            w * (x - .08),
            h * .78,
            w * x,
            h * .80,
          )
          ..cubicTo(
            w * (x + .08),
            h * .78,
            w * (x + .085),
            h * .61,
            w * x,
            h * .46,
          );
        canvas.drawPath(drop, gem);
        canvas.drawPath(
          drop,
          gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.7,
        );
      }
    }
  }

  double _sin(double x) {
    // Aproximación es suficiente para la pequeña decoración circular.
    final normalized = x % (2 * 3.141592653589793);
    var z = normalized;
    if (z > 3.141592653589793) z -= 2 * 3.141592653589793;
    return z * (1 - z.abs() / 3.141592653589793) * 1.27323954;
  }

  double _cos(double x) => _sin(x + 1.5707963267948966);

  @override
  bool shouldRepaint(covariant _JewelryPainter oldDelegate) =>
      oldDelegate.category != category;
}
