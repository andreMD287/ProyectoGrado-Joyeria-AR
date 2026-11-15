import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';

class DiscoverArScreen extends StatefulWidget {
  const DiscoverArScreen({super.key});

  @override
  State<DiscoverArScreen> createState() => _DiscoverArScreenState();
}

class _DiscoverArScreenState extends State<DiscoverArScreen> {
  final _controller = PageController();
  int _index = 0;
  static const _steps = <_GuideStep>[
    _GuideStep(
      Icons.grid_view_rounded,
      '01 · DESCUBRE',
      'Encuentra tu joya',
      'Explora las fotografías y filtra por collares, aretes o pulseras.',
      'assets/jewelry_home/06_pulsera_tipo_cartier.jpg',
    ),
    _GuideStep(
      Icons.view_in_ar_outlined,
      '02 · OBSERVA',
      'Admírala en 360°',
      'En la ficha de una joya con modelo 3D puedes girarla y acercarte a sus detalles.',
      'assets/jewelry_home/01_collar_piedra_circonita.jpg',
    ),
    _GuideStep(
      Icons.center_focus_strong,
      '03 · EXPERIMENTA',
      'Pruébala con AR',
      'En el detalle toca “Probar con AR” cuando esté disponible. Algunas piezas esperan calibración.',
      'assets/jewelry_home/05_aretes_circulares_circonita.jpg',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _steps.length - 1) {
      context.go('/catalog');
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JoyeriaPalette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Volver',
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: JoyeriaPalette.espresso,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Descubre AR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontFamily: 'Georgia',
                          color: JoyeriaPalette.espresso,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 48,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.auto_awesome_outlined,
                          color: JoyeriaPalette.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _steps.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final step = _steps[i];
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        // Adapta la fotografía a la altura real de cada iPhone.
                        // El ScrollView evita desbordamientos al usar texto grande.
                        final photoHeight = (constraints.maxHeight * 0.45)
                            .clamp(175.0, 275.0)
                            .toDouble();
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        blurRadius: 22,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(25),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: photoHeight,
                                      child: Image.asset(
                                        step.image,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Row(
                                  children: [
                                    Icon(
                                      step.icon,
                                      size: 21,
                                      color: JoyeriaPalette.gold,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      step.eyebrow,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        letterSpacing: 1.6,
                                        fontWeight: FontWeight.w700,
                                        color: JoyeriaPalette.rose,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  step.title,
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 30,
                                    height: 1.14,
                                    color: JoyeriaPalette.espresso,
                                  ),
                                ),
                                const SizedBox(height: 11),
                                Text(
                                  step.description,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: JoyeriaPalette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _index == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _index == i
                          ? JoyeriaPalette.rose
                          : JoyeriaPalette.stroke,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 53,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    _index == _steps.length - 1
                        ? 'Explorar catálogo'
                        : 'Siguiente',
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

class _GuideStep {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final String image;
  const _GuideStep(
    this.icon,
    this.eyebrow,
    this.title,
    this.description,
    this.image,
  );
}
