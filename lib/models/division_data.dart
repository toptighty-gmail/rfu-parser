import 'fixture.dart';
import 'standing_entry.dart';

class DivisionData {
  final String divisionName;
  final String season;
  final int? rfuCompetitionId;
  final int? rfuDivisionId;
  final int? tierLevel;
  final String? region;
  final List<StandingEntry> standings;
  final List<Fixture> fixtures;
  final String? sourceUrl;
  /// True when data was generated offline (not from Supabase or live RFU crawl).
  /// Offline-generated data must NEVER be persisted to Supabase.
  final bool isOfflineGenerated;

  DivisionData({
    required this.divisionName,
    required this.season,
    this.rfuCompetitionId,
    this.rfuDivisionId,
    this.tierLevel,
    this.region,
    required this.standings,
    required this.fixtures,
    this.sourceUrl,
    this.isOfflineGenerated = false,
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
      rfuCompetitionId: json['rfu_competition_id'] != null ? int.tryParse(json['rfu_competition_id'].toString()) : null,
      rfuDivisionId: json['rfu_division_id'] != null ? int.tryParse(json['rfu_division_id'].toString()) : null,
      tierLevel: json['tier_level'] != null ? int.tryParse(json['tier_level'].toString()) : null,
      region: json['region']?.toString(),
      standings: standingsList,
      fixtures: fixturesList,
      sourceUrl: json['source_url'],
      isOfflineGenerated: false, // Data from DB is never offline-generated
    );
  }
}
