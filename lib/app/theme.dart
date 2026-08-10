import 'package:flutter/material.dart';

/// Tema Material 3 de la aplicación, con paleta derivada de un dorado joyería.
ThemeData buildTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B6914)),
    useMaterial3: true,
  );
}
