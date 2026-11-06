import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';

/// Pantalla de entrada pública: no hay cuentas, registro ni autenticación.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JoyeriaPalette.background,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(top: 8, left: 4, child: _Sprig(mirror: false)),
            const Positioned(
              right: 8,
              bottom: 132,
              child: _Sprig(mirror: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 16, 30, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    'ELEGANCIA EN CADA DETALLE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.4,
                      color: JoyeriaPalette.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(flex: 3),
                  const Icon(
                    Icons.diamond_outlined,
                    size: 68,
                    color: JoyeriaPalette.gold,
                  ),
                  const SizedBox(height: 22),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Jewelry AR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48,
                        fontFamily: 'Georgia',
                        color: JoyeriaPalette.espresso,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LineDecoration(),
                      SizedBox(width: 12),
                      Icon(
                        Icons.auto_awesome,
                        size: 11,
                        color: JoyeriaPalette.gold,
                      ),
                      SizedBox(width: 12),
                      _LineDecoration(),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Descubre tus joyas favoritas y\npruébatelas con realidad aumentada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 1.7,
                      fontSize: 14,
                      color: JoyeriaPalette.muted,
                    ),
                  ),
                  const Spacer(flex: 2),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CategoryPreview(label: 'Collares'),
                      _CategoryPreview(label: 'Aretes'),
                      _CategoryPreview(label: 'Pulseras'),
                    ],
                  ),
                  const Spacer(flex: 2),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: () => context.go('/home'),
                      child: const Text(
                        'Explorar colección',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineDecoration extends StatelessWidget {
  const _LineDecoration();
  @override
  Widget build(BuildContext context) =>
      Container(width: 46, height: 1, color: JoyeriaPalette.stroke);
}

class _CategoryPreview extends StatelessWidget {
  final String label;
  const _CategoryPreview({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: JoyeriaPalette.surface,
            border: Border.all(color: JoyeriaPalette.stroke),
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(25, 25),
              painter: _JewelryIconPainter(label),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: JoyeriaPalette.muted),
        ),
      ],
    );
  }
}

/// Iconos lineales para las tres categorias reales de joyas.
class _JewelryIconPainter extends CustomPainter {
  final String category;
  const _JewelryIconPainter(this.category);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 28, size.height / 28);
    final line = Paint()
      ..color = JoyeriaPalette.rose
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (category == 'Collares') {
      final chain = Path()
        ..moveTo(4, 5)
        ..cubicTo(4, 15, 8, 21, 14, 21)
        ..cubicTo(20, 21, 24, 15, 24, 5);
      canvas.drawPath(chain, line);
      canvas.drawLine(const Offset(14, 21), const Offset(14, 23), line);
      canvas.drawCircle(const Offset(14, 25), 2, line);
    } else if (category == 'Aretes') {
      for (final x in [8.0, 20.0]) {
        canvas.drawCircle(Offset(x, 5), 1.8, line);
        canvas.drawLine(Offset(x, 7), Offset(x, 12), line);
        final drop = Path()
          ..moveTo(x, 12)
          ..cubicTo(x - 7, 20, x - 3, 25, x, 25)
          ..cubicTo(x + 3, 25, x + 7, 20, x, 12);
        canvas.drawPath(drop, line);
      }
    } else if (category == 'Pulseras') {
      canvas.drawOval(const Rect.fromLTWH(3, 7, 22, 14), line);
      canvas.drawCircle(const Offset(14, 21), 3, line);
      canvas.drawLine(const Offset(4, 12), const Offset(7, 12), line);
      canvas.drawLine(const Offset(21, 12), const Offset(24, 12), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _JewelryIconPainter oldDelegate) =>
      category != oldDelegate.category;
}

/// Ramita decorativa dibujada en Flutter: no exige imágenes externas.
class _Sprig extends StatelessWidget {
  final bool mirror;
  const _Sprig({required this.mirror});
  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: mirror,
      flipY: mirror,
      child: SizedBox(
        width: 106,
        height: 132,
        child: CustomPaint(painter: _SprigPainter()),
      ),
    );
  }
}

class _SprigPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final branch = Paint()
      ..color = JoyeriaPalette.mutedRose.withValues(alpha: .50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final vine = Path()
      ..moveTo(size.width * .10, size.height * .96)
      ..cubicTo(
        size.width * .52,
        size.height * .64,
        size.width * .18,
        size.height * .37,
        size.width * .88,
        size.height * .04,
      );
    canvas.drawPath(vine, branch);
    for (var i = 0; i < 5; i++) {
      final y = size.height * (.19 + i * .15);
      final x = size.width * (.76 - i * .12);
      final side = i.isEven ? -1.0 : 1.0;
      final p = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + side * 31, y - 28, x + side * 38, y - 7)
        ..quadraticBezierTo(x + side * 19, y + 9, x, y);
      canvas.drawPath(p, branch);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
