import 'package:flutter/material.dart';
import '../models/fixture.dart';
import '../theme/app_theme.dart';
import '../services/rfu_team_registry.dart';
import '../utils/fixtures_util.dart' as fixtures_util;
import 'fixture_card.dart';

class FixtureList extends StatelessWidget {
  final List<Fixture> fixtures;
  final bool isAdmin;
  final String? filterTeam;
  final String? Function(String teamName)? logoProvider;
  final ValueChanged<String>? onTeamSelected;
  final VoidCallback? onClearTeamFilter;
  final Function(Fixture)? onEditFixture;
  final Function(Fixture)? onDeleteFixture;

  const FixtureList({
    super.key,
    required this.fixtures,
    this.isAdmin = false,
    this.filterTeam,
    this.logoProvider,
    this.onTeamSelected,
    this.onClearTeamFilter,
    this.onEditFixture,
    this.onDeleteFixture,
  });

  static DateTime parseFixtureDate(Fixture f) => fixtures_util.parseFixtureDate(f);

  static bool isExactTeamMatch(String fixtureTeam, String? filter) {
    if (filter == null || filter.trim().isEmpty) return false;
    final ft = fixtureTeam.trim().toLowerCase();
    final qt = filter.trim().toLowerCase();
    if (ft == qt) return true;

    // Strict suffix check (II, III, IV, 2nd, 3rd, 4th)
    final ftHasII = RegExp(r'\b(ii|2nd|extra)\b').hasMatch(ft);
    final qtHasII = RegExp(r'\b(ii|2nd|extra)\b').hasMatch(qt);
    if (ftHasII != qtHasII) return false;

    final ftHasIII = RegExp(r'\b(iii|3rd)\b').hasMatch(ft);
    final qtHasIII = RegExp(r'\b(iii|3rd)\b').hasMatch(qt);
    if (ftHasIII != qtHasIII) return false;

    final ftHasIV = RegExp(r'\b(iv|4th)\b').hasMatch(ft);
    final qtHasIV = RegExp(r'\b(iv|4th)\b').hasMatch(qt);
    if (ftHasIV != qtHasIV) return false;

    // Base name normalization (strip RFC, Club, XV)
    String normalizeBase(String s) {
      return s.replaceAll(RegExp(r'\b(rfc|rugby club|club|xv)\b', caseSensitive: false), '').trim();
    }

    final baseFt = normalizeBase(ft);
    final baseQt = normalizeBase(qt);
    return baseFt == baseQt || baseFt.contains(baseQt) || baseQt.contains(baseFt);
  }

  @override
  Widget build(BuildContext context) {
    final cleanFilter = filterTeam?.trim();
    final isTeamFiltered = cleanFilter != null && cleanFilter.isNotEmpty;

    final activeFixtures = isTeamFiltered
        ? fixtures.where((f) {
            // For custom fixtures (e.g. Friendlies / Cup entries):
            if (f.isCustom) {
              final targetTeamId = RfuTeamRegistry.lookupTeamId(cleanFilter.toLowerCase());
              if (targetTeamId != null && f.rfuTeamId != null) {
                return f.rfuTeamId == targetTeamId;
              }
              if (f.contextTeam != null && f.contextTeam!.trim().isNotEmpty) {
                return isExactTeamMatch(f.contextTeam!, cleanFilter);
              }
            }
            return isExactTeamMatch(f.homeTeam, cleanFilter) || isExactTeamMatch(f.awayTeam, cleanFilter);
          }).toList()
        : fixtures;

    if (activeFixtures.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: AppTheme.glassBoxDecoration(),
        child: Column(
          children: [
            Icon(isTeamFiltered ? Icons.search_off : Icons.event_busy, color: AppTheme.goldAccent, size: 36),
            SizedBox(height: 12),
            Text(
              isTeamFiltered
                  ? 'No fixtures found for "${filterTeam!.trim()}" in this selection.'
                  : 'No fixtures available for this selection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            if (isTeamFiltered && onClearTeamFilter != null) ...[
              SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.goldAccent,
                  side: BorderSide(color: AppTheme.goldAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Show All Division Fixtures'),
                onPressed: onClearTeamFilter,
              ),
            ],
          ],
        ),
      );
    }

    int extractRoundNumber(String key) {
      final k = key.toLowerCase();
      if (k.contains('cup')) return -2;
      if (k.contains('friendly')) return -1;
      final m = RegExp(r'(\d+)').firstMatch(key);
      return m != null ? (int.tryParse(m.group(1)!) ?? 999) : 999;
    }

    // When viewing single team fixtures, render a unified sleek schedule list strictly in CHRONOLOGICAL order
    if (isTeamFiltered) {
      final sortedTeamFixtures = List<Fixture>.from(activeFixtures)
        ..sort((a, b) {
          final dtA = parseFixtureDate(a);
          final dtB = parseFixtureDate(b);
          final dateComp = dtA.compareTo(dtB);
          if (dateComp != 0) return dateComp;
          return a.time.compareTo(b.time);
        });

      // Calculate next fixture for this team
      final nextTeamFixtures = fixtures_util.computeNextFixtures(sortedTeamFixtures, filterTeam: filterTeam);

      return Container(
        decoration: AppTheme.glassBoxDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.goldAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_month, color: AppTheme.goldAccent, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'CHRONOLOGICAL SCHEDULE FOR "${filterTeam!.trim().toUpperCase()}" (${sortedTeamFixtures.length} MATCHES)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: AppTheme.goldAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  if (onClearTeamFilter != null)
                    InkWell(
                      onTap: onClearTeamFilter,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.close, size: 13, color: AppTheme.textMuted),
                            SizedBox(width: 4),
                            Text('Clear', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            ...sortedTeamFixtures.map((f) => FixtureCard(
                  fixture: f,
                  isAdmin: isAdmin,
                  isNextFixture: nextTeamFixtures.contains(f),
                  filterTeam: filterTeam,
                  logoProvider: logoProvider,
                  onTeamSelected: onTeamSelected,
                  onEdit: onEditFixture,
                  onDelete: onDeleteFixture,
                )),
          ],
        ),
      );
    }

    // Division-only view: mark all non-completed fixtures in the earliest round as NEXT UP.
    final Set<Fixture> divisionNextFixtures = fixtures_util.computeNextFixtures(activeFixtures);

    // Group fixtures by round or match category for full division view
    final Map<String, List<Fixture>> grouped = {};
    for (var f in activeFixtures) {
      final isCup = f.competition.toLowerCase().contains('cup') || f.roundNum.toLowerCase().contains('cup');
      final key = f.isCustom
          ? (isCup ? (f.competition.isNotEmpty && f.competition != 'Cup Match' ? f.competition : 'Cup Matches') : 'Friendly Matches')
          : f.roundNum;
      grouped.putIfAbsent(key, () => []).add(f);
    }

    // Sort round entries chronologically by the earliest match date in each round
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final earliestA = a.value.map(parseFixtureDate).reduce((min, d) => d.isBefore(min) ? d : min);
        final earliestB = b.value.map(parseFixtureDate).reduce((min, d) => d.isBefore(min) ? d : min);
        final comp = earliestA.compareTo(earliestB);
        if (comp != 0) return comp;
        return extractRoundNumber(a.key).compareTo(extractRoundNumber(b.key));
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...sortedEntries.map((entry) {
          final isCupSection = entry.key.toLowerCase().contains('cup');
          final headerColor = isCupSection ? AppTheme.emeraldAccent : AppTheme.goldAccent;

          // Sort matches inside each round by date & kickoff time
          final sortedMatchesInRound = List<Fixture>.from(entry.value)
            ..sort((a, b) {
              final dtA = parseFixtureDate(a);
              final dtB = parseFixtureDate(b);
              final dateComp = dtA.compareTo(dtB);
              if (dateComp != 0) return dateComp;
              return a.time.compareTo(b.time);
            });

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: AppTheme.glassBoxDecoration(),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Round Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4),
                  child: Row(
                    children: [
                      Icon(
                        isCupSection ? Icons.emoji_events : Icons.sports_rugby,
                        color: headerColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.key.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          fontSize: 13,
                          color: headerColor,
                        ),
                      ),
                    ],
                  ),
                ),

                ...sortedMatchesInRound.map((f) => FixtureCard(
                      fixture: f,
                      isAdmin: isAdmin,
                      isNextFixture: divisionNextFixtures.contains(f),
                      filterTeam: filterTeam,
                      logoProvider: logoProvider,
                      onTeamSelected: onTeamSelected,
                      onEdit: onEditFixture,
                      onDelete: onDeleteFixture,
                    )),
              ],
            ),
          );
        }),
      ],
    );
  }
}
