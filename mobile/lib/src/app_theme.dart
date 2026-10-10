import 'package:flutter/material.dart';

class SarehnyColors {
  static const ink = Color(0xFF242A3A);
  static const muted = Color(0xFF7D8292);
  static const canvas = Color(0xFFF7F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF7357C8);
  static const primarySoft = Color(0xFFF0ECFB);
  static const mint = Color(0xFF2F8F76);
  static const line = Color(0xFFEAE8F0);
  static const danger = Color(0xFFB64D62);
}

ThemeData buildSarehnyTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SarehnyColors.primary,
    brightness: Brightness.light,
    surface: SarehnyColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: SarehnyColors.primary,
      onPrimary: Colors.white,
      surface: SarehnyColors.surface,
      error: SarehnyColors.danger,
    ),
    scaffoldBackgroundColor: SarehnyColors.canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: SarehnyColors.canvas,
      foregroundColor: SarehnyColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: SarehnyColors.ink),
    ),
    cardTheme: CardThemeData(
      color: SarehnyColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: SarehnyColors.line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: SarehnyColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: SarehnyColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: SarehnyColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SarehnyColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 28, height: 1.25, fontWeight: FontWeight.w800, color: SarehnyColors.ink),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: SarehnyColors.ink),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SarehnyColors.ink),
      bodyLarge: TextStyle(fontSize: 15, height: 1.7, color: SarehnyColors.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.65, color: SarehnyColors.ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.55, color: SarehnyColors.muted),
    ),
  );
}
