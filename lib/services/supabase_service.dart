import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fixture.dart';

class SupabaseService {
  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static bool get isInitialized => _client != null;

  // Initialize Supabase client safely
  static Future<void> init({required String url, required String anonKey}) async {
    if (url.isEmpty || anonKey.isEmpty || url.contains('your-supabase-project')) {
      print('Supabase credentials not configured yet. Running in offline/hybrid mode.');
      return;
    }
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
    } catch (e) {
      print('Supabase init error: $e');
    }
  }

  // --- Custom Fixtures CRUD ---

  static Future<List<Fixture>> fetchCustomFixtures(String division) async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client
          .from('custom_fixtures')
          .select()
          .eq('division', division)
          .order('created_at', ascending: true);
      
      return (response as List).map((row) => Fixture.fromJson(row)).toList();
    } catch (e) {
      print('Error fetching custom fixtures from Supabase: $e');
      return [];
    }
  }

  static Future<Fixture?> addCustomFixture(Fixture fixture, String division) async {
    final client = _client;
    if (client == null) return null;
    try {
      final payload = fixture.toJson();
      payload['division'] = division;
      
      final response = await client
          .from('custom_fixtures')
          .insert(payload)
          .select()
          .single();

      return Fixture.fromJson(response);
    } catch (e) {
      print('Error adding fixture to Supabase: $e');
      return null;
    }
  }

  static Future<bool> updateCustomFixture(String id, Map<String, dynamic> updates) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client
          .from('custom_fixtures')
          .update(updates)
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error updating fixture in Supabase: $e');
      return false;
    }
  }

  static Future<bool> deleteCustomFixture(String id) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client
          .from('custom_fixtures')
          .delete()
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error deleting fixture from Supabase: $e');
      return false;
    }
  }

  // --- Team Logos Storage & Database ---

  static Future<String?> uploadTeamLogo(String teamName, Uint8List fileBytes, String fileExtension) async {
    final client = _client;
    if (client == null) return null;
    try {
      final cleanTeamName = teamName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      final path = '$cleanTeamName$fileExtension';

      // 1. Upload to Supabase Storage Bucket 'team-logos'
      await client.storage.from('team-logos').uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = client.storage.from('team-logos').getPublicUrl(path);

      // 2. Upsert mapping in team_logos table
      await client.from('team_logos').upsert({
        'team_name': teamName.trim(),
        'logo_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'team_name');

      return publicUrl;
    } catch (e) {
      print('Error uploading team logo to Supabase: $e');
      return null;
    }
  }

  static Future<Map<String, String>> fetchTeamLogos() async {
    final client = _client;
    if (client == null) return {};
    try {
      final response = await client.from('team_logos').select('team_name, logo_url');
      final Map<String, String> logoMap = {};
      for (var row in (response as List)) {
        logoMap[row['team_name'].toString().toLowerCase()] = row['logo_url'].toString();
      }
      return logoMap;
    } catch (e) {
      print('Error fetching team logos from Supabase: $e');
      return {};
    }
  }
}
