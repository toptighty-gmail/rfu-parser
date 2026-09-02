import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_theme_store.dart';

enum AppThemeMode {
  coolMinimalist(
    id: 'cool_minimalist',
    title: 'Cool Minimalist',
    subtitle: 'Clean, airy, modern contrast',
    darkBg: Color(0xFFF8FAFC), // background
    surfaceBg: Color(0xFFFFFFFF), // surface
    cardBorder: Color(0x33000000),
    goldAccent: Color(0xFF38BDF8), // accent
    tertiaryAccent: Color(0xFF64748B), // secondary
    emeraldAccent: Color(0xFF38BDF8), // accent
    rubyAccent: Color(0xFF4F46E5), // primary
    textPrimary: Color(0xFF1E293B),
    textMuted: Color(0xFF64748B), // secondary
  ),
  softNeutral(
    id: 'soft_neutral',
    title: 'Soft Neutral',
    subtitle: 'Warm, muted, understated',
    darkBg: Color(0xFFFAFAF9), // background
    surfaceBg: Color(0xFFFFFFFF), // surface
    cardBorder: Color(0x33000000),
    goldAccent: Color(0xFFFBBF24), // accent
    tertiaryAccent: Color(0xFF78716C), // secondary
    emeraldAccent: Color(0xFFFBBF24), // accent
    rubyAccent: Color(0xFF44403C), // primary
    textPrimary: Color(0xFF292524),
    textMuted: Color(0xFF78716C), // secondary
  ),
  electricModern(
    id: 'electric_modern',
    title: 'Electric Modern',
    subtitle: 'Bold, vivid, high-energy',
    darkBg: Color(0xFFFAFAFA), // background
    surfaceBg: Color(0xFFFFFFFF), // surface
    cardBorder: Color(0x33000000),
    goldAccent: Color(0xFFA3E635), // accent
    tertiaryAccent: Color(0xFF3B82F6), // secondary
    emeraldAccent: Color(0xFFA3E635), // accent
    rubyAccent: Color(0xFF1D4ED8), // primary
    textPrimary: Color(0xFF1F2937),
    textMuted: Color(0xFF6B7280), // neutral gray (secondary here is a vivid blue, unsuitable for muted text)
  ),
  custom(
    id: 'custom',
    title: 'Custom',
    subtitle: 'Your own colors and font',
    darkBg: CustomThemeStore.defaultBackground,
    surfaceBg: CustomThemeStore.defaultSurface,
    cardBorder: CustomThemeStore.defaultBorder,
    goldAccent: CustomThemeStore.defaultPrimary,
    tertiaryAccent: CustomThemeStore.defaultAccent,
    emeraldAccent: CustomThemeStore.defaultPrimary,
    rubyAccent: CustomThemeStore.defaultAccent,
    textPrimary: CustomThemeStore.defaultText,
    textMuted: CustomThemeStore.defaultTextMuted,
  );

  final String id;
  final String title;
  final String subtitle;
  final Color _darkBg;
  final Color _surfaceBg;
  final Color _cardBorder;
  final Color _goldAccent;
  final Color _tertiaryAccent;
  final Color _emeraldAccent;
  final Color _rubyAccent;
  final Color _textPrimary;
  final Color _textMuted;

  const AppThemeMode({
    required this.id,
    required this.title,
    required this.subtitle,
    required Color darkBg,
    required Color surfaceBg,
    required Color cardBorder,
    required Color goldAccent,
    required Color tertiaryAccent,
    required Color emeraldAccent,
    required Color rubyAccent,
    required Color textPrimary,
    required Color textMuted,
  })  : _darkBg = darkBg,
        _surfaceBg = surfaceBg,
        _cardBorder = cardBorder,
        _goldAccent = goldAccent,
        _tertiaryAccent = tertiaryAccent,
        _emeraldAccent = emeraldAccent,
        _rubyAccent = rubyAccent,
        _textPrimary = textPrimary,
        _textMuted = textMuted;

  /// Whether this is the user-editable Custom theme, whose live colors come
  /// from [CustomThemeStore] rather than the const values above.
  bool get isCustom => this == AppThemeMode.custom;

  Color get darkBg => isCustom ? CustomThemeStore.background.value : _darkBg;
  Color get surfaceBg => isCustom ? CustomThemeStore.surface.value : _surfaceBg;
  Color get cardBorder => isCustom ? CustomThemeStore.border.value : _cardBorder;
  Color get goldAccent => isCustom ? CustomThemeStore.primary.value : _goldAccent;
  Color get tertiaryAccent => isCustom ? CustomThemeStore.accent.value : _tertiaryAccent;
  Color get emeraldAccent => isCustom ? CustomThemeStore.primary.value : _emeraldAccent;
  Color get rubyAccent => isCustom ? CustomThemeStore.accent.value : _rubyAccent;
  Color get textPrimary => isCustom ? CustomThemeStore.text.value : _textPrimary;
  Color get textMuted => isCustom ? CustomThemeStore.textMuted.value : _textMuted;
}

/// A [ValueNotifier] with a public [refresh] so the Custom theme's colors
/// (which live in [CustomThemeStore], not on the enum value itself) can push
/// a rebuild to every [ValueListenableBuilder] listening to [AppTheme.themeNotifier]
/// even though the notifier's value (the [AppThemeMode.custom] enum constant)
/// hasn't changed.
class AppThemeNotifier extends ValueNotifier<AppThemeMode> {
  AppThemeNotifier(super.value);

  void refresh() => notifyListeners();
}

class AppTheme {
  static const String _kThemePrefKey = 'rfu_selected_theme_mode_v2';

  // Default to Cool Minimalist
  static final AppThemeNotifier themeNotifier = AppThemeNotifier(AppThemeMode.coolMinimalist);

  static AppThemeMode get currentMode => themeNotifier.value;

  // Dynamic getters so all widgets across the app seamlessly adapt to the selected theme
  static Color get goldAccent => currentMode.goldAccent;
  static Color get tertiaryAccent => currentMode.tertiaryAccent;
  static Color get emeraldAccent => currentMode.emeraldAccent;
  static Color get rubyAccent => currentMode.rubyAccent;
  static Color get textPrimary => currentMode.textPrimary;
  static Color get textMuted => currentMode.textMuted;
  static Color get cardBorder => currentMode.cardBorder;
  static Color get darkBg => currentMode.darkBg;
  static Color get surfaceBg => currentMode.surfaceBg;

  /// Load persisted theme preference (and any saved Custom theme colors/font)
  /// from storage on startup.
  static Future<void> initTheme() async {
    await CustomThemeStore.load();
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_kThemePrefKey);
      if (savedId != null && savedId.isNotEmpty) {
        final match = AppThemeMode.values.firstWhere(
          (m) => m.id == savedId,
          orElse: () => AppThemeMode.coolMinimalist,
        );
        themeNotifier.value = match;
      }
    } catch (_) {}
  }

  /// Switch the active theme and persist the choice
  static Future<void> setTheme(AppThemeMode mode) async {
    themeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemePrefKey, mode.id);
    } catch (_) {}
  }

  /// Revert back to the default theme
  static Future<void> revertToOriginal() async {
    await setTheme(AppThemeMode.coolMinimalist);
  }

  static ThemeData get darkTheme => getTheme(currentMode);

  /// Call after changing a [CustomThemeStore] value while [currentMode] is
  /// [AppThemeMode.custom], so the live app (not just the editor's own
  /// preview) picks up the change immediately.
  static void refreshIfCustom() {
    if (currentMode.isCustom) themeNotifier.refresh();
  }

  static ThemeData getTheme(AppThemeMode mode) {
    final fontFamily = mode.isCustom ? CustomThemeStore.fontFamily.value : 'Sora';
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: mode.darkBg,
      primaryColor: mode.goldAccent,
      colorScheme: ColorScheme.light(
        primary: mode.goldAccent,
        secondary: mode.tertiaryAccent,
        surface: mode.surfaceBg,
        error: mode.rubyAccent,
      ),
      textTheme: GoogleFonts.getTextTheme(fontFamily, ThemeData.light().textTheme).copyWith(
        displayLarge: TextStyle(color: mode.textPrimary, fontWeight: FontWeight.bold, fontSize: 32),
        titleLarge: TextStyle(color: mode.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        bodyLarge: TextStyle(color: mode.textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: mode.textMuted, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: mode.surfaceBg,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: mode.cardBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }

  static BoxDecoration glassBoxDecoration({double borderRadius = 16, Color? borderColor}) {
    return BoxDecoration(
      color: currentMode.surfaceBg.withValues(alpha: 0.90),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? currentMode.cardBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
