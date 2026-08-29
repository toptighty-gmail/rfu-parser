class Fixture {
  final String? id;
  final String date;
  final String dateIso;
  final String time;
  final String homeTeam;
  final String awayTeam;
  final int? homeScore;
  final int? awayScore;
  final String status;
  final String venue;
  final String competition;
  final String roundNum;
  final bool isCustom;
  final String? homeLogoUrl;
  final String? awayLogoUrl;

  Fixture({
    this.id,
    required this.date,
    required this.dateIso,
    required this.time,
    required this.homeTeam,
    required this.awayTeam,
    this.homeScore,
    this.awayScore,
    required this.status,
    required this.venue,
    required this.competition,
    required this.roundNum,
    this.isCustom = false,
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

    return Fixture(
      id: json['id']?.toString(),
      date: json['date'] ?? '',
      dateIso: json['date_iso'] ?? json['date'] ?? '',
      time: json['time'] ?? '15:00',
      homeTeam: json['home_team'] ?? '',
      awayTeam: json['away_team'] ?? '',
      homeScore: hScore,
      awayScore: aScore,
      status: json['status'] ?? (hScore != null && aScore != null ? 'Completed' : 'Scheduled'),
      venue: json['venue'] ?? json['notes'] ?? 'TBC',
      competition: json['competition'] ?? (isCustom ? 'Friendly' : 'League'),
      roundNum: json['round_num'] ?? (isCustom ? 'Friendly Matches' : 'Scheduled'),
      isCustom: isCustom,
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
      'home_score': homeScore,
      'away_score': awayScore,
      'status': status,
      'venue': venue,
      'competition': competition,
      'round_num': roundNum,
      'is_custom': isCustom,
    };
  }
}
