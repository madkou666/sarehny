import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarehny_mobile/src/app_theme.dart';

void main() {
  group('SarehnyPalette', () {
    test('parses the public site palette and derives a dark theme', () {
      final palette = SarehnyPalette.fromServer({
        'colors': {
          'bg': '#06070a',
          'surface': '#0b0d12',
          'raised': '#202328',
          'ink': '#eef1f2',
          'ink_2': '#c4ccd1',
          'muted': '#8f9aa7',
          'border': '#262b34',
          'primary': '#3df0c0',
          'secondary': '#ff4d8d',
          'success': '#3df0c0',
          'warning': '#f5c14e',
          'danger': '#ff6c96',
          'info': '#82abff',
        },
        'radius': 12,
      });
      final theme = buildSarehnyTheme(palette);

      expect(palette.canvas, const Color(0xFF06070A));
      expect(palette.primary, const Color(0xFF3DF0C0));
      expect(palette.radius, 12);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, palette.canvas);
    });

    test('uses the original dark site palette for malformed server colors and clamps radius', () {
      final palette = SarehnyPalette.fromServer({
        'colors': {'bg': 'url(unsafe)', 'primary': '#123'},
        'radius': 100,
      });

      expect(SarehnyPalette.defaults.canvas, const Color(0xFF06070A));
      expect(SarehnyPalette.defaults.surface, const Color(0xFF0B0D12));
      expect(SarehnyPalette.defaults.primary, const Color(0xFF3DF0C0));
      expect(SarehnyPalette.defaults.secondary, const Color(0xFFFF4D8D));
      expect(palette.canvas, SarehnyPalette.defaults.canvas);
      expect(palette.primary, SarehnyPalette.defaults.primary);
      expect(palette.radius, 24);
    });

    test('accepts only complete server palettes with safe colors and radius', () {
      final validTheme = <String, dynamic>{
        'colors': {
          'bg': '#06070a',
          'surface': '#0b0d12',
          'raised': '#202328',
          'ink': '#eef1f2',
          'ink_2': '#c4ccd1',
          'muted': '#8f9aa7',
          'border': '#262b34',
          'primary': '#3df0c0',
          'secondary': '#ff4d8d',
          'success': '#3df0c0',
          'warning': '#f5c14e',
          'danger': '#ff6c96',
          'info': '#82abff',
        },
        'radius': 8,
      };

      expect(SarehnyPalette.isValidServerTheme(validTheme), isTrue);
      expect(
        SarehnyPalette.isValidServerTheme({
          ...validTheme,
          'colors': {'bg': 'url(unsafe)'},
        }),
        isFalse,
      );
      expect(SarehnyPalette.isValidServerTheme({...validTheme, 'radius': 25}), isFalse);
    });
  });
}
