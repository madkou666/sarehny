import 'package:flutter/material.dart';

class SarehnyColors {
  static const ink = Color(0xFFF3F4F6);
  static const ink2 = Color(0xFFD1D5DB);
  static const muted = Color(0xFF9CA3AF);
  static const canvas = Color(0xFF0A0E1A);
  static const surface = Color(0xFF111827);
  static const raised = Color(0xFF1F2937);
  static const primary = Color(0xFF60A5FA);
  static const secondary = Color(0xFFF472B6);
  static const mint = Color(0xFF34D399);
  static const line = Color(0xFF283247);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const info = Color(0xFF93C5FD);
}

@immutable
class SarehnyPalette extends ThemeExtension<SarehnyPalette> {
  const SarehnyPalette({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.line,
    required this.primary,
    required this.secondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    this.radius = 8,
  });

  final Color canvas;
  final Color surface;
  final Color raised;
  final Color ink;
  final Color ink2;
  final Color muted;
  final Color line;
  final Color primary;
  final Color secondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final double radius;

  static const defaults = SarehnyPalette(
    canvas: SarehnyColors.canvas,
    surface: SarehnyColors.surface,
    raised: SarehnyColors.raised,
    ink: SarehnyColors.ink,
    ink2: SarehnyColors.ink2,
    muted: SarehnyColors.muted,
    line: SarehnyColors.line,
    primary: SarehnyColors.primary,
    secondary: SarehnyColors.secondary,
    success: SarehnyColors.mint,
    warning: SarehnyColors.warning,
    danger: SarehnyColors.danger,
    info: SarehnyColors.info,
    radius: 8,
  );

  factory SarehnyPalette.fromServer(Map<String, dynamic> value) {
    final colors = value['colors'] is Map
        ? Map<String, dynamic>.from(value['colors'] as Map)
        : const <String, dynamic>{};
    Color parse(String key, Color fallback) {
      final raw = colors[key];
      if (raw is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(raw)) {
        return fallback;
      }
      return Color(int.parse(raw.substring(1), radix: 16) | 0xFF000000);
    }

    final radiusValue = value['radius'];
    final radius = radiusValue is num ? radiusValue.toDouble().clamp(0, 24).toDouble() : defaults.radius;
    return SarehnyPalette(
      canvas: parse('bg', defaults.canvas),
      surface: parse('surface', defaults.surface),
      raised: parse('raised', defaults.raised),
      ink: parse('ink', defaults.ink),
      ink2: parse('ink_2', defaults.ink2),
      muted: parse('muted', defaults.muted),
      line: parse('border', defaults.line),
      primary: parse('primary', defaults.primary),
      secondary: parse('secondary', defaults.secondary),
      success: parse('success', defaults.success),
      warning: parse('warning', defaults.warning),
      danger: parse('danger', defaults.danger),
      info: parse('info', defaults.info),
      radius: radius,
    );
  }

  Color get primarySoft => Color.alphaBlend(primary.withValues(alpha: 0.11), surface);

  @override
  SarehnyPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? raised,
    Color? ink,
    Color? ink2,
    Color? muted,
    Color? line,
    Color? primary,
    Color? secondary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    double? radius,
  }) => SarehnyPalette(
        canvas: canvas ?? this.canvas,
        surface: surface ?? this.surface,
        raised: raised ?? this.raised,
        ink: ink ?? this.ink,
        ink2: ink2 ?? this.ink2,
        muted: muted ?? this.muted,
        line: line ?? this.line,
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        info: info ?? this.info,
        radius: radius ?? this.radius,
      );

  @override
  SarehnyPalette lerp(ThemeExtension<SarehnyPalette>? other, double t) {
    if (other is! SarehnyPalette) return this;
    return SarehnyPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      radius: radius + (other.radius - radius) * t,
    );
  }
}

bool _isDarkColor(Color color) => color.computeLuminance() < 0.42;

Color _contrastingColor(Color color) =>
    color.computeLuminance() > 0.42 ? const Color(0xFF151515) : Colors.white;

ThemeData buildSarehnyTheme([SarehnyPalette palette = SarehnyPalette.defaults]) {
  final brightness = _isDarkColor(palette.canvas) ? Brightness.dark : Brightness.light;
  final cardRadius = (10 + palette.radius * 1.5).clamp(10, 28).toDouble();
  final controlRadius = (8 + palette.radius).clamp(8, 24).toDouble();
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: brightness,
    surface: palette.surface,
  );
  final borderSide = BorderSide(color: palette.line);

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoKufiArabic',
    brightness: brightness,
    extensions: [palette],
    colorScheme: scheme.copyWith(
      primary: palette.primary,
      onPrimary: _contrastingColor(palette.primary),
      secondary: palette.secondary,
      onSecondary: _contrastingColor(palette.secondary),
      surface: palette.surface,
      onSurface: palette.ink,
      error: palette.danger,
      onError: _contrastingColor(palette.danger),
    ),
    scaffoldBackgroundColor: palette.canvas,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.canvas,
      foregroundColor: palette.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: palette.ink),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius), side: borderSide),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: borderSide),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: borderSide),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: BorderSide(color: palette.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: _contrastingColor(palette.primary),
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(fontSize: 28, height: 1.25, fontWeight: FontWeight.w800, color: palette.ink),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: palette.ink),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: palette.ink),
      bodyLarge: TextStyle(fontSize: 15, height: 1.7, color: palette.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.65, color: palette.ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.55, color: palette.muted),
    ),
  );
}
