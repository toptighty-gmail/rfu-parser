class StandingEntry {
  final int pos;
  final String teamName;
  final int? rfuTeamId;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int pointsFor;
  final int pointsAgainst;
  final int pointsDiff;
  final int tryBonus;
  final int lossBonus;
  final int pointsDeducted;
  final int points;
  final String? logoUrl;

  StandingEntry({
    required this.pos,
    required this.teamName,
    this.rfuTeamId,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.pointsDiff,
    required this.tryBonus,
    required this.lossBonus,
    required this.pointsDeducted,
    required this.points,
    this.logoUrl,
  });

  factory StandingEntry.fromJson(Map<String, dynamic> json) {
    return StandingEntry(
      pos: json['position'] ?? json['pos'] ?? 0,
      teamName: json['team_name'] ?? json['team'] ?? '',
      rfuTeamId: json['rfu_team_id'] != null ? int.tryParse(json['rfu_team_id'].toString()) : null,
      played: json['played'] ?? 0,
      won: json['won'] ?? 0,
      drawn: json['drawn'] ?? 0,
      lost: json['lost'] ?? 0,
      pointsFor: json['points_for'] ?? json['pf'] ?? 0,
      pointsAgainst: json['points_against'] ?? json['pa'] ?? 0,
      pointsDiff: json['points_diff'] ?? json['pd'] ?? 0,
      tryBonus: json['try_bonus'] ?? json['tb'] ?? 0,
      lossBonus: json['loss_bonus'] ?? json['lb'] ?? 0,
      pointsDeducted: json['points_deducted'] ?? json['pts_ded'] ?? 0,
      points: json['points'] ?? json['pts'] ?? 0,
      logoUrl: json['logo_url'],
    );
  }
}
