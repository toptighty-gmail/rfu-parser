import 'package:flutter/material.dart';
import '../models/fixture.dart';
import '../theme/app_theme.dart';
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
            // For custom fixtures (e.g. Friendlies / Cup entries entered in admin mode)
            if (f.isCustom) {
              if (f.contextTeam != null && isExactTeamMatch(f.contextTeam!, cleanFilter)) return true;
              if (isExactTeamMatch(f.homeTeam, cleanFilter) || isExactTeamMatch(f.awayTeam, cleanFilter)) return true;
              final cleanLower = cleanFilter.toLowerCase();
              final baseWords = cleanLower.split(' ').where((w) => w.length > 3 && !['club', 'rugby'].contains(w)).toList();
              for (var w in baseWords) {
                if (f.homeTeam.toLowerCase().contains(w) || f.awayTeam.toLowerCase().contains(w)) return true;
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
            const SizedBox(height: 12),
            Text(
              isTeamFiltered
                  ? 'No fixtures found for "${filterTeam!.trim()}" in this selection.'
                  : 'No fixtures available for this selection.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            if (isTeamFiltered && onClearTeamFilter != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.goldAccent,
                  side: const BorderSide(color: AppTheme.goldAccent),
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

    // When viewing single team fixtures, render a unified sleek schedule list
    if (isTeamFiltered) {
      final sortedTeamFixtures = List<Fixture>.from(activeFixtures)
        ..sort((a, b) {
          final rA = extractRoundNumber(a.roundNum);
          final rB = extractRoundNumber(b.roundNum);
          if (rA != rB) return rA.compareTo(rB);
          return a.dateIso.compareTo(b.dateIso);
        });

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
                      const Icon(Icons.calendar_month, color: AppTheme.goldAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'FIXTURE SCHEDULE FOR "${filterTeam!.trim().toUpperCase()}" (${sortedTeamFixtures.length} MATCHES)',
                        style: const TextStyle(
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
                      child: const Padding(
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

    // Group fixtures by round or match category for full division view
    final Map<String, List<Fixture>> grouped = {};
    for (var f in activeFixtures) {
      final isCup = f.competition.toLowerCase().contains('cup') || f.roundNum.toLowerCase().contains('cup');
      final key = f.isCustom
          ? (isCup ? (f.competition.isNotEmpty && f.competition != 'Cup Match' ? f.competition : 'Cup Matches') : 'Friendly Matches')
          : f.roundNum;
      grouped.putIfAbsent(key, () => []).add(f);
    }

    // Sort round entries in strict chronological order (Cup, Friendly, Round 1, Round 2, ... Round 22)
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final rA = extractRoundNumber(a.key);
        final rB = extractRoundNumber(b.key);
        if (rA != rB) return rA.compareTo(rB);
        return a.key.compareTo(b.key);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...sortedEntries.map((entry) {
          final isCupSection = entry.key.toLowerCase().contains('cup');
          final headerColor = isCupSection ? AppTheme.emeraldAccent : AppTheme.goldAccent;

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

                ...entry.value.map((f) => FixtureCard(
                      fixture: f,
                      isAdmin: isAdmin,
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
