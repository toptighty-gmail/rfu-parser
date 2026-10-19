/// One division (league, merit table, cup round, international series...) in
/// a season's catalogue, from the `divisions` table with its competition.
class DivisionCatalogEntry {
  final String name;
  final int? rfuDivisionId;
  final int? rfuCompetitionId;

  /// e.g. "RFU Men's Community Cup"; empty when the competition is unknown.
  final String competition;

  /// Display group from competitions.category: "Elite", "Internationals",
  /// "Men's Leagues", "Merit Tables", "Women's Leagues", "Cups",
  /// "Women's Cups"; empty when unknown.
  final String category;

  const DivisionCatalogEntry({
    required this.name,
    this.rfuDivisionId,
    this.rfuCompetitionId,
    this.competition = '',
    this.category = '',
  });

  /// Display order of the competition groups.
  static const List<String> categoryOrder = [
    'Elite',
    'Internationals',
    "Men's Leagues",
    'Merit Tables',
    "Women's Leagues",
    'Cups',
    "Women's Cups",
  ];

  /// Knockout competitions list their rounds in the order the RFU created
  /// them (Round 1 ... Final), which their division ids follow.
  bool get isKnockout => category == 'Cups' || category == "Women's Cups";

  factory DivisionCatalogEntry.fromJson(Map<String, dynamic> json) {
    final comp = json['competitions'];
    return DivisionCatalogEntry(
      name: (json['division_name'] ?? '').toString(),
      rfuDivisionId: int.tryParse((json['rfu_division_id'] ?? '').toString()),
      rfuCompetitionId: int.tryParse((json['rfu_competition_id'] ?? '').toString()),
      competition: comp is Map ? (comp['name'] ?? '').toString() : '',
      category: comp is Map ? (comp['category'] ?? '').toString() : '',
    );
  }
}
