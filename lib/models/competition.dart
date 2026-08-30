class Competition {
  final int id;
  final String name;
  final String category;
  final bool isElite;
  final String season;

  Competition({
    required this.id,
    required this.name,
    this.category = 'Senior Mens',
    this.isElite = false,
    this.season = '2025-2026',
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    return Competition(
      id: int.tryParse(json['rfu_competition_id']?.toString() ?? json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? json['competition_name'] ?? 'RFU Competition',
      category: json['category'] ?? 'Senior Mens',
      isElite: json['is_elite'] == true || json['is_elite'] == 1,
      season: json['season'] ?? '2025-2026',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rfu_competition_id': id,
      'name': name,
      'category': category,
      'is_elite': isElite,
      'season': season,
    };
  }
}
