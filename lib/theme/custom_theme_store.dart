import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user-editable colors and font for [AppThemeMode.custom],
/// persisted to [SharedPreferences] and exposed as [ValueNotifier]s so the
/// live preview and the app itself update immediately as the user edits.
class CustomThemeStore {
  CustomThemeStore._();

  static const String _prefsPrefix = 'rfu_custom_theme_';

  /// Sensible defaults shown the first time a user opens the Custom theme.
  static const Color defaultPrimary = Color(0xFF4F46E5);
  static const Color defaultAccent = Color(0xFF64748B);
  static const Color defaultBackground = Color(0xFFFFFFFF);
  static const Color defaultSurface = Color(0xFFFFFFFF);
  static const Color defaultText = Color(0xFF1E293B);
  static const Color defaultTextMuted = Color(0xFF64748B);
  static const Color defaultBorder = Color(0x33000000);
  static const String defaultFontFamily = 'Sora';

  /// Fonts offered in the font picker. Loaded on demand via GoogleFonts, so
  /// this list can grow without bundling anything extra.
  static const List<String> availableFonts = [
    'Sora',
    'Inter',
    'Roboto',
    'Poppins',
    'Nunito',
    'Montserrat',
    'Outfit',
    'Lato',
  ];

  static final ValueNotifier<Color> primary = ValueNotifier(defaultPrimary);
  static final ValueNotifier<Color> accent = ValueNotifier(defaultAccent);
  static final ValueNotifier<Color> background = ValueNotifier(defaultBackground);
  static final ValueNotifier<Color> surface = ValueNotifier(defaultSurface);
  static final ValueNotifier<Color> text = ValueNotifier(defaultText);
  static final ValueNotifier<Color> textMuted = ValueNotifier(defaultTextMuted);
  static final ValueNotifier<Color> border = ValueNotifier(defaultBorder);
  static final ValueNotifier<String> fontFamily = ValueNotifier(defaultFontFamily);

  static bool _loaded = false;

  /// Loads any previously saved custom theme from disk. Safe to call more
  /// than once; only reads from disk the first time.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      primary.value = _readColor(prefs, 'primary') ?? defaultPrimary;
      accent.value = _readColor(prefs, 'accent') ?? defaultAccent;
      background.value = _readColor(prefs, 'background') ?? defaultBackground;
      surface.value = _readColor(prefs, 'surface') ?? defaultSurface;
      text.value = _readColor(prefs, 'text') ?? defaultText;
      textMuted.value = _readColor(prefs, 'text_muted') ?? defaultTextMuted;
      border.value = _readColor(prefs, 'border') ?? defaultBorder;
      fontFamily.value = prefs.getString('${_prefsPrefix}font_family') ?? defaultFontFamily;
    } catch (_) {}
  }

  static Color? _readColor(SharedPreferences prefs, String key) {
    final argb = prefs.getInt('$_prefsPrefix$key');
    return argb != null ? Color(argb) : null;
  }

  static Future<void> _saveColor(String key, Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_prefsPrefix$key', color.toARGB32());
    } catch (_) {}
  }

  static Future<void> setPrimary(Color color) async {
    primary.value = color;
    await _saveColor('primary', color);
  }

  static Future<void> setAccent(Color color) async {
    accent.value = color;
    await _saveColor('accent', color);
  }

  static Future<void> setBackground(Color color) async {
    background.value = color;
    await _saveColor('background', color);
  }

  static Future<void> setSurface(Color color) async {
    surface.value = color;
    await _saveColor('surface', color);
  }

  static Future<void> setText(Color color) async {
    text.value = color;
    await _saveColor('text', color);
  }

  static Future<void> setTextMuted(Color color) async {
    textMuted.value = color;
    await _saveColor('text_muted', color);
  }

  static Future<void> setBorder(Color color) async {
    border.value = color;
    await _saveColor('border', color);
  }

  static Future<void> setFontFamily(String font) async {
    fontFamily.value = font;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_prefsPrefix}font_family', font);
    } catch (_) {}
  }

  /// Resets every token back to its default value and persists the reset.
  static Future<void> resetToDefaults() async {
    await setPrimary(defaultPrimary);
    await setAccent(defaultAccent);
    await setBackground(defaultBackground);
    await setSurface(defaultSurface);
    await setText(defaultText);
    await setTextMuted(defaultTextMuted);
    await setBorder(defaultBorder);
    await setFontFamily(defaultFontFamily);
  }

  /// WCAG relative luminance, per https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
  static double _relativeLuminance(Color c) {
    double linear(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
  }

  /// WCAG contrast ratio between two colors (1.0 to 21.0).
  static double contrastRatio(Color a, Color b) {
    final la = _relativeLuminance(a) + 0.05;
    final lb = _relativeLuminance(b) + 0.05;
    return la > lb ? la / lb : lb / la;
  }
}
