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

bool isWalkover(Fixture f) {
  final s = f.status.toLowerCase();
  return s == 'hwo' || s == 'awo';
}

bool isAbandoned(Fixture f) => f.status.toLowerCase() == 'abandoned';

/// Postponed matches are awaiting a new date, unlike a walkover or an
/// abandoned match (both settled outcomes) or "Scheduled" (still on for its
/// stated date). Not treated as completed, and not folded into "no result
/// reported" either - it has its own distinct display.
bool isPostponed(Fixture f) => f.status.toLowerCase() == 'postponed';

/// A fixture whose outcome is settled: a numeric score, a walkover, or an
/// abandoned match. Postponed and genuinely-upcoming fixtures are not.
bool isFixtureCompleted(Fixture f) {
  return f.status.toLowerCase() == 'completed' ||
      isWalkover(f) ||
      isAbandoned(f) ||
      (f.homeScore != null && f.awayScore != null);
}

/// The text to show in place of a numeric score: the real score when known,
/// "HWO"/"AWO" for a walkover, "ABANDONED"/"POSTPONED" for those outcomes
/// (RFU never publishes points for any of these), or a plain "v" for a
/// fixture that hasn't been played yet.
String fixtureScoreText(Fixture f) {
  if (isWalkover(f)) return f.status.toUpperCase();
  if (isAbandoned(f)) return 'ABANDONED';
  if (isPostponed(f)) return 'POSTPONED';
  if (isFixtureCompleted(f)) return '${f.homeScore ?? 0} - ${f.awayScore ?? 0}';
  return 'v';
}

/// True once a fixture's stated match date has passed - used to stop a stale
/// date (an unreported past match, or a postponed one still carrying its old
/// date) from being treated as "next up".
bool hasPastDate(Fixture f) => parseFixtureDate(f).isBefore(DateTime.now());

/// True when a fixture's match date has already passed but no result was ever
/// recorded (the RFU source itself never had a score for it - not a sync gap
/// we can fix by re-crawling). Distinct from "Scheduled", which should only
/// describe genuinely upcoming matches, and from "Postponed", which has its
/// own explicit label.
bool isPastUnreported(Fixture f) {
  if (isFixtureCompleted(f) || isPostponed(f)) return false;
  return hasPastDate(f);
}

/// Returns true if [date] falls within the RFU season window for [season]
/// (e.g. "2025-2026"). The window runs from 1 Jul of the start year through
/// 30 Jun of the following year, safely covering pre-season friendlies
/// through end-of-season fixtures. If [season] can't be parsed, returns
/// true so callers don't silently drop fixtures they can't classify.
bool isDateInSeason(DateTime date, String season) {
  final parts = season.split(RegExp(r'[-/]'));
  if (parts.isEmpty) return true;
  final startYear = int.tryParse(parts.first.trim());
  if (startYear == null) return true;
  final start = DateTime(startYear, 7, 1);
  final end = DateTime(startYear + 1, 6, 30, 23, 59, 59);
  return !date.isBefore(start) && !date.isAfter(end);
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

  // Eligible to be "next": not completed, and not carrying a past date -
  // covers both a past match whose result was never reported and a postponed
  // fixture still sitting on its original (now stale) date.
  bool isEligibleNext(Fixture f) => !isFixtureCompleted(f) && !hasPastDate(f);

  final isTeamFiltered = filterTeam != null && filterTeam.trim().isNotEmpty;
  if (isTeamFiltered) {
    final sorted = List<Fixture>.from(fixtures)..sort(compareFixturesChronologically);
    for (final f in sorted) {
      if (isEligibleNext(f)) return {f};
    }
    return {};
  }

  final Map<String, List<Fixture>> grouped = {};
  for (final f in fixtures) {
    grouped.putIfAbsent(_roundGroupKey(f), () => []).add(f);
  }
  if (grouped.isEmpty) return {};

  // Only consider rounds that still have at least one genuinely upcoming fixture.
  final eligibleEntries = grouped.entries.where((e) => e.value.any(isEligibleNext)).toList()
    ..sort((a, b) {
      final earliestA = a.value.map(parseFixtureDate).reduce((min, d) => d.isBefore(min) ? d : min);
      final earliestB = b.value.map(parseFixtureDate).reduce((min, d) => d.isBefore(min) ? d : min);
      final comp = earliestA.compareTo(earliestB);
      if (comp != 0) return comp;
      return _extractRoundNumber(a.key).compareTo(_extractRoundNumber(b.key));
    });
  if (eligibleEntries.isEmpty) return {};

  final earliestEntry = eligibleEntries.first;
  return earliestEntry.value.where(isEligibleNext).toSet();
}
