import 'package:intl/intl.dart';
import '../models/fixture.dart';

/// Parses a [Fixture]'s date across the various date string formats used by
/// import sources, falling back to `date_iso` when possible.
DateTime parseFixtureDate(Fixture f) {
  if (f.dateIso.isNotEmpty) {
    final dt = DateTime.tryParse(f.dateIso);
    if (dt != null) return dt;
  }
  var clean = f.date.replaceAll(RegExp(r'^[A-Za-z]+,\s*'), '').trim();
  // Remove ordinal suffixes like 20th -> 20, 1st -> 1, 2nd -> 2, 3rd -> 3
  clean = clean.replaceAll(RegExp(r'(\d+)(st|nd|rd|th)', caseSensitive: false), r'$1');

  for (final pattern in [
    'd MMM yyyy',
    'd MMMM yyyy',
    'MMMM d, yyyy',
    'dd/MM/yyyy',
    'd/M/yyyy',
    'd MMM',
  ]) {
    try {
      return DateFormat(pattern).parse(clean);
    } catch (_) {}
  }
  return DateTime(2099);
}

bool isFixtureCompleted(Fixture f) {
  return f.status.toLowerCase() == 'completed' || (f.homeScore != null && f.awayScore != null);
}

int compareFixturesChronologically(Fixture a, Fixture b) {
  final dateComp = parseFixtureDate(a).compareTo(parseFixtureDate(b));
  if (dateComp != 0) return dateComp;
  return a.time.compareTo(b.time);
}

String _roundGroupKey(Fixture f) {
  final isCup = f.competition.toLowerCase().contains('cup') || f.roundNum.toLowerCase().contains('cup');
  return f.isCustom
      ? (isCup ? (f.competition.isNotEmpty && f.competition != 'Cup Match' ? f.competition : 'Cup Matches') : 'Friendly Matches')
      : f.roundNum;
}

int _extractRoundNumber(String key) {
  final k = key.toLowerCase();
  if (k.contains('cup')) return -2;
  if (k.contains('friendly')) return -1;
  final m = RegExp(r'(\d+)').firstMatch(key);
  return m != null ? (int.tryParse(m.group(1)!) ?? 999) : 999;
}

/// Determines which fixtures should be flagged with the "NEXT MATCH" badge.
///
/// - When [filterTeam] is a non-empty team name, returns the single next
///   non-completed fixture for that team, chronologically.
/// - When [filterTeam] is null/empty (division-wide view), returns every
///   non-completed fixture belonging to the earliest round/group, so the
///   whole upcoming round is highlighted rather than just its first fixture.
Set<Fixture> computeNextFixtures(List<Fixture> fixtures, {String? filterTeam}) {
  if (fixtures.isEmpty) return {};

  final isTeamFiltered = filterTeam != null && filterTeam.trim().isNotEmpty;
  if (isTeamFiltered) {
    final sorted = List<Fixture>.from(fixtures)..sort(compareFixturesChronologically);
    for (final f in sorted) {
      if (!isFixtureCompleted(f)) return {f};
    }
    return {};
  }

  final Map<String, List<Fixture>> grouped = {};
  for (final f in fixtures) {
    grouped.putIfAbsent(_roundGroupKey(f), () => []).add(f);
  }
  if (grouped.isEmpty) return {};

  final sortedEntries = grouped.entries.toList()
    ..sort((a, b) {
      final earliestA = a.value.map(parseFixtureDate).reduce((min, d) => d.isBefore(min) ? d : min);
      final earliestB = b.value.map(parseFixtureDate).reduce((min, d) => d.isBefore(min) ? d : min);
      final comp = earliestA.compareTo(earliestB);
      if (comp != 0) return comp;
      return _extractRoundNumber(a.key).compareTo(_extractRoundNumber(b.key));
    });

  final earliestEntry = sortedEntries.first;
  return earliestEntry.value.where((f) => !isFixtureCompleted(f)).toSet();
}
