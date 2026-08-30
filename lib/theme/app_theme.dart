import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  englandRfuOfficial(
    id: 'england_rfu_official',
    title: 'Navy & Rose Red (Official RFU)',
    subtitle: 'Official England Rugby & RFU Website Theme (Deep Navy, Rose Red & White)',
    darkBg: Color(0xFF081026),
    surfaceBg: Color(0xFF0F1E3D),
    cardBorder: Color(0x33E11D48),
    goldAccent: Color(0xFFE11D48), // England Rugby Rose Red
    tertiaryAccent: Color(0xFFF59E0B), // Championship Gold
    emeraldAccent: Color(0xFF10B981),
    rubyAccent: Color(0xFFDC2626),
    textPrimary: Color(0xFFFFFFFF),
    textMuted: Color(0xFF94A3B8),
  ),
  plymouthOaks(
    id: 'plymouth_oaks',
    title: 'Green & Gold',
    subtitle: 'British Racing Green & Gold (Plymstock Oaks RFC)',
    darkBg: Color(0xFF041A11),
    surfaceBg: Color(0xFF0A291C),
    cardBorder: Color(0x3334D399),
    goldAccent: Color(0xFFE5C158),
    tertiaryAccent: Color(0xFF10B981), // Emerald Turf
    emeraldAccent: Color(0xFF10B981),
    rubyAccent: Color(0xFFEF4444),
    textPrimary: Color(0xFFF8FAF8),
    textMuted: Color(0xFFA3B8AC),
  ),
  navySkyBlue(
    id: 'navy_sky_blue',
    title: 'Navy & Sky Blue',
    subtitle: 'Deep Oxford Navy & Sky Blue (Coventry & Maritime Clubs)',
    darkBg: Color(0xFF060F1E),
    surfaceBg: Color(0xFF0D1C34),
    cardBorder: Color(0x3338BDF8),
    goldAccent: Color(0xFF38BDF8),
    tertiaryAccent: Color(0xFFF59E0B), // Warm Amber
    emeraldAccent: Color(0xFF0284C7),
    rubyAccent: Color(0xFFEF4444),
    textPrimary: Color(0xFFF0F6FC),
    textMuted: Color(0xFF94A3B8),
  ),
  blackAmber(
    id: 'black_amber',
    title: 'Black & Amber',
    subtitle: 'Carbon Obsidian & Rich Rugby Amber',
    darkBg: Color(0xFF0A0A0A),
    surfaceBg: Color(0xFF171717),
    cardBorder: Color(0x33F59E0B),
    goldAccent: Color(0xFFF59E0B),
    tertiaryAccent: Color(0xFF06B6D4), // Electric Cyan
    emeraldAccent: Color(0xFFD97706),
    rubyAccent: Color(0xFFEF4444),
    textPrimary: Color(0xFFF5F5F5),
    textMuted: Color(0xFFA3A3A3),
  ),
  scarletWhite(
    id: 'scarlet_white',
    title: 'Scarlet & White',
    subtitle: 'Dark Scarlet Charcoal & Crisp White',
    darkBg: Color(0xFF170608),
    surfaceBg: Color(0xFF260C10),
    cardBorder: Color(0x33F43F5E),
    goldAccent: Color(0xFFFFFFFF),
    tertiaryAccent: Color(0xFFE5C158), // Championship Gold
    emeraldAccent: Color(0xFFEF4444),
    rubyAccent: Color(0xFFEF4444),
    textPrimary: Color(0xFFFFF1F2),
    textMuted: Color(0xFFFDA4AF),
  ),
  royalBlueYellow(
    id: 'royal_blue_yellow',
    title: 'Royal Blue & Yellow',
    subtitle: 'Deep Royal Cobalt & Electric Yellow (Bath & Brixham style)',
    darkBg: Color(0xFF051228),
    surfaceBg: Color(0xFF0A1F42),
    cardBorder: Color(0x33FACC15),
    goldAccent: Color(0xFFFACC15),
    tertiaryAccent: Color(0xFFFB923C), // Vibrant Tangerine
    emeraldAccent: Color(0xFF3B82F6),
    rubyAccent: Color(0xFFEF4444),
    textPrimary: Color(0xFFEFF6FF),
    textMuted: Color(0xFF93C5FD),
  ),
  maroonSilver(
    id: 'maroon_silver',
    title: 'Maroon & Silver',
    subtitle: 'Deep Velvet Maroon & Platinum Silver',
    darkBg: Color(0xFF14080F),
    surfaceBg: Color(0xFF220D1A),
    cardBorder: Color(0x33E2E8F0),
    goldAccent: Color(0xFFE2E8F0),
    tertiaryAccent: Color(0xFFE5C158), // Warm Gold
    emeraldAccent: Color(0xFFFB7185),
    rubyAccent: Color(0xFFEF4444),
    textPrimary: Color(0xFFFFF1F2),
    textMuted: Color(0xFFCBD5E1),
  ),
  emeraldWhite(
    id: 'emerald_white',
    title: 'Emerald & White',
    subtitle: 'Deep Turf Green & Pure White (Trailfinders style)',
    darkBg: Color(0xFF03160D),
    surfaceBg: Color(0xFF072617),
    cardBorder: Color(0x3322C55E),
    goldAccent: Color(0xFFFFFFFF),
    tertiaryAccent: Color(0xFFE5C158), // Warm Gold
    emeraldAccent: Color(0xFF22C55E),
    rubyAccent: Color(0xFFEF4444),
    textPrimary: Color(0xFFF0FDF4),
    textMuted: Color(0xFF86EFAC),
  ),
  rfuChampionship(
    id: 'rfu_championship',
    title: 'Midnight & Gold (Original)',
    subtitle: 'Midnight Slate & Championship Gold (Classic RFU Theme)',
    darkBg: Color(0xFF0B0F19),
    surfaceBg: Color(0xFF131A29),
    cardBorder: Color(0x33384260),
    goldAccent: Color(0xFFE5C158),
    tertiaryAccent: Color(0xFF10B981), // Emerald Green
    emeraldAccent: Color(0xFF10B981),
    rubyAccent: Color(0xFFEF4444),
    textPrimary: Color(0xFFF3F4F6),
    textMuted: Color(0xFF9CA3AF),
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
  
  // Default to Plymouth Oaks Green & Gold
  static final ValueNotifier<AppThemeMode> themeNotifier = ValueNotifier<AppThemeMode>(AppThemeMode.plymouthOaks);

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
        secondary: mode.tertiaryAccent,
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
