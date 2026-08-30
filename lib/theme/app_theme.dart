import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  plymouthOaks(
    id: 'plymouth_oaks',
    title: 'Green & Gold',
    subtitle: 'British Racing Green & Gold (Plymouth Oaks RFC)',
    darkBg: Color(0xFF041A11),
    surfaceBg: Color(0xFF0A291C),
    cardBorder: Color(0x3334D399),
    goldAccent: Color(0xFFE5C158),
    emeraldAccent: Color(0xFF10B981),
    rubyAccent: Color(0xFFEF4444),
    textPrimary: Color(0xFFF8FAF8),
    textMuted: Color(0xFFA3B8AC),
  ),
  rfuChampionship(
    id: 'rfu_championship',
    title: 'Midnight & Gold (Original)',
    subtitle: 'Midnight Slate & Championship Gold (Classic Theme)',
    darkBg: Color(0xFF0B0F19),
    surfaceBg: Color(0xFF131A29),
    cardBorder: Color(0x33384260),
    goldAccent: Color(0xFFE5C158),
    emeraldAccent: Color(0xFF10B981),
    rubyAccent: Color(0xFFEF4444),
    textPrimary: Color(0xFFF3F4F6),
    textMuted: Color(0xFF9CA3AF),
  ),
  coastalNavy(
    id: 'coastal_navy',
    title: 'Navy & Gold',
    subtitle: 'Deep Royal Navy & Amber Gold (Maritime & Coastal Clubs)',
    darkBg: Color(0xFF060F1E),
    surfaceBg: Color(0xFF0C1D38),
    cardBorder: Color(0x3338BDF8),
    goldAccent: Color(0xFFFBBF24),
    emeraldAccent: Color(0xFF06B6D4),
    rubyAccent: Color(0xFFEF4444),
    textPrimary: Color(0xFFF0F6FC),
    textMuted: Color(0xFF94A3B8),
  ),
  clubhouseCrimson(
    id: 'clubhouse_crimson',
    title: 'Crimson & Gold',
    subtitle: 'Velvet Burgundy & Warm Gold (Traditional Rugby Heritage)',
    darkBg: Color(0xFF14080D),
    surfaceBg: Color(0xFF220D16),
    cardBorder: Color(0x33FB7185),
    goldAccent: Color(0xFFE5C158),
    emeraldAccent: Color(0xFF10B981),
    rubyAccent: Color(0xFFF43F5E),
    textPrimary: Color(0xFFFFF1F2),
    textMuted: Color(0xFFBEA1A9),
  );

  final String id;
  final String title;
  final String subtitle;
  final Color darkBg;
  final Color surfaceBg;
  final Color cardBorder;
  final Color goldAccent;
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
    required this.emeraldAccent,
    required this.rubyAccent,
    required this.textPrimary,
    required this.textMuted,
  });
}

class AppTheme {
  static const String _kThemePrefKey = 'rfu_selected_theme_mode_v2';
  
  // Default to Plymouth Oaks Elite
  static final ValueNotifier<AppThemeMode> themeNotifier = ValueNotifier<AppThemeMode>(AppThemeMode.plymouthOaks);

  static AppThemeMode get currentMode => themeNotifier.value;

  // Constant palette tokens allowing const widget expressions to compile cleanly
  static const Color goldAccent = Color(0xFFE5C158);
  static const Color emeraldAccent = Color(0xFF10B981);
  static const Color rubyAccent = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFF8FAF8);
  static const Color textMuted = Color(0xFFA3B8AC);
  static const Color cardBorder = Color(0x33384260);
  static const Color darkBg = Color(0xFF041A11);
  static const Color surfaceBg = Color(0xFF0A291C);

  /// Load persisted theme preference from storage on startup
  static Future<void> initTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_kThemePrefKey);
      if (savedId != null && savedId.isNotEmpty) {
        final match = AppThemeMode.values.firstWhere(
          (m) => m.id == savedId,
          orElse: () => AppThemeMode.plymouthOaks,
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

  /// Revert back to the original RFU Championship theme
  static Future<void> revertToOriginal() async {
    await setTheme(AppThemeMode.rfuChampionship);
  }

  static ThemeData get darkTheme => getTheme(currentMode);

  static ThemeData getTheme(AppThemeMode mode) {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: mode.darkBg,
      primaryColor: mode.goldAccent,
      colorScheme: ColorScheme.dark(
        primary: mode.goldAccent,
        secondary: mode.emeraldAccent,
        surface: mode.surfaceBg,
        error: mode.rubyAccent,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
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
