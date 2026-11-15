import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';

/// Dos secciones principales; la prueba AR se realiza desde cada joya.
class JewelryBottomNav extends StatelessWidget {
  final bool isHome;

  const JewelryBottomNav({super.key, required this.isHome});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: JoyeriaPalette.surface,
          border: Border(top: BorderSide(color: JoyeriaPalette.stroke)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavAction(
                icon: Icons.home_outlined,
                label: 'Inicio',
                selected: isHome,
                onTap: () => context.go('/home'),
              ),
            ),
            Expanded(
              child: _NavAction(
                icon: Icons.grid_view_rounded,
                label: 'Catálogo',
                selected: !isHome,
                onTap: () => context.go('/catalog'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavAction({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? JoyeriaPalette.rose : JoyeriaPalette.muted,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? JoyeriaPalette.rose : JoyeriaPalette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
