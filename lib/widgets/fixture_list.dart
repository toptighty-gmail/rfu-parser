import 'package:flutter/material.dart';
import '../models/fixture.dart';
import '../theme/app_theme.dart';
import 'fixture_card.dart';

class FixtureList extends StatelessWidget {
  final List<Fixture> fixtures;
  final bool isAdmin;
  final String? filterTeam;
  final String? Function(String teamName)? logoProvider;
  final VoidCallback? onClearTeamFilter;
  final Function(Fixture)? onEditFixture;
  final Function(Fixture)? onDeleteFixture;

  const FixtureList({
    super.key,
    required this.fixtures,
    this.isAdmin = false,
    this.filterTeam,
    this.logoProvider,
    this.onClearTeamFilter,
    this.onEditFixture,
    this.onDeleteFixture,
  });

  @override
  Widget build(BuildContext context) {
    final cleanFilter = filterTeam?.trim().toLowerCase();
    final isTeamFiltered = cleanFilter != null && cleanFilter.isNotEmpty;

    final activeFixtures = isTeamFiltered
        ? fixtures.where((f) {
            return f.homeTeam.toLowerCase().contains(cleanFilter) ||
                f.awayTeam.toLowerCase().contains(cleanFilter);
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

    // When viewing single team fixtures, render a unified sleek schedule list
    if (isTeamFiltered) {
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
                        'FIXTURE SCHEDULE FOR "${filterTeam!.trim().toUpperCase()}" (${activeFixtures.length} MATCHES)',
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
                            Text('Show All', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            ...activeFixtures.map((f) => FixtureCard(
                  fixture: f,
                  isAdmin: isAdmin,
                  filterTeam: filterTeam,
                  logoProvider: logoProvider,
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
      final key = f.isCustom ? 'Friendly Matches' : f.roundNum;
      grouped.putIfAbsent(key, () => []).add(f);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...grouped.entries.map((entry) {
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
                      const Icon(Icons.sports_rugby, color: AppTheme.goldAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          fontSize: 13,
                          color: AppTheme.goldAccent,
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
