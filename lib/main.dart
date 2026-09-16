import 'dart:async';
import 'package:flutter/material.dart';
import 'config/supabase_config.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'views/home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase client first - AppTheme.initTheme() below needs it
  // ready in order to fetch the site-wide default theme for a first-time
  // visitor with no personal theme choice saved yet.
  const String envUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  const String envAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  final String supabaseUrl = envUrl.isNotEmpty
      ? envUrl
      : SupabaseConfig.fallbackUrl;
  final String supabaseAnonKey = envAnonKey.isNotEmpty
      ? envAnonKey
      : SupabaseConfig.fallbackAnonKey;

  await SupabaseService.init(url: supabaseUrl, anonKey: supabaseAnonKey);

  // Initialize saved theme preference (or the site-wide default)
  await AppTheme.initTheme();

  // Fire-and-forget: loads the full team ID registry from Supabase in the
  // background so it's ready well before any dialog needs it, without
  // delaying first paint.
  unawaited(SupabaseService.loadTeamIdRegistry());

  runApp(const RFUHubApp());
}

class RFUHubApp extends StatelessWidget {
  const RFUHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'RFU Fixtures & League Tables Hub',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getTheme(themeMode),
          home: const HomeView(),
        );
      },
    );
  }
}
