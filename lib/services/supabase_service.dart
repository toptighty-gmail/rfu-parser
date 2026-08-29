import 'package:flutter/foundation.dart';
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
      debugPrint('Supabase credentials not configured yet. Running in offline/hybrid mode.');
      return;
    }
    try {
      await Supabase.initialize(
        url: url,
        publishableKey: anonKey,
      );
    } catch (e) {
      debugPrint('Supabase init error: $e');
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
      debugPrint('Error fetching custom fixtures from Supabase: $e');
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
      debugPrint('Error adding fixture to Supabase: $e');
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
      debugPrint('Error updating fixture in Supabase: $e');
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
      debugPrint('Error deleting fixture from Supabase: $e');
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
      debugPrint('Error uploading team logo to Supabase: $e');
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
      debugPrint('Error fetching team logos from Supabase: $e');
      return {};
    }
  }

  // --- Live Division, Standings & Fixtures Sync ---

  static Future<bool> upsertDivisionData(dynamic divisionData) async {
    final client = _client;
    if (client == null) {
      debugPrint('Supabase client not initialized, skipping database upsert.');
      return false;
    }

    try {
      final divisionName = divisionData.divisionName as String;
      final season = divisionData.season as String;
      final sourceUrl = (divisionData.sourceUrl ?? '') as String;

      // 1. Upsert Division
      final divResponse = await client.from('divisions').upsert({
        'division_name': divisionName,
        'season': season,
        'source_url': sourceUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'division_name,season').select('id').single();

      final divisionId = divResponse['id'] as String?;
      if (divisionId == null) return false;

      // 2. Upsert Standings
      final standings = divisionData.standings as List;
      if (standings.isNotEmpty) {
        final standingsPayload = standings.map((s) => {
          'division_id': divisionId,
          'position': s.pos,
          'team_name': s.teamName,
          'played': s.played,
          'won': s.won,
          'drawn': s.drawn,
          'lost': s.lost,
          'points_for': s.pointsFor,
          'points_against': s.pointsAgainst,
          'points_diff': s.pointsDiff,
          'try_bonus': s.tryBonus,
          'lose_bonus': s.lossBonus,
          'points': s.points,
          'updated_at': DateTime.now().toIso8601String(),
        }).toList();

        await client.from('standings').upsert(
          standingsPayload,
          onConflict: 'division_id,team_name',
        );
      }

      // 3. Upsert Fixtures
      final fixtures = divisionData.fixtures as List;
      if (fixtures.isNotEmpty) {
        final fixturesPayload = fixtures.map((f) => {
          'division_id': divisionId,
          'date': f.date,
          'time': f.time != null && f.time.isNotEmpty ? f.time : '15:00',
          'home_team': f.homeTeam,
          'away_team': f.awayTeam,
          'home_score': f.homeScore,
          'away_score': f.awayScore,
          'status': f.status,
          'venue': f.venue ?? '',
          'round_num': f.roundNum ?? '',
          'is_custom': f.isCustom ?? false,
          'updated_at': DateTime.now().toIso8601String(),
        }).toList();

        await client.from('fixtures').upsert(
          fixturesPayload,
          onConflict: 'division_id,home_team,away_team,round_num',
        );
      }

      debugPrint('Successfully synced $divisionName ($season) to Supabase tables.');
      return true;
    } catch (e) {
      debugPrint('Error syncing division data to Supabase: $e');
      return false;
    }
  }
}
