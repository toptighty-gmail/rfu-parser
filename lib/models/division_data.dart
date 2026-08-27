import 'fixture.dart';
import 'standing_entry.dart';

class DivisionData {
  final String divisionName;
  final String season;
  final List<StandingEntry> standings;
  final List<Fixture> fixtures;
  final String? sourceUrl;

  DivisionData({
    required this.divisionName,
    required this.season,
    required this.standings,
    required this.fixtures,
    this.sourceUrl,
  });

  factory DivisionData.fromJson(Map<String, dynamic> json) {
    var standingsList = (json['standings'] as List<dynamic>?)
            ?.map((e) => StandingEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    var fixturesList = (json['fixtures'] as List<dynamic>?)
            ?.map((e) => Fixture.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return DivisionData(
      divisionName: json['division_name'] ?? json['division'] ?? 'RFU Division',
      season: json['season'] ?? '2025-2026',
      standings: standingsList,
      fixtures: fixturesList,
      sourceUrl: json['source_url'],
    );
  }
}
