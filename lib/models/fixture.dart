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
    return Fixture(
      id: json['id']?.toString(),
      date: json['date'] ?? '',
      dateIso: json['date_iso'] ?? json['date'] ?? '',
      time: json['time'] ?? '15:00',
      homeTeam: json['home_team'] ?? '',
      awayTeam: json['away_team'] ?? '',
      homeScore: json['home_score'] != null ? int.tryParse(json['home_score'].toString()) : null,
      awayScore: json['away_score'] != null ? int.tryParse(json['away_score'].toString()) : null,
      status: json['status'] ?? 'Scheduled',
      venue: json['venue'] ?? 'TBC',
      competition: json['competition'] ?? 'League',
      roundNum: json['round_num'] ?? 'Scheduled',
      isCustom: json['is_custom'] == true || json['is_custom'] == 1,
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
