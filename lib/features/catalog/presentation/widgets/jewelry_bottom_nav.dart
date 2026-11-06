import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';

class JewelryBottomNav extends StatelessWidget {
  final bool isHome;
  const JewelryBottomNav({super.key, required this.isHome});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 76,
        decoration: const BoxDecoration(
          color: JoyeriaPalette.surface,
          border: Border(top: BorderSide(color: JoyeriaPalette.stroke)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavAction(
              icon: Icons.home_outlined,
              label: 'Inicio',
              selected: isHome,
              onTap: () => context.go('/home'),
            ),
            _NavAction(
              icon: Icons.grid_view_rounded,
              label: 'Catálogo',
              selected: !isHome,
              onTap: () => context.go('/catalog'),
            ),
            GestureDetector(
              onTap: () => context.go('/catalog'),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 49,
                    height: 49,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: JoyeriaPalette.rose,
                    ),
                    child: const Icon(
                      Icons.center_focus_strong,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const Text(
                    'Probar AR',
                    style: TextStyle(fontSize: 10, color: JoyeriaPalette.rose),
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
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 23,
            color: selected ? JoyeriaPalette.rose : JoyeriaPalette.muted,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: selected ? JoyeriaPalette.rose : JoyeriaPalette.muted,
            ),
          ),
        ],
      ),
    ),
  );
}
