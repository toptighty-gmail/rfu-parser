/// One player's season totals for one team, from the
/// `player_season_appearances` view (lineups scraped by scripts/sync_lineups.py).
class PlayerSeasonAppearance {
  final String season;
  final int playerId;
  final String displayName;
  final bool nameWithheld;
  final int? teamId;
  final String teamName;

  /// Match-day squads named in (starts + bench).
  final int appearances;
  final int starts;

  /// Named as a replacement (S1, S2...). RFU lineups don't record whether
  /// they actually came on.
  final int bench;
  final DateTime? firstMatchDate;
  final DateTime? lastMatchDate;

  const PlayerSeasonAppearance({
    required this.season,
    required this.playerId,
    required this.displayName,
    required this.nameWithheld,
    required this.teamId,
    required this.teamName,
    required this.appearances,
    required this.starts,
    required this.bench,
    this.firstMatchDate,
    this.lastMatchDate,
  });

  factory PlayerSeasonAppearance.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
    DateTime? toDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return PlayerSeasonAppearance(
      season: json['season']?.toString() ?? '',
      playerId: toInt(json['rfu_player_id']),
      displayName: json['display_name']?.toString() ?? '',
      nameWithheld: json['name_withheld'] == true,
      teamId: json['rfu_team_id'] == null
          ? null
          : int.tryParse(json['rfu_team_id'].toString()),
      teamName: json['team_name']?.toString() ?? '',
      appearances: toInt(json['appearances']),
      starts: toInt(json['starts']),
      bench: toInt(json['bench']),
      firstMatchDate: toDate(json['first_match_date']),
      lastMatchDate: toDate(json['last_match_date']),
    );
  }

  /// The RFU's own player page (full match history, tries, points).
  String get rfuProfileUrl =>
      'https://www.englandrugby.com/fixtures-and-results/player-stats?playerId=$playerId';
}

/// A team that has synced lineups, from the `player_appearance_teams` view,
/// merged across the selected seasons.
class AppearanceTeam {
  final int teamId;
  final String teamName;

  /// Matches with a synced lineup, across [seasons].
  final int matches;
  final List<String> seasons;

  const AppearanceTeam({
    required this.teamId,
    required this.teamName,
    required this.matches,
    required this.seasons,
  });
}
