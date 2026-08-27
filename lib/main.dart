import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'views/home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase client
  // Replace these with your actual Supabase URL & Anon Key or configure via environment variables
  const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  await SupabaseService.init(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const RFUHubApp());
}

class RFUHubApp extends StatelessWidget {
  const RFUHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RFU Fixtures & League Tables Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeView(),
    );
  }
}
