import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  );

  final String id;
  final String title;
  final String subtitle;
  final Color darkBg;
  final Color surfaceBg;
  final Color cardBorder;
  final Color goldAccent;
  final Color tertiaryAccent;
  final Color emeraldAccent;
  final Color rubyAccent;
  final Color textPrimary;
  final Color textMuted;

  const AppThemeMode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.darkBg,
    required this.surfaceBg,
    required this.cardBorder,
    required this.goldAccent,
    required this.tertiaryAccent,
    required this.emeraldAccent,
    required this.rubyAccent,
    required this.textPrimary,
    required this.textMuted,
  });
}

class AppTheme {
  static const String _kThemePrefKey = 'rfu_selected_theme_mode_v2';
  
  // Default to Cool Minimalist
  static final ValueNotifier<AppThemeMode> themeNotifier = ValueNotifier<AppThemeMode>(AppThemeMode.coolMinimalist);

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

  /// Load persisted theme preference from storage on startup
  static Future<void> initTheme() async {
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

  static ThemeData getTheme(AppThemeMode mode) {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: mode.darkBg,
      primaryColor: mode.goldAccent,
      colorScheme: ColorScheme.light(
        primary: mode.goldAccent,
        secondary: mode.tertiaryAccent,
        surface: mode.surfaceBg,
        error: mode.rubyAccent,
      ),
      textTheme: GoogleFonts.soraTextTheme(ThemeData.light().textTheme).copyWith(
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
