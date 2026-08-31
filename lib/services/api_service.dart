import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/division_data.dart';
import '../models/fixture.dart';

class ApiService {
  static Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.base.resolve(cleanPath).replace(queryParameters: queryParams);
  }

  static Future<DivisionData?> crawlAndSyncLiveRFUData({
    String? division,
    String? team,
    String? season,
  }) async {
    try {
      final uri = _buildUri('/api/crawl', {
        if (division != null && division.isNotEmpty) 'division': division,
        if (team != null && team.isNotEmpty) 'team': team,
        if (season != null && season.isNotEmpty) 'season': season,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        if (resData['data'] is Map<String, dynamic>) {
          return DivisionData.fromJson(resData['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiService crawl error: $e');
    }
    return null;
  }

  static Future<DivisionData?> fetchDivisionData({
    String? division,
    String? team,
    String? season,
    String? url,
  }) async {
    try {
      final uri = _buildUri('/api/parse', {
        if (division != null && division.isNotEmpty) 'division': division,
        if (team != null && team.isNotEmpty) 'team': team,
        if (season != null && season.isNotEmpty) 'season': season,
        if (url != null && url.isNotEmpty) 'url': url,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 14));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DivisionData.fromJson(data);
      }
    } catch (e) {
      debugPrint('ApiService error: $e');
    }
    return null;
  }

  static Future<bool> verifyAdminPassword(String password) async {
    final clean = password.trim();
    // 1. Instant local verification (handles rugby2026 and Rugby2026)
    if (clean.toLowerCase() == 'rugby2026') {
      return true;
    }

    // 2. Try serverless backend verification for custom passwords
    try {
      final uri = _buildUri('/api/admin/login');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'password': clean}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        if (resData is Map && resData['success'] == true) return true;
      }
    } catch (e) {
      debugPrint('Admin backend verification fallback: $e');
    }

    return false;
  }

  static Future<List<Map<String, dynamic>>> suggestTeams(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final uri = _buildUri('/api/suggest-teams', {'q': query.trim()});
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('Team suggestion error: $e');
    }
    return [];
  }

  static Future<List<Fixture>> fetchBackendCustomFixtures({String? season, String? team}) async {
    try {
      final uri = _buildUri('/api/fixtures/custom', {
        if (season != null && season.isNotEmpty) 'season': season,
        if (team != null && team.isNotEmpty) 'team': team,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['fixtures'] is List) {
          return (data['fixtures'] as List).map((row) => Fixture.fromJson(row)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching backend custom fixtures: $e');
    }
    return [];
  }

  static Future<bool> addBackendCustomFixture(Map<String, dynamic> payload) async {
    try {
      final uri = _buildUri('/api/fixtures/custom');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateBackendCustomFixture(String id, Map<String, dynamic> payload) async {
    try {
      final uri = _buildUri('/api/fixtures/custom/$id');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteBackendCustomFixture(String id) async {
    try {
      final uri = _buildUri('/api/fixtures/custom/$id');
      final response = await http.delete(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
