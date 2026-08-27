import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _fadeController.forward();
    _progressController.forward();

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) {
        context.go('/catalog');
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFFBF7F2);
    const espresso = Color(0xFF3A2419);
    const gold = Color(0xFFB4895B);
    const champagne = Color(0xFFD8BE9A);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: _BackgroundRingsPainter(),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _fadeController,
                curve: Curves.easeOut,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Joya decorativa superior
                    const SizedBox(
                      width: 290,
                      height: 125,
                      child: CustomPaint(
                        painter: _DiamondArcPainter(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Badge AR READY
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 21,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF956C48),
                            Color(0xFF795238),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8F6846)
                                .withValues(alpha: 0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_in_ar_outlined,
                            size: 17,
                            color: Color(0xFFF6EBDD),
                          ),
                          SizedBox(width: 9),
                          Text(
                            'AR READY',
                            style: TextStyle(
                              color: Color(0xFFFFF8EF),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 38),

                    const Text(
                      'C A S A   D E',
                      style: TextStyle(
                        color: gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Joyería',
                      style: TextStyle(
                        color: espresso,
                        fontSize: 70,
                        height: 1,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w400,
                        letterSpacing: -2,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // AR + líneas decorativas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 1,
                          color: champagne,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            'AR',
                            style: TextStyle(
                              color: gold,
                              fontSize: 34,
                              fontFamily: 'Georgia',
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        Container(
                          width: 72,
                          height: 1,
                          color: champagne,
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'REALIDAD AUMENTADA  ·  JOYERÍA FINA',
                        style: TextStyle(
                          color: gold,
                          fontSize: 11,
                          letterSpacing: 2.1,
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Barra de carga animada
                    SizedBox(
                      width: 220,
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: _progressController.value,
                              minHeight: 1.8,
                              backgroundColor:
                                  champagne.withValues(alpha: 0.30),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                gold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'C A R G A N D O   E X P E R I E N C I A',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFBE956D),
                        fontSize: 9.5,
                        letterSpacing: 1.7,
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Círculos decorativos suaves del fondo.
class _BackgroundRingsPainter extends CustomPainter {
  const _BackgroundRingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height * 0.43,
    );

    final paint = Paint()
      ..color = const Color(0xFFD8BE9A).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final radii = [
      size.width * 0.45,
      size.width * 0.72,
      size.width * 1.03,
    ];

    for (final radius in radii) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Arco superior de diamantes.
class _DiamondArcPainter extends CustomPainter {
  const _DiamondArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height * 1.05,
    );

    final radius = size.width * 0.39;

    const startAngle = math.pi + 0.34;
    const endAngle = (2 * math.pi) - 0.34;

    final chainPaint = Paint()
      ..color = const Color(0xFFC59A6B).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    canvas.drawArc(
      rect,
      startAngle,
      endAngle - startAngle,
      false,
      chainPaint,
    );

    const diamondCount = 21;

    for (int i = 0; i < diamondCount; i++) {
      final fraction = i / (diamondCount - 1);

      final angle =
          startAngle + ((endAngle - startAngle) * fraction);

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      final centerDistance = (fraction - 0.5).abs() * 2;

      final diamondSize =
          3.7 + (1 - centerDistance) * 3.8;

      _drawDiamond(
        canvas,
        Offset(x, y),
        diamondSize,
      );
    }
  }

  void _drawDiamond(
    Canvas canvas,
    Offset center,
    double size,
  ) {
    final shadowPaint = Paint()
      ..color = const Color(0xFFB58755).withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        3,
      );

    canvas.drawCircle(
      center + const Offset(0, 2),
      size,
      shadowPaint,
    );

    final goldPaint = Paint()
      ..color = const Color(0xFFC99A63)
      ..style = PaintingStyle.fill;

    final gemPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF3E7D8),
          Color(0xFFFFFFFF),
        ],
      ).createShader(
        Rect.fromCenter(
          center: center,
          width: size * 2,
          height: size * 2,
        ),
      );

    final outer = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size, center.dy)
      ..close();

    canvas.drawPath(outer, goldPaint);

    final innerSize = size * 0.70;

    final inner = Path()
      ..moveTo(center.dx, center.dy - innerSize)
      ..lineTo(center.dx + innerSize, center.dy)
      ..lineTo(center.dx, center.dy + innerSize)
      ..lineTo(center.dx - innerSize, center.dy)
      ..close();

    canvas.drawPath(inner, gemPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}