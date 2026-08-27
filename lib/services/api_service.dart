import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/division_data.dart';

class ApiService {
  static Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.base.resolve('/api$cleanPath').replace(queryParameters: queryParams);
  }

  static Future<DivisionData?> fetchDivisionData({
    String? division,
    String? team,
    String? season,
    String? url,
  }) async {
    try {
      final uri = _buildUri('/parse', {
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
      print('ApiService error: $e');
    }
    return null;
  }

  static Future<bool> verifyAdminPassword(String password) async {
    // 1. Try serverless backend verification
    try {
      final uri = _buildUri('/admin/login');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'password': password}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final resData = json.decode(response.body);
        if (resData['success'] == true) return true;
      }
    } catch (e) {
      print('Admin backend verification fallback: $e');
    }

    // 2. Fallback local verification
    return password.trim() == 'rugby2026';
  }

  static Future<List<Map<String, dynamic>>> suggestTeams(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final uri = _buildUri('/suggest-teams', {'q': query.trim()});
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      print('Team suggestion error: $e');
    }
    return [];
  }
}
