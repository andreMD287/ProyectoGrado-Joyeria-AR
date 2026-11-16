import 'package:flutter/material.dart';

/// Identidad visual Rocío: marfil, rosa empolvado y acentos champán.
abstract final class JoyeriaPalette {
  static const background = Color(0xFFF8F0EE);
  static const surface = Color(0xFFFFFAF9);
  static const blush = Color(0xFFF0DFDC);
  static const rose = Color(0xFFA35F70);
  static const mutedRose = Color(0xFFBA8D90);
  static const espresso = Color(0xFF432B31);
  static const muted = Color(0xFF9C8184);
  static const gold = Color(0xFFBC9163);
  static const stroke = Color(0xFFECDAD7);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: JoyeriaPalette.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: JoyeriaPalette.rose,
    ).copyWith(primary: JoyeriaPalette.rose, surface: JoyeriaPalette.surface),
    appBarTheme: const AppBarTheme(
      backgroundColor: JoyeriaPalette.background,
      foregroundColor: JoyeriaPalette.espresso,
      centerTitle: true,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'Georgia',
        color: JoyeriaPalette.espresso,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Georgia',
        color: JoyeriaPalette.espresso,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Georgia',
        color: JoyeriaPalette.espresso,
      ),
      bodyMedium: TextStyle(color: JoyeriaPalette.espresso),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: JoyeriaPalette.rose,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
    ),
  );
}
