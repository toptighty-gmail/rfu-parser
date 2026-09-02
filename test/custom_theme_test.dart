import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfu_hub/theme/app_theme.dart';
import 'package:rfu_hub/theme/custom_theme_store.dart';
import 'package:rfu_hub/widgets/theme_selector_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CustomThemeStore', () {
    test('setters update the notifier value immediately', () async {
      await CustomThemeStore.setPrimary(const Color(0xFF112233));
      expect(CustomThemeStore.primary.value, const Color(0xFF112233));
    });

    test('saved colors round-trip through SharedPreferences', () async {
      await CustomThemeStore.setPrimary(const Color(0xFFAABBCC));
      await CustomThemeStore.setFontFamily('Inter');

      final prefs = await SharedPreferences.getInstance();
      final storedArgb = prefs.getInt('rfu_custom_theme_primary');
      expect(storedArgb, const Color(0xFFAABBCC).toARGB32());
      expect(prefs.getString('rfu_custom_theme_font_family'), 'Inter');
    });

    test('resetToDefaults restores every token', () async {
      await CustomThemeStore.setPrimary(const Color(0xFF000001));
      await CustomThemeStore.resetToDefaults();
      expect(CustomThemeStore.primary.value, CustomThemeStore.defaultPrimary);
      expect(CustomThemeStore.fontFamily.value, CustomThemeStore.defaultFontFamily);
    });

    test('contrastRatio is 21:1 for black on white and 1:1 for identical colors', () {
      expect(CustomThemeStore.contrastRatio(Colors.black, Colors.white), closeTo(21.0, 0.05));
      expect(CustomThemeStore.contrastRatio(Colors.red, Colors.red), closeTo(1.0, 0.001));
    });
  });

  group('AppThemeMode.custom', () {
    test('reflects live CustomThemeStore values, unlike the preset themes', () async {
      await CustomThemeStore.setPrimary(const Color(0xFF654321));
      expect(AppThemeMode.custom.goldAccent, const Color(0xFF654321));
      expect(AppThemeMode.custom.isCustom, isTrue);
      expect(AppThemeMode.coolMinimalist.isCustom, isFalse);
    });

    test('AppTheme.getTheme builds a ThemeData for the custom mode without throwing', () async {
      await CustomThemeStore.setBackground(const Color(0xFFF0F0F0));
      final theme = AppTheme.getTheme(AppThemeMode.custom);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF0F0F0));
    });
  });

  group('ThemeSelectorDialog', () {
    testWidgets('lists every AppThemeMode, including Custom', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ThemeSelectorDialog())),
      );
      await tester.pumpAndSettle();

      for (final mode in AppThemeMode.values) {
        expect(find.text(mode.title), findsOneWidget);
      }
    });

    testWidgets('shows an edit action only on the Custom tile', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ThemeSelectorDialog())),
      );
      await tester.pumpAndSettle();

      // One edit icon for Custom, plus the dialog's own "Revert" restore icon
      // and Apply button - just assert at least one edit affordance exists.
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });
}
