import '../services/rfu_team_registry.dart';

class Fixture {
  final String? id;
  final String date;
  final String dateIso;
  final String time;
  final String homeTeam;
  final String awayTeam;
  final int? homeTeamId;
  final int? awayTeamId;
  final int? homeScore;
  final int? awayScore;
  final String status;
  final String venue;
  final String competition;
  final String roundNum;
  final bool isCustom;
  final String? contextTeam;
  final int? rfuTeamId;
  final String? homeLogoUrl;
  final String? awayLogoUrl;

  Fixture({
    this.id,
    required this.date,
    required this.dateIso,
    required this.time,
    required this.homeTeam,
    required this.awayTeam,
    this.homeTeamId,
    this.awayTeamId,
    this.homeScore,
    this.awayScore,
    required this.status,
    required this.venue,
    required this.competition,
    required this.roundNum,
    this.isCustom = false,
    this.contextTeam,
    this.rfuTeamId,
    this.homeLogoUrl,
    this.awayLogoUrl,
  });

  factory Fixture.fromJson(Map<String, dynamic> json) {
    int? hScore = json['home_score'] != null ? int.tryParse(json['home_score'].toString()) : null;
    int? aScore = json['away_score'] != null ? int.tryParse(json['away_score'].toString()) : null;
    if (hScore == null && aScore == null && json['score'] != null) {
      final s = json['score'].toString().trim();
      if (s.contains('-')) {
        final parts = s.split('-');
        if (parts.length >= 2) {
          hScore = int.tryParse(parts[0].trim());
          aScore = int.tryParse(parts[1].trim());
        }
      }
    }

    final isCustom = json['is_custom'] == true || json['is_custom'] == 1;
    final comp = json['competition'] ??
        (json['division'] != null && json['division'].toString().toLowerCase().contains('cup')
            ? 'Cup Fixture'
            : (isCustom ? 'Friendly' : 'League'));
    final isCup = comp.toString().toLowerCase().contains('cup') ||
        (json['round_num'] != null && json['round_num'].toString().toLowerCase().contains('cup'));

    // Resolve context team and RFU Team ID
    String? ctxTeam = json['context_team']?.toString();
    int? teamId = json['rfu_team_id'] != null ? int.tryParse(json['rfu_team_id'].toString()) : null;
    int? hTeamId = json['home_team_id'] != null ? int.tryParse(json['home_team_id'].toString()) : null;
    int? aTeamId = json['away_team_id'] != null ? int.tryParse(json['away_team_id'].toString()) : null;

    final notesStr = (json['notes'] ?? json['venue'] ?? '').toString();
    if (ctxTeam == null && notesStr.contains('[Context:')) {
      final m = RegExp(r'\[Context:\s*([^\]]+)\]').firstMatch(notesStr);
      if (m != null) ctxTeam = m.group(1)?.trim();
    }
    if (teamId == null && notesStr.contains('[ID:')) {
      final m = RegExp(r'\[ID:\s*(\d+)\]').firstMatch(notesStr);
      if (m != null) teamId = int.tryParse(m.group(1)!);
    }

    final rawHome = json['home_team']?.toString() ?? '';
    final rawAway = json['away_team']?.toString() ?? '';
    final normHome = RfuTeamRegistry.normalizeTeamName(rawHome);
    final normAway = RfuTeamRegistry.normalizeTeamName(rawAway);
    final normCtx = ctxTeam != null ? RfuTeamRegistry.normalizeTeamName(ctxTeam) : null;

    // Auto-resolve RFU Team ID if not explicitly present
    teamId ??= RfuTeamRegistry.lookupTeamId(normCtx ?? (normHome.isNotEmpty ? normHome : normAway));
    hTeamId ??= RfuTeamRegistry.lookupTeamId(normHome);
    aTeamId ??= RfuTeamRegistry.lookupTeamId(normAway);

    return Fixture(
      id: json['id']?.toString(),
      date: json['date'] ?? '',
      dateIso: json['date_iso'] ?? json['date'] ?? '',
      time: json['time'] ?? '15:00',
      homeTeam: normHome,
      awayTeam: normAway,
      homeTeamId: hTeamId,
      awayTeamId: aTeamId,
      homeScore: hScore,
      awayScore: aScore,
      status: json['status'] ?? (hScore != null && aScore != null ? 'Completed' : 'Scheduled'),
      venue: json['venue'] ?? json['notes'] ?? 'TBC',
      competition: comp,
      roundNum: json['round_num'] ?? (isCustom ? (isCup ? 'Cup Matches' : 'Friendly Matches') : 'Scheduled'),
      isCustom: isCustom,
      contextTeam: normCtx,
      rfuTeamId: teamId,
      homeLogoUrl: json['home_logo_url'],
      awayLogoUrl: json['away_logo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'date_iso': dateIso,
      'time': time,
      'home_team': homeTeam,
      'away_team': awayTeam,
      if (homeTeamId != null) 'home_team_id': homeTeamId,
      if (awayTeamId != null) 'away_team_id': awayTeamId,
      'home_score': homeScore,
      'away_score': awayScore,
      'status': status,
      'venue': venue,
      'competition': competition,
      'round_num': roundNum,
      'is_custom': isCustom,
      if (contextTeam != null) 'context_team': contextTeam,
      if (rfuTeamId != null) 'rfu_team_id': rfuTeamId,
    };
  }
}
