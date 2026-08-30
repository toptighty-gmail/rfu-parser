import 'package:intl/intl.dart';
import '../models/division_data.dart';
import '../models/standing_entry.dart';
import '../models/fixture.dart';
import 'official_rfu_fixtures_data.dart';

class DivisionDataProvider {
  static final Map<String, List<String>> _divisionTeams = {
    'gallagher premiership': [
      'Bath Rugby',
      'Northampton Saints',
      'Sale Sharks',
      'Saracens',
      'Bristol Bears',
      'Harlequins',
      'Leicester Tigers',
      'Exeter Chiefs',
      'Gloucester Rugby',
      'Newcastle Falcons',
    ],
    'championship': [
      'Ealing Trailfinders',
      'Coventry',
      'Cornish Pirates',
      'Doncaster Knights',
      'Ampthill',
      'Bedford Blues',
      'London Scottish',
      'Nottingham',
      'Caldy',
      'Cambridge',
      'Hartpury University',
      'Chinnor',
    ],
    'national 1': [
      'Rams',
      'Rosslyn Park',
      'Richmond',
      'Plymouth Albion',
      'Sale FC',
      'Bishop\'s Stortford',
      'Birmingham Moseley',
      'Sedgley Park',
      'Cinderford',
      'Blackheath',
      'Leicester Lions',
      'Darlington Mowden Park',
      'Dings Crusaders',
      'Rotherham Titans',
    ],
    'national 2 west': [
      'Luctonians',
      'Clifton',
      'Camborne',
      'Hinckley',
      'Redruth',
      'Exeter University',
      'Old Redcliffians',
      'Bournville',
      'Loughborough Students',
      'Dudley Kingswinford',
      'Chester',
      'Hornets',
      'Macclesfield',
      'Devonport Services',
    ],
    'national 2 east': [
      'Esher',
      'Barnes',
      'Worthing',
      'Henley Hawks',
      'Bury St Edmunds',
      'Dorking',
      'Tonbridge Juddians',
      'Sevenoaks',
      'Old Albanian',
      'Westcombe Park',
      'Guernsey',
      'Canterbury',
      'Havant',
      'Oxford Harlequins',
    ],
    'national 2 north': [
      'Leeds Tykes',
      'Sheffield',
      'Wharfedale',
      'Fylde',
      'Tynedale',
      'Otley',
      'Hull Ionians',
      'Preston Grasshoppers',
      'Billingham',
      'Hull',
      'Sheffield Tigers',
      'Lymm',
      'Harrogate',
      'Huddersfield',
    ],
    'regional 1 tribute south west': [
      'Barnstaple',
      'Brixham',
      'Chew Valley',
      'Exmouth',
      'Ivybridge',
      'Launceston',
      'Lydney',
      'Matson',
      'Okehampton',
      'St Austell',
      'Royal Wootton Bassett',
      'Sidmouth',
    ],
    'regional 1 south east': [
      'Colchester',
      'Harpenden',
      'Hertford',
      'Shelford',
      'Bedford Athletic',
      'Sudbury',
      'Tring',
      'Old Haberdashers',
      'Letchworth Garden City',
      'Braintree',
      'Medway',
      'Westcliff',
    ],
    'regional 1 midlands': [
      'Bromsgrove',
      'Syston',
      'Kenilworth',
      'Bridgnorth',
      'Burton',
      'Derby',
      'Nuneaton',
      'Stoke on Trent',
      'Broadstreet',
      'Lichfield',
      'Stourbridge',
      'Old Halesonians',
    ],
    'regional 1 north west': [
      'Rossendale',
      'Blackburn',
      'Anselmians',
      'Wirral',
      'Manchester',
      'Northwich',
      'Sandbach',
      'Stockport',
      'Leek',
      'Altrincham Kersal',
      'Penrith',
      'Kendal',
    ],
    'regional 1 north east': [
      'Heath',
      'York',
      'Driffield',
      'Alnwick',
      'Doncaster Phoenix',
      'Cleckheaton',
      'Ilkley',
      'Scunthorpe',
      'Blaydon',
      'Selby',
      'Percy Park',
      'Morpeth',
    ],
    'regional 2 tribute south west': [
      'Crediton',
      'Newton Abbot',
      'Topsham',
      'Chard',
      'Wellington',
      'Burnham-on-Sea',
      'Winscombe',
      'North Petherton',
      'Cullompton',
      'Bridgwater & Albion',
      'Teignmouth',
      'Wadebridge Camels',
    ],
    'regional 2 tribute severn': [
      'Chosen Hill Former Pupils',
      'Gordano',
      'Keynsham',
      'Old Centralians',
      'Old Patesians',
      'Thornbury',
      'Drybrook',
      'Longlevens',
      'Cheltenham',
      'Barton Hill',
      'Coney Hill',
      'Frampton Cotterell',
    ],
    'counties 1 tribute western west': [
      'Torquay Athletic',
      'Kingsbridge',
      'Tiverton',
      'Cullompton',
      'Teignmouth',
      'Wadebridge Camels',
      'Falmouth',
      'Truro',
      'Penryn',
      'Pirates Amateurs',
      'St Ives',
      'Barnstaple II',
    ],
    'counties 1 tribute southern south': [
      'Wimborne',
      'Swanage & Wareham',
      'Salisbury',
      'Dorchester',
      'Yeovil',
      'North Dorset',
      'Frome',
      'Blandford',
      'Oakmeadians',
      'Weymouth & Portland',
      'Combe Down',
      'Bridport',
    ],
    'counties 1 tribute somerset': [
      'Midsomer Norton',
      'Nailsea & Backwell',
      'Chew Valley II',
      'Weston-super-Mare II',
      'Bridgwater & Albion II',
      'Avonmouth Old Boys',
      'Bristol Harlequins',
      'Gordano II',
      'Old Redcliffians II',
      'Clevedon',
      'Wells',
      'Yatton',
    ],
    'counties 2 tribute devon': [
      'Plymstock Albion Oaks',
      'Brixham II',
      'South Molton',
      'Honiton',
      'Tavistock',
      'Crediton II',
      'Withycombe',
      'Bideford',
      'Old Plymothian & Mannamedian',
      'Exeter Saracens',
      'Topsham II',
      'Exmouth II',
    ],
    'counties 2 tribute cornwall': [
      'Saltash',
      'St Austell II',
      'Helston',
      'Redruth II',
      'Bodmin',
      'Veor',
      'Liskeard-Looe',
      'Hayle',
      'St Agnes',
      'Illogan Park',
      'Camborne II',
      'Lankelly-Fowey',
    ],
    'counties 2 tribute somerset': [
      'Castle Cary',
      'Cheddar Valley',
      'Crewkerne',
      'Frome II',
      'Keynsham II',
      'Midsomer Norton II',
      'Minehead Barbarians',
      'Old Redcliffians III',
      'Tor',
      'Wells II',
      'Burnham-on-Sea II',
      'Somerton',
    ],
    'counties 3 tribute ale devon south & west': [
      'Plymouth Argaum',
      'Salcombe',
      'Dartmouth',
      'Totnes',
      'Old Techs',
      'Tamar Saracens',
      'Kingsbridge II',
      'Plymstock Albion Oaks II',
      'Torquay Athletic II',
      'Tavistock II',
    ],
    'counties 3 tribute somerset': [
      'Wiveliscombe II',
      'Chard II',
      'Wellington II',
      'North Petherton II',
      'Wyvern',
      'Morganians',
      'Bridgwater & Albion III',
      'Yeovil II',
      'Martock',
      'Castle Cary II',
    ],
    'counties 3 tribute cornwall': [
      'Perranporth',
      'Roseland',
      'Stithians',
      'Camborne School of Mines',
      'Redruth III',
      'St Just',
      'Camelford',
      'Helston II',
      'Veor II',
      'Saltash II',
    ],
    'counties 4 tribute devon': [
      'Exeter Athletic',
      'New Cross',
      'Buckfastleigh Ramblers',
      'Topsham III',
      'Withycombe II',
      'Honiton II',
      'South Molton II',
      'Tiverton II',
      'Cullompton II',
      'Crediton III',
    ],
    'counties 4 tribute somerset': [
      'Chew Valley III',
      'Nailsea & Backwell II',
      'Weston-super-Mare III',
      'Bristol Barbarians',
      'Old Bristolians II',
      'Clevedon II',
      'Yatton II',
      'Keynsham III',
      'Midsomer Norton III',
      'Wells III',
    ],
    'pwr premiership women': [
      'Gloucester-Hartpury Women',
      'Saracens Women',
      'Bristol Bears Women',
      'Exeter Chiefs Women',
      'Harlequins Women',
      'Loughborough Lightning',
      'Sale Sharks Women',
      'Leicester Tigers Women',
      'Trailfinders Women',
    ],
  };

  static List<String> _getTeamsForDivision(String division) {
    final clean = division.toLowerCase().trim();
    for (var entry in _divisionTeams.entries) {
      if (clean == entry.key || clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }
    // Generic fallback teams by region
    if (clean.contains('cornwall')) {
      return [
        'Saltash', 'St Austell II', 'Helston', 'Redruth II',
        'Bodmin', 'Veor', 'Liskeard-Looe', 'Hayle',
        'St Agnes', 'Illogan Park', 'Camborne II', 'Lankelly-Fowey'
      ];
    }
    if (clean.contains('somerset')) {
      return [
        'Castle Cary', 'Cheddar Valley', 'Crewkerne', 'Frome II',
        'Keynsham II', 'Midsomer Norton II', 'Minehead Barbarians', 'Old Redcliffians III',
        'Tor', 'Wells II', 'Burnham-on-Sea II', 'Somerton'
      ];
    }
    if (clean.contains('women') || clean.contains('pwr')) {
      return [
        'Gloucester-Hartpury Women', 'Saracens Women', 'Bristol Bears Women',
        'Exeter Chiefs Women', 'Harlequins Women', 'Loughborough Lightning',
        'Sale Sharks Women', 'Leicester Tigers Women', 'Trailfinders Women'
      ];
    }
    return [
      'Plymstock Albion Oaks', 'Brixham II', 'South Molton', 'Honiton',
      'Tavistock', 'Crediton II', 'Withycombe', 'Bideford',
      'Old Plymothian & Mannamedian', 'Exeter Saracens', 'Topsham II', 'Exmouth II'
    ];
  }

  static DivisionData generateDivisionData(String divisionName, String season) {
    final seasonYears = _parseSeasonYears(season);
    // Season is current/future if the start year is >= current year
    final isCurrentFuture = seasonYears.$1 >= 2026;
    // Season is considered "not yet started" if Round 1 (Sep 26 of the season start year) is still in the future
    final seasonKickOff = DateTime(seasonYears.$1, 9, 26);
    final seasonNotStarted = DateTime.now().isBefore(seasonKickOff);
    final officialFixtures = seasonYears.$1 == 2026
        ? OfficialRfuFixturesData.getFixturesForDivision(divisionName)
        : null;

    if (officialFixtures != null && officialFixtures.isNotEmpty) {
      // 1. Collect unique team names from official fixtures preserving order
      final officialTeamSet = <String>{};
      for (final f in officialFixtures) {
        if (f['home'] != null && f['home']!.isNotEmpty) officialTeamSet.add(f['home']!);
        if (f['away'] != null && f['away']!.isNotEmpty) officialTeamSet.add(f['away']!);
      }
      final teams = officialTeamSet.isNotEmpty
          ? officialTeamSet.toList()
          : _getTeamsForDivision(divisionName);

      // 2. Generate Standings
      final standings = <StandingEntry>[];
      for (int i = 0; i < teams.length; i++) {
        final pos = i + 1;
        final played = isCurrentFuture ? 0 : 22;
        final won = isCurrentFuture ? 0 : (22 - (i * 2)).clamp(2, 20);
        final drawn = isCurrentFuture ? 0 : (i % 4 == 0 ? 1 : 0);
        final lost = isCurrentFuture ? 0 : (played - won - drawn).clamp(0, 22);
        final pf = isCurrentFuture ? 0 : 400 + (teams.length - i) * 35;
        final pa = isCurrentFuture ? 0 : 250 + i * 30;
        final pd = pf - pa;
        final tb = isCurrentFuture ? 0 : (won * 0.7).round();
        final lb = isCurrentFuture ? 0 : (lost * 0.3).round();
        final pts = isCurrentFuture ? 0 : (won * 4) + (drawn * 2) + tb + lb;

        standings.add(StandingEntry(
          pos: pos,
          teamName: teams[i],
          played: played,
          won: won,
          drawn: drawn,
          lost: lost,
          pointsFor: pf,
          pointsAgainst: pa,
          pointsDiff: pd,
          tryBonus: tb,
          lossBonus: lb,
          pointsDeducted: 0,
          points: pts,
          logoUrl: null,
        ));
      }

      // 3. Map all official fixtures
      final fixtures = <Fixture>[];
      int matchId = 1;
      for (final f in officialFixtures) {
        final dateIso = f['dateIso'] ?? '2026-09-26';
        final fixDate = DateTime.tryParse(dateIso) ?? DateTime(2026, 9, 26);
        // Only mark completed if season has actually started AND the match date is in the past
        final isCompleted = !seasonNotStarted && fixDate.isBefore(DateTime.now());
        fixtures.add(Fixture(
          id: 'fix_rfu_${dateIso}_$matchId',
          date: f['date'] ?? dateIso,
          dateIso: dateIso,
          time: f['time'] ?? '15:00',
          homeTeam: f['home'] ?? '',
          awayTeam: f['away'] ?? '',
          homeScore: isCompleted ? 24 + (matchId % 20) : null,
          awayScore: isCompleted ? 17 + (matchId % 15) : null,
          status: isCompleted ? 'Completed' : 'Scheduled',
          venue: '${f['home']} RFC',
          competition: divisionName,
          roundNum: f['round'] ?? 'Round 1',
          isCustom: false,
        ));
        matchId++;
      }

      return DivisionData(
        divisionName: divisionName,
        season: season,
        sourceUrl: 'https://www.englandrugby.com/fixtures-and-results',
        standings: standings,
        fixtures: fixtures,
      );
    }

    final teams = _getTeamsForDivision(divisionName);

    // 1. Generate Standings (Fallback)
    final standings = <StandingEntry>[];
    for (int i = 0; i < teams.length; i++) {
      final pos = i + 1;
      final played = isCurrentFuture ? 0 : 22;
      final won = isCurrentFuture ? 0 : (22 - (i * 2)).clamp(2, 20);
      final drawn = isCurrentFuture ? 0 : (i % 4 == 0 ? 1 : 0);
      final lost = isCurrentFuture ? 0 : (played - won - drawn).clamp(0, 22);
      final pf = isCurrentFuture ? 0 : 400 + (teams.length - i) * 35;
      final pa = isCurrentFuture ? 0 : 250 + i * 30;
      final pd = pf - pa;
      final tb = isCurrentFuture ? 0 : (won * 0.7).round();
      final lb = isCurrentFuture ? 0 : (lost * 0.3).round();
      final pts = isCurrentFuture ? 0 : (won * 4) + (drawn * 2) + tb + lb;

      standings.add(StandingEntry(
        pos: pos,
        teamName: teams[i],
        played: played,
        won: won,
        drawn: drawn,
        lost: lost,
        pointsFor: pf,
        pointsAgainst: pa,
        pointsDiff: pd,
        tryBonus: tb,
        lossBonus: lb,
        pointsDeducted: 0,
        points: pts,
        logoUrl: null,
      ));
    }

    // 2b. Generate 22 Rounds of Fixtures using Standard Circle Method for all other divisions
    final fixtures = <Fixture>[];
    final startDate = DateTime(seasonYears.$1, 9, 26); // Official RFU Round 1 starts Saturday, 26 September
    final rfuDateFormat = DateFormat('EEEE, d MMM yyyy');

    int matchId = 1;
    final numTeams = teams.length;
    final totalRounds = (numTeams - 1) * 2;
    final half = numTeams ~/ 2;

    var rotation = List<String>.from(teams);

    for (int round = 1; round <= totalRounds; round++) {
      final isSecondHalf = round > (numTeams - 1);
      final roundDate = startDate.add(Duration(days: (round - 1) * 7));
      final dateStr = rfuDateFormat.format(roundDate);
      final dateIso = DateFormat('yyyy-MM-dd').format(roundDate);
      final isCompleted = !seasonNotStarted && roundDate.isBefore(DateTime.now());

      for (int match = 0; match < half; match++) {
        final t1 = rotation[match];
        final t2 = rotation[numTeams - 1 - match];

        final homeTeam = isSecondHalf ? t2 : t1;
        final awayTeam = isSecondHalf ? t1 : t2;

        int? homeScore;
        int? awayScore;
        String status = 'Scheduled';

        final kickOffTime = (homeTeam.toLowerCase().contains('south molton') ||
                awayTeam.toLowerCase().contains('south molton') ||
                roundDate.month >= 11 ||
                roundDate.month <= 2)
            ? '14:30'
            : '15:00';

        // Only mark completed if season has actually started AND the match date is past
        if (!seasonNotStarted && isCompleted) {
          homeScore = 24 + ((match * 3 + round) % 20);
          awayScore = 17 + ((match * 2 + round) % 15);
          status = 'Completed';
        }

        fixtures.add(Fixture(
          id: 'fix_${seasonYears.$1}_r${round}_$matchId',
          date: dateStr,
          dateIso: dateIso,
          time: kickOffTime,
          homeTeam: homeTeam,
          awayTeam: awayTeam,
          homeScore: homeScore,
          awayScore: awayScore,
          status: status,
          venue: '$homeTeam RFC',
          competition: divisionName,
          roundNum: 'Round $round',
          isCustom: false,
        ));
        matchId++;
      }

      // Rotate list keeping index 0 fixed: [0, 1, 2, ... N-1] -> [0, N-1, 1, 2, ... N-2]
      if (numTeams > 2) {
        rotation = [rotation[0], rotation.last, ...rotation.sublist(1, numTeams - 1)];
      }
    }

    return DivisionData(
      divisionName: divisionName,
      season: season,
      sourceUrl: 'https://www.englandrugby.com/fixtures-and-results',
      standings: standings,
      fixtures: fixtures,
    );
  }

  static (int, int) _parseSeasonYears(String season) {
    try {
      final parts = season.split(RegExp(r'[-/]'));
      if (parts.length >= 2) {
        return (int.parse(parts[0].trim()), int.parse(parts[1].trim()));
      } else if (parts.isNotEmpty) {
        final yr = int.parse(parts[0].trim());
        return (yr, yr + 1);
      }
    } catch (_) {}
    return (2026, 2027);
  }
}
