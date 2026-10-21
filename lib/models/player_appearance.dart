/// Tries, conversions, drop goals, penalties and cards, from the "key match
/// events" on RFU match pages, credited to a player by name (an event whose
/// name matches no one, or several people, in the lineup isn't counted).
class ScoringStats {
  final int tries;
  final int conversions;
  final int dropGoals;
  final int penalties;
  final int yellowCards;
  final int redCards;

  const ScoringStats({
    this.tries = 0,
    this.conversions = 0,
    this.dropGoals = 0,
    this.penalties = 0,
    this.yellowCards = 0,
    this.redCards = 0,
  });

  static const zero = ScoringStats();

  /// Column headings for [values], with what each stands for.
  static const labels = ['T', 'C', 'D', 'P', 'Y', 'R'];
  static const names = [
    'Tries',
    'Conversions',
    'Drop goals',
    'Penalties',
    'Yellow cards',
    'Red cards',
  ];

  factory ScoringStats.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
    return ScoringStats(
      tries: toInt(json['tries']),
      conversions: toInt(json['conversions']),
      dropGoals: toInt(json['drop_goals']),
      penalties: toInt(json['penalties']),
      yellowCards: toInt(json['yellow_cards']),
      redCards: toInt(json['red_cards']),
    );
  }

  /// In [labels] order: T, C, D, P, Y, R.
  List<int> get values => [tries, conversions, dropGoals, penalties, yellowCards, redCards];

  bool get isEmpty => values.every((v) => v == 0);

  /// e.g. "2T 1C 1Y"; "" when there's nothing.
  String get summary => [
        for (var i = 0; i < labels.length; i++)
          if (values[i] > 0) '${values[i]}${labels[i]}',
      ].join(' ');

  ScoringStats operator +(ScoringStats other) => ScoringStats(
        tries: tries + other.tries,
        conversions: conversions + other.conversions,
        dropGoals: dropGoals + other.dropGoals,
        penalties: penalties + other.penalties,
        yellowCards: yellowCards + other.yellowCards,
        redCards: redCards + other.redCards,
      );

  static ScoringStats sum(Iterable<ScoringStats> all) => all.fold(zero, (a, b) => a + b);
}

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
  final ScoringStats stats;

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
    this.stats = ScoringStats.zero,
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
      stats: ScoringStats.fromJson(json),
    );
  }

  /// The RFU's own player page (full match history, tries, points).
  String get rfuProfileUrl =>
      'https://www.englandrugby.com/fixtures-and-results/player-stats?playerId=$playerId';
}

/// One match a player was named in, from `appearances` with its `matches` row.
class PlayerMatchAppearance {
  final String season;
  final DateTime? matchDate;
  final int? teamId;
  final String teamName;

  /// As on the match card: "1".."15" starting, "S1".."S8" bench.
  final String shirt;
  final bool isSubstitute;
  final String homeTeam;
  final String awayTeam;
  final int? homeScore;
  final int? awayScore;

  /// Whether the player's team was the home side.
  final bool isHome;
  final ScoringStats stats;

  const PlayerMatchAppearance({
    required this.season,
    required this.matchDate,
    required this.teamId,
    required this.teamName,
    required this.shirt,
    required this.isSubstitute,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.isHome,
    this.stats = ScoringStats.zero,
  });

  factory PlayerMatchAppearance.fromJson(Map<String, dynamic> json) {
    int? toInt(dynamic v) => v == null ? null : int.tryParse(v.toString());
    final match = Map<String, dynamic>.from(json['matches'] ?? const {});
    final teamId = toInt(json['rfu_team_id']);
    final teamName = json['team_name']?.toString() ?? '';
    final homeTeam = match['home_team']?.toString() ?? '';
    final homeId = toInt(match['home_team_id']);
    return PlayerMatchAppearance(
      season: json['season']?.toString() ?? '',
      matchDate: json['match_date'] == null
          ? null
          : DateTime.tryParse(json['match_date'].toString()),
      teamId: teamId,
      teamName: teamName,
      shirt: json['shirt']?.toString() ?? '',
      isSubstitute: json['is_substitute'] == true,
      homeTeam: homeTeam,
      awayTeam: match['away_team']?.toString() ?? '',
      homeScore: toInt(match['home_score']),
      awayScore: toInt(match['away_score']),
      isHome: (teamId != null && homeId != null)
          ? teamId == homeId
          : teamName.toLowerCase() == homeTeam.toLowerCase(),
      stats: ScoringStats.fromJson(json),
    );
  }

  String get opponent => isHome ? awayTeam : homeTeam;
  int? get teamScore => isHome ? homeScore : awayScore;
  int? get opponentScore => isHome ? awayScore : homeScore;

  /// "W", "L", "D", or "" when the score isn't known.
  String get result {
    final us = teamScore, them = opponentScore;
    if (us == null || them == null) return '';
    return us > them ? 'W' : (us < them ? 'L' : 'D');
  }
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
