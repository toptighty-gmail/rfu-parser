import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/competition.dart';
import '../models/division_data.dart';
import '../models/fixture.dart';
import '../models/standing_entry.dart';
import 'api_service.dart';
import 'team_logo_provider.dart';
import 'rfu_team_registry.dart';
import '../widgets/fixture_list.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static bool _initialized = false;

  static const String _kLocalFixturesKey = 'rfu_custom_fixtures_cache';
  static const String _kLocalLogosKey = 'rfu_team_logos_cache';

  static Future<void> init({String? url, String? anonKey}) async {
    if (_initialized) return;

    await _loadFromLocalCache();

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

  // --- Local Cache Helpers ---

  static final List<Fixture> _localCustomFixtures = [];
  static final Map<String, String> _localLogosMap = {};

  static Future<void> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final fixturesJson = prefs.getString(_kLocalFixturesKey);
      if (fixturesJson != null && fixturesJson.isNotEmpty) {
        final List decoded = json.decode(fixturesJson);
        _localCustomFixtures.clear();
        for (var item in decoded) {
          _localCustomFixtures.add(Fixture.fromJson(Map<String, dynamic>.from(item)));
        }
      }

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

  // --- Relational Competitions & Divisions Queries ---

  static Future<List<Competition>> fetchCompetitions() async {
    final client = _client;
    if (client == null) return [];
    try {
      final response = await client
          .from('competitions')
          .select()
          .order('rfu_competition_id', ascending: true);
      return (response as List).map((row) => Competition.fromJson(row)).toList();
    } catch (e) {
      debugPrint('Error fetching competitions from Supabase: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDivisionsCatalog({
    int? competitionId,
    int? tierLevel,
    String season = '2025-2026',
  }) async {
    final client = _client;
    if (client == null) return [];
    try {
      dynamic filter = client.from('divisions').select('id, division_name, rfu_competition_id, rfu_division_id, tier_level, region, season');
      if (competitionId != null) {
        filter = filter.eq('rfu_competition_id', competitionId);
      }
      if (tierLevel != null) {
        filter = filter.eq('tier_level', tierLevel);
      }
      final response = await filter.eq('season', season).order('division_name', ascending: true);
      return (response as List).map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('Error fetching divisions catalog from Supabase: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchTeams({String? county}) async {
    final client = _client;
    if (client == null) return [];
    try {
      dynamic filter = client.from('teams').select();
      if (county != null && county.isNotEmpty) {
        filter = filter.eq('county', county);
      }
      final response = await filter.order('team_name', ascending: true);
      return (response as List).map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('Error fetching teams from Supabase: $e');
      return [];
    }
  }

  // --- Custom Fixtures CRUD ---

  static Future<List<Fixture>> fetchCustomFixtures({String? division, String? team}) async {
    if (_localCustomFixtures.isEmpty) {
      await _loadFromLocalCache();
    }

    final List<Fixture> allFixtures = [];
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

    final cleanTeam = team?.trim();
    if (cleanTeam == null || cleanTeam.isEmpty) {
      return [];
    }

    final cleanTeamLower = cleanTeam.toLowerCase();
    final targetTeamId = RfuTeamRegistry.lookupTeamId(cleanTeamLower);

    return allFixtures.where((f) {
      // 1. Primary: If both have rfu_team_id, match strictly on rfu_team_id
      if (targetTeamId != null && f.rfuTeamId != null) {
        return f.rfuTeamId == targetTeamId;
      }

      // 2. Secondary: If context_team is present, match strictly using isExactTeamMatch
      if (f.contextTeam != null && f.contextTeam!.trim().isNotEmpty) {
        return FixtureList.isExactTeamMatch(f.contextTeam!, cleanTeam);
      }

      // 3. Fallback: Check home/away team with strict squad matching
      return FixtureList.isExactTeamMatch(f.homeTeam, cleanTeam) ||
             FixtureList.isExactTeamMatch(f.awayTeam, cleanTeam);
    }).toList();
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
      homeTeamId: fixture.homeTeamId,
      awayTeamId: fixture.awayTeamId,
      homeScore: fixture.homeScore,
      awayScore: fixture.awayScore,
      status: fixture.status,
      venue: fixture.venue,
      competition: fixture.competition,
      roundNum: fixture.roundNum,
      contextTeam: fixture.contextTeam,
      rfuTeamId: fixture.rfuTeamId,
      isCustom: true,
      homeLogoUrl: fixture.homeLogoUrl,
      awayLogoUrl: fixture.awayLogoUrl,
    );

    _localCustomFixtures.removeWhere((f) => f.id == generatedId);
    _localCustomFixtures.add(customFix);
    await _saveLocalFixturesCache();

    try {
      await ApiService.addBackendCustomFixture({
        'date': fixture.date,
        'home_team': fixture.homeTeam,
        'away_team': fixture.awayTeam,
        'time': fixture.time,
        'score': (fixture.homeScore != null && fixture.awayScore != null)
            ? '${fixture.homeScore} - ${fixture.awayScore}'
            : 'v',
        'status': fixture.status,
        'notes': fixture.venue,
      });
    } catch (_) {}

    final client = _client;
    if (client != null) {
      try {
        final payload = {
          'division': division,
          'date': fixture.date,
          'time': fixture.time,
          'home_team': fixture.homeTeam,
          'away_team': fixture.awayTeam,
          'score': (fixture.homeScore != null && fixture.awayScore != null)
              ? '${fixture.homeScore} - ${fixture.awayScore}'
              : 'v',
          'status': fixture.status,
          'notes': fixture.venue,
          'is_custom': true,
          'context_team': fixture.contextTeam ?? fixture.homeTeam,
          'rfu_team_id': fixture.rfuTeamId,
          'created_at': DateTime.now().toIso8601String(),
        };

        final response = await client.from('custom_fixtures').insert(payload).select().single();
        final remoteFixture = Fixture.fromJson(response);
        _localCustomFixtures.removeWhere((f) => f.id == generatedId);
        _localCustomFixtures.add(remoteFixture);
        await _saveLocalFixturesCache();
        return remoteFixture;
      } catch (e) {
        debugPrint('Supabase insert custom fixture error: $e');
      }
    }

    return customFix;
  }

  static Future<bool> updateCustomFixture(dynamic arg1, [dynamic arg2]) async {
    String? fixtureId;
    Map<String, dynamic> updatePayload = {};

    if (arg1 is Fixture) {
      fixtureId = arg1.id;
      updatePayload = arg1.toJson();
      final idx = _localCustomFixtures.indexWhere((f) => f.id == fixtureId);
      if (idx != -1) {
        _localCustomFixtures[idx] = arg1;
        await _saveLocalFixturesCache();
      }
    } else if (arg1 is String && arg2 is Map<String, dynamic>) {
      fixtureId = arg1;
      updatePayload = arg2;
      final idx = _localCustomFixtures.indexWhere((f) => f.id == fixtureId);
      if (idx != -1) {
        final updatedFix = Fixture.fromJson({..._localCustomFixtures[idx].toJson(), ...updatePayload});
        _localCustomFixtures[idx] = updatedFix;
        await _saveLocalFixturesCache();
      }
    }

    if (fixtureId != null) {
      try {
        if (!fixtureId.startsWith('cust_')) {
          await ApiService.updateBackendCustomFixture(fixtureId, updatePayload);
        }
      } catch (_) {}

      final client = _client;
      if (client != null) {
        try {
          await client.from('custom_fixtures').update(updatePayload).eq('id', fixtureId);
          return true;
        } catch (e) {
          debugPrint('Supabase update custom fixture error: $e');
        }
      }
    }

    return true;
  }

  static Future<bool> deleteCustomFixture(String fixtureId) async {
    _localCustomFixtures.removeWhere((f) => f.id == fixtureId);
    await _saveLocalFixturesCache();

    try {
      if (!fixtureId.startsWith('cust_')) {
        await ApiService.deleteBackendCustomFixture(fixtureId);
      }
    } catch (_) {}

    final client = _client;
    if (client != null) {
      try {
        await client.from('custom_fixtures').delete().eq('id', fixtureId);
        return true;
      } catch (e) {
        debugPrint('Supabase delete custom fixture error: $e');
      }
    }

    return true;
  }

  // --- Team Logos Storage & Table Management ---

  static Future<String?> uploadTeamLogo(String teamName, Uint8List fileBytes, String fileExtension) async {
    final cleanExt = fileExtension.replaceAll('.', '').toLowerCase();
    final cleanTeamKey = teamName.trim().toLowerCase();
    final sanitizedSlug = cleanTeamKey.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    final fileName = '$sanitizedSlug.$cleanExt';
    
    final client = _client;
    String chosenLogoUrl = '';

    if (client != null) {
      try {
        const bucketCandidates = [
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

        String? activeBucket;
        for (var b in bucketCandidates) {
          try {
            await client.storage.from(b).uploadBinary(
              fileName,
              fileBytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: cleanExt == 'svg' ? 'image/svg+xml' : 'image/$cleanExt',
              ),
            );
            activeBucket = b;
            break;
          } catch (_) {}
        }

        if (activeBucket != null) {
          chosenLogoUrl = client.storage.from(activeBucket).getPublicUrl(fileName);
        }

        if (chosenLogoUrl.isEmpty) {
          chosenLogoUrl = 'https://tgexkxrhcyxvnqafbdff.supabase.co/storage/v1/object/public/rfu-parcer-team-logos/$fileName';
        }

        await client.from('team_logos').upsert({
          'team_name': teamName.trim(),
          'logo_url': chosenLogoUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'team_name');
      } catch (dbError) {
        debugPrint('Supabase team_logos table upsert error: $dbError');
      }
    }

    if (chosenLogoUrl.isEmpty) {
      final base64String = base64Encode(fileBytes);
      final mime = cleanExt == 'svg' ? 'image/svg+xml' : 'image/$cleanExt';
      chosenLogoUrl = 'data:$mime;base64,$base64String';
    }

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
      final compId = divisionData.rfuCompetitionId as int?;
      final divIdNum = divisionData.rfuDivisionId as int?;
      final tier = divisionData.tierLevel as int?;
      final reg = divisionData.region as String?;

      // 1. Upsert Division
      final divResponse = await client.from('divisions').upsert({
        'division_name': divisionName,
        'season': season,
        'source_url': sourceUrl,
        if (compId != null) 'rfu_competition_id': compId,
        if (divIdNum != null) 'rfu_division_id': divIdNum,
        if (tier != null) 'tier_level': tier,
        if (reg != null) 'region': reg,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'division_name,season').select('id').single();

      final divisionId = divResponse['id'] as String?;
      if (divisionId == null) return false;

      // 2. Upsert Standings
      final standings = divisionData.standings as List;
      if (standings.isNotEmpty) {
        final standingsPayload = standings.map((s) {
          final tId = s.rfuTeamId ?? RfuTeamRegistry.lookupTeamId(s.teamName.toString());
          return {
            'division_id': divisionId,
            'position': s.pos,
            'team_name': s.teamName,
            if (tId != null) 'rfu_team_id': tId,
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
          };
        }).toList();

        await client.from('standings').upsert(
          standingsPayload,
          onConflict: 'division_id,team_name',
        );
      }

      // 3. Upsert Fixtures
      final fixtures = (divisionData.fixtures as List).where((f) => f.isCustom != true).toList();
      if (fixtures.isNotEmpty) {
        final fixturesPayload = fixtures.map((f) {
          final hId = f.homeTeamId ?? RfuTeamRegistry.lookupTeamId(f.homeTeam);
          final aId = f.awayTeamId ?? RfuTeamRegistry.lookupTeamId(f.awayTeam);
          return {
            'division_id': divisionId,
            'date': f.date,
            'time': f.time != null && f.time.isNotEmpty ? f.time : '15:00',
            'home_team': f.homeTeam,
            'away_team': f.awayTeam,
            if (hId != null) 'home_team_id': hId,
            if (aId != null) 'away_team_id': aId,
            'home_score': f.homeScore,
            'away_score': f.awayScore,
            'status': f.status,
            'venue': f.venue ?? '',
            'round_num': f.roundNum ?? '',
            'is_custom': false,
            'updated_at': DateTime.now().toIso8601String(),
          };
        }).toList();

        await client.from('fixtures').upsert(
          fixturesPayload,
          onConflict: 'division_id,home_team,away_team,round_num',
        );
      }

      // 4. Auto-Sync discovered Team Logos into team_logos table
      final standingsList = divisionData.standings as List;
      for (var s in standingsList) {
        final tName = s.teamName.toString().trim();
        if (tName.isEmpty) continue;
        final cleanKey = tName.toLowerCase();
        if (!_localLogosMap.containsKey(cleanKey)) {
          final logo = s.logoUrl ?? TeamLogoProvider.getPredefinedLogo(tName);
          if (logo != null && logo.isNotEmpty) {
            try {
              await client.from('team_logos').upsert({
                'team_name': tName,
                'logo_url': logo,
                'updated_at': DateTime.now().toIso8601String(),
              }, onConflict: 'team_name');
              _localLogosMap[cleanKey] = logo;
            } catch (_) {}
          }
        }
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
      int? resolvedCompId;
      int? resolvedDivIdNum;
      int? resolvedTier;
      String? resolvedRegion;

      // 1. If a specific team was searched or selected, resolve that team's actual division first!
      if (team != null && team.trim().isNotEmpty) {
        final cleanTeam = team.trim();
        final standingsMatches = await client
            .from('standings')
            .select('division_id, team_name, divisions!inner(id, division_name, season, source_url, rfu_competition_id, rfu_division_id, tier_level, region)')
            .eq('divisions.season', season)
            .ilike('team_name', '%$cleanTeam%');

        if (standingsMatches != null && (standingsMatches as List).isNotEmpty) {
          dynamic bestMatch = standingsMatches.first;
          for (var match in standingsMatches) {
            final tName = match['team_name']?.toString() ?? '';
            if (FixtureList.isExactTeamMatch(tName, cleanTeam)) {
              bestMatch = match;
              break;
            }
          }

          final divInfo = bestMatch['divisions'];
          if (divInfo != null) {
            divId = divInfo['id'] as String?;
            resolvedDivisionName = divInfo['division_name'] as String?;
            resolvedSourceUrl = divInfo['source_url'] as String?;
            resolvedCompId = divInfo['rfu_competition_id'] as int?;
            resolvedDivIdNum = divInfo['rfu_division_id'] as int?;
            resolvedTier = divInfo['tier_level'] as int?;
            resolvedRegion = divInfo['region'] as String?;
          }
        }
      }

      // 2. If no team specified or not found in standings, resolve by division name
      if (divId == null && division != null && division.trim().isNotEmpty && division != 'ALL / Select Division') {
        final divResp = await client
            .from('divisions')
            .select('id, division_name, season, source_url, rfu_competition_id, rfu_division_id, tier_level, region')
            .ilike('division_name', '%${division.trim()}%')
            .eq('season', season)
            .maybeSingle();

        if (divResp != null) {
          divId = divResp['id'] as String?;
          resolvedDivisionName = divResp['division_name'] as String?;
          resolvedSourceUrl = divResp['source_url'] as String?;
          resolvedCompId = divResp['rfu_competition_id'] as int?;
          resolvedDivIdNum = divResp['rfu_division_id'] as int?;
          resolvedTier = divResp['tier_level'] as int?;
          resolvedRegion = divResp['region'] as String?;
        }
      }

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
            rfuCompetitionId: resolvedCompId,
            rfuDivisionId: resolvedDivIdNum,
            tierLevel: resolvedTier,
            region: resolvedRegion,
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
