import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/division_data.dart';
import '../models/fixture.dart';
import '../models/standing_entry.dart';
import 'api_service.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static bool _initialized = false;

  static const String _kLocalFixturesKey = 'rfu_custom_fixtures_cache';
  static const String _kLocalLogosKey = 'rfu_team_logos_cache';

  static Future<void> init({String? url, String? anonKey}) async {
    if (_initialized) return;

    // 1. Restore cached fixtures and logos from persistent storage
    await _loadFromLocalCache();

    // 2. Initialize Supabase if credentials are provided
    const envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

    final resolvedUrl = (url != null && url.isNotEmpty)
        ? url
        : (envUrl.isNotEmpty ? envUrl : SupabaseConfig.fallbackUrl);
    final resolvedAnonKey = (anonKey != null && anonKey.isNotEmpty)
        ? anonKey
        : (envAnonKey.isNotEmpty ? envAnonKey : SupabaseConfig.fallbackAnonKey);

    if (resolvedUrl.isNotEmpty && resolvedAnonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: resolvedUrl,
          // ignore: deprecated_member_use
          anonKey: resolvedAnonKey,
        );
        _client = Supabase.instance.client;
        _initialized = true;
        debugPrint('Supabase successfully initialized with project: $resolvedUrl');
      } catch (e) {
        debugPrint('Supabase init error (using offline fallback): $e');
      }
    } else {
      debugPrint('Supabase credentials not configured. Operating in offline/local persistence mode.');
    }
  }

  // --- Local Cache Helpers (Browser LocalStorage / SharedPreferences) ---

  static final List<Fixture> _localCustomFixtures = [];
  static final Map<String, String> _localLogosMap = {};

  static Future<void> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load cached fixtures
      final fixturesJson = prefs.getString(_kLocalFixturesKey);
      if (fixturesJson != null && fixturesJson.isNotEmpty) {
        final List decoded = json.decode(fixturesJson);
        _localCustomFixtures.clear();
        for (var item in decoded) {
          _localCustomFixtures.add(Fixture.fromJson(Map<String, dynamic>.from(item)));
        }
      }

      // Load cached logos
      final logosJson = prefs.getString(_kLocalLogosKey);
      if (logosJson != null && logosJson.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(logosJson);
        _localLogosMap.clear();
        decoded.forEach((key, value) {
          _localLogosMap[key.toLowerCase()] = value.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading local cache: $e');
    }
  }

  static Future<void> _saveLocalFixturesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listData = _localCustomFixtures.map((f) => f.toJson()).toList();
      await prefs.setString(_kLocalFixturesKey, json.encode(listData));
    } catch (e) {
      debugPrint('Error saving local fixtures cache: $e');
    }
  }

  static Future<void> _saveLocalLogosCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalLogosKey, json.encode(_localLogosMap));
    } catch (e) {
      debugPrint('Error saving local logos cache: $e');
    }
  }

  // --- Custom Fixtures CRUD with Multi-Layer Persistence ---

  static Future<List<Fixture>> fetchCustomFixtures({String? division, String? team}) async {
    // Ensure cache is loaded
    if (_localCustomFixtures.isEmpty) {
      await _loadFromLocalCache();
    }

    final List<Fixture> allFixtures = [];

    // 1. Fetch from Supabase if connected (Source of Truth)
    final client = _client;
    if (client != null) {
      try {
        final response = await client
            .from('custom_fixtures')
            .select()
            .order('created_at', ascending: true);
        
        final remote = (response as List).map((row) => Fixture.fromJson(row)).toList();
        _localCustomFixtures.clear();
        _localCustomFixtures.addAll(remote);
        await _saveLocalFixturesCache();
        allFixtures.addAll(remote);
      } catch (e) {
        debugPrint('Error fetching custom fixtures from Supabase: $e');
        allFixtures.addAll(_localCustomFixtures);
      }
    } else {
      allFixtures.addAll(_localCustomFixtures);
    }

    // Filter by team if requested
    final cleanTeam = team?.trim().toLowerCase();
    if (cleanTeam != null && cleanTeam.isNotEmpty) {
      return allFixtures.where((f) {
        return f.homeTeam.toLowerCase().contains(cleanTeam) ||
            f.awayTeam.toLowerCase().contains(cleanTeam);
      }).toList();
    }

    return allFixtures;
  }

  static Future<Fixture?> addCustomFixture(Fixture fixture, String division) async {
    final generatedId = fixture.id ?? 'cust_${DateTime.now().millisecondsSinceEpoch}';
    final customFix = Fixture(
      id: generatedId,
      date: fixture.date,
      dateIso: fixture.dateIso,
      time: fixture.time,
      homeTeam: fixture.homeTeam,
      awayTeam: fixture.awayTeam,
      homeScore: fixture.homeScore,
      awayScore: fixture.awayScore,
      status: fixture.status,
      venue: fixture.venue,
      competition: 'Friendly',
      roundNum: 'Friendly Matches',
      isCustom: true,
      homeLogoUrl: fixture.homeLogoUrl,
      awayLogoUrl: fixture.awayLogoUrl,
    );

    // 1. Save to local memory and browser persistent storage immediately
    _localCustomFixtures.removeWhere((f) => f.id == generatedId);
    _localCustomFixtures.add(customFix);
    await _saveLocalFixturesCache();

    // 2. Sync to Python backend API
    try {
      final payload = customFix.toJson();
      payload['division'] = division;
      await ApiService.addBackendCustomFixture(payload);
    } catch (_) {}

    // 3. Save to Supabase if client is initialized
    final client = _client;
    if (client != null) {
      try {
        final payload = customFix.toJson();
        payload['division'] = division;
        
        final response = await client
            .from('custom_fixtures')
            .insert(payload)
            .select()
            .single();

        return Fixture.fromJson(response);
      } catch (e) {
        debugPrint('Error adding fixture to Supabase: $e');
      }
    }

    return customFix;
  }

  static Future<bool> updateCustomFixture(String id, Map<String, dynamic> updates) async {
    final idx = _localCustomFixtures.indexWhere((f) => f.id == id);
    if (idx != -1) {
      final old = _localCustomFixtures[idx];
      _localCustomFixtures[idx] = Fixture(
        id: id,
        date: updates['date'] ?? old.date,
        dateIso: updates['date_iso'] ?? old.dateIso,
        time: updates['time'] ?? old.time,
        homeTeam: updates['home_team'] ?? old.homeTeam,
        awayTeam: updates['away_team'] ?? old.awayTeam,
        homeScore: updates.containsKey('home_score') ? updates['home_score'] : old.homeScore,
        awayScore: updates.containsKey('away_score') ? updates['away_score'] : old.awayScore,
        status: updates['status'] ?? old.status,
        venue: updates['venue'] ?? old.venue,
        competition: 'Friendly',
        roundNum: 'Friendly Matches',
        isCustom: true,
      );
      await _saveLocalFixturesCache();
    }

    // Sync to Python backend
    try {
      await ApiService.updateBackendCustomFixture(id, updates);
    } catch (_) {}

    // Sync to Supabase
    final client = _client;
    if (client == null) return true;
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
    _localCustomFixtures.removeWhere((f) => f.id == id);
    await _saveLocalFixturesCache();

    // Sync to Python backend
    try {
      await ApiService.deleteBackendCustomFixture(id);
    } catch (_) {}

    // Sync to Supabase (Delete from both custom_fixtures and fixtures tables)
    final client = _client;
    if (client == null) return true;
    try {
      await client
          .from('custom_fixtures')
          .delete()
          .eq('id', id);
      
      await client
          .from('fixtures')
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
    final cleanTeam = teamName.trim();
    final cleanTeamKey = cleanTeam.toLowerCase();
    final cleanFileExt = fileExtension.replaceAll('.', '').toLowerCase();
    final mime = cleanFileExt == 'svg' ? 'image/svg+xml' : (cleanFileExt == 'jpg' ? 'image/jpeg' : 'image/$cleanFileExt');
    final base64String = base64Encode(fileBytes);
    final dataUri = 'data:$mime;base64,$base64String';

    String chosenLogoUrl = dataUri;
    final client = _client;

    if (client != null) {
      // 1. Attempt upload to Supabase Storage bucket
      final candidateBuckets = [
        'rfu-parcer-team-logos',
        'rfu-parser-team-logos',
        'rfu_parcer_team_logos',
        'rfu_parser_team_logos',
        'team-logos',
        'team-logo',
        'team_logos',
        'team_logo',
        'teamlogos',
      ];
      bool uploadSuccess = false;

      for (var bucket in candidateBuckets) {
        try {
          final cleanPath = '${cleanTeamKey.replaceAll(RegExp(r'[^a-z0-9]'), '_')}$fileExtension';
          await client.storage.from(bucket).uploadBinary(
                cleanPath,
                fileBytes,
                fileOptions: const FileOptions(upsert: true),
              );
          chosenLogoUrl = client.storage.from(bucket).getPublicUrl(cleanPath);
          uploadSuccess = true;
          break;
        } catch (_) {
          // Try next bucket variant
        }
      }

      if (!uploadSuccess) {
        debugPrint('Supabase storage bucket upload fallback to data URI');
        chosenLogoUrl = dataUri;
      }

      // 2. Upsert mapping in team_logos table
      try {
        await client.from('team_logos').upsert({
          'team_name': cleanTeam,
          'logo_url': chosenLogoUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'team_name');
      } catch (dbError) {
        debugPrint('Supabase team_logos table upsert error: $dbError');
      }
    }

    // 3. Store in persistent local cache so UI immediately and permanently displays it
    _localLogosMap[cleanTeamKey] = chosenLogoUrl;
    await _saveLocalLogosCache();
    return chosenLogoUrl;
  }

  static Future<Map<String, String>> fetchTeamLogos() async {
    if (_localLogosMap.isEmpty) {
      await _loadFromLocalCache();
    }
    final Map<String, String> logoMap = Map.from(_localLogosMap);
    final client = _client;
    if (client == null) return logoMap;
    try {
      final response = await client.from('team_logos').select('team_name, logo_url');
      for (var row in (response as List)) {
        final k = row['team_name'].toString().toLowerCase();
        final v = row['logo_url'].toString();
        logoMap[k] = v;
        _localLogosMap[k] = v;
      }
      await _saveLocalLogosCache();
      return logoMap;
    } catch (e) {
      debugPrint('Error fetching team logos from Supabase: $e');
      return logoMap;
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

      // 3. Upsert Fixtures (only official league fixtures, custom fixtures belong in custom_fixtures table)
      final fixtures = (divisionData.fixtures as List).where((f) => f.isCustom != true).toList();
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
          'is_custom': false,
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

  static Future<DivisionData?> fetchDivisionFromSupabase({
    String? division,
    String? team,
    required String season,
  }) async {
    final client = _client;
    if (client == null) return null;

    try {
      String? divId;
      String? resolvedDivisionName = division;
      String? resolvedSourceUrl;

      // 1. If division name is provided, search directly
      if (division != null && division.trim().isNotEmpty && division != 'ALL / Select Division') {
        final divResp = await client
            .from('divisions')
            .select('id, division_name, season, source_url')
            .ilike('division_name', '%${division.trim()}%')
            .eq('season', season)
            .maybeSingle();

        if (divResp != null) {
          divId = divResp['id'] as String?;
          resolvedDivisionName = divResp['division_name'] as String?;
          resolvedSourceUrl = divResp['source_url'] as String?;
        }
      }

      // 2. If division was not resolved yet but a team name was provided, search standings for the team's division
      if (divId == null && team != null && team.trim().isNotEmpty) {
        final cleanTeam = team.trim();
        final standingsMatch = await client
            .from('standings')
            .select('division_id, team_name')
            .ilike('team_name', '%$cleanTeam%')
            .limit(1)
            .maybeSingle();

        if (standingsMatch != null) {
          divId = standingsMatch['division_id'] as String?;
          if (divId != null) {
            final divResp = await client
                .from('divisions')
                .select('id, division_name, season, source_url')
                .eq('id', divId)
                .maybeSingle();
            if (divResp != null) {
              resolvedDivisionName = divResp['division_name'] as String?;
              resolvedSourceUrl = divResp['source_url'] as String?;
            }
          }
        }
      }

      // 3. Fetch Standings & Fixtures if division was identified
      if (divId != null) {
        final standingsResp = await client
            .from('standings')
            .select()
            .eq('division_id', divId)
            .order('position', ascending: true);

        final fixturesResp = await client
            .from('fixtures')
            .select()
            .eq('division_id', divId)
            .order('date', ascending: true);

        final standings = (standingsResp as List).map((row) => StandingEntry.fromJson(row)).toList();
        final fixtures = (fixturesResp as List).map((row) => Fixture.fromJson(row)).toList();

        // Sort fixtures in strict chronological round order (Round 1, Round 2, ... Round 22)
        fixtures.sort((a, b) {
          int extractRound(String r) {
            final m = RegExp(r'(\d+)').firstMatch(r);
            return m != null ? (int.tryParse(m.group(1)!) ?? 999) : 999;
          }
          final rA = extractRound(a.roundNum);
          final rB = extractRound(b.roundNum);
          if (rA != rB) return rA.compareTo(rB);
          return (a.dateIso).compareTo(b.dateIso);
        });

        if (standings.isNotEmpty || fixtures.isNotEmpty) {
          return DivisionData(
            divisionName: resolvedDivisionName ?? (division ?? team ?? 'RFU Division'),
            season: season,
            sourceUrl: resolvedSourceUrl ?? '',
            standings: standings,
            fixtures: fixtures,
          );
        }
      }
    } catch (e) {
      debugPrint('Supabase division/team fetch error: $e');
    }
    return null;
  }
}
