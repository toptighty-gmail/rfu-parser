import 'package:flutter/material.dart';
import '../models/division_data.dart';
import '../models/fixture.dart';
import '../models/standing_entry.dart';
import '../theme/app_theme.dart';

class BookletPrintView extends StatelessWidget {
  final DivisionData divisionData;
  final String? filterTeam;
  final Map<String, String> customLogosMap;

  const BookletPrintView({
    super.key,
    required this.divisionData,
    this.filterTeam,
    this.customLogosMap = const {},
  });

  String? _resolveLogo(String teamName, String? defaultLogoUrl) {
    if (defaultLogoUrl != null && defaultLogoUrl.trim().isNotEmpty) {
      return defaultLogoUrl.trim();
    }
    final clean = teamName.trim().toLowerCase();
    if (customLogosMap.containsKey(clean)) {
      return customLogosMap[clean];
    }
    for (var s in divisionData.standings) {
      if (s.teamName.trim().toLowerCase() == clean && s.logoUrl != null && s.logoUrl!.isNotEmpty) {
        return s.logoUrl;
      }
    }
    for (var s in divisionData.standings) {
      if ((s.teamName.toLowerCase().contains(clean) || clean.contains(s.teamName.toLowerCase())) &&
          s.logoUrl != null &&
          s.logoUrl!.isNotEmpty) {
        return s.logoUrl;
      }
    }
    return null;
  }

  Widget _buildTeamLogo(String teamName, String? directLogoUrl, {double size = 22}) {
    final logoUrl = _resolveLogo(teamName, directLogoUrl);
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.shield, size: size - 4, color: Colors.grey.shade400),
        ),
      );
    }
    return Icon(Icons.shield, size: size - 4, color: Colors.grey.shade400);
  }

  @override
  Widget build(BuildContext context) {
    final cleanFilter = filterTeam?.trim().toLowerCase();
    final isTeamFiltered = cleanFilter != null && cleanFilter.isNotEmpty;

    final activeFixtures = isTeamFiltered
        ? divisionData.fixtures.where((f) {
            return f.homeTeam.toLowerCase().contains(cleanFilter) ||
                f.awayTeam.toLowerCase().contains(cleanFilter);
          }).toList()
        : divisionData.fixtures;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 1,
        title: Text(
          isTeamFiltered
              ? 'A4 Print: ${filterTeam!.trim().toUpperCase()}'
              : 'A4 Print: ${divisionData.divisionName}',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: AppTheme.goldAccent),
            tooltip: 'Print Page (Ctrl+P / Cmd+P)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Press Ctrl+P (or Cmd+P on Mac) in your browser to print this document.'),
                  backgroundColor: AppTheme.emeraldAccent,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Document Header Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                divisionData.divisionName.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isTeamFiltered
                                    ? 'TEAM CONTEXT: ${filterTeam!.trim().toUpperCase()}  •  SEASON: ${divisionData.season}'
                                    : 'OFFICIAL LEAGUE & FIXTURE SCHEDULE  •  SEASON: ${divisionData.season}',
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: const Text(
                            'RFU OFFICIAL',
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // SECTION 1: LEAGUE TABLE STANDINGS
                  _buildSectionHeader('1. LEAGUE TABLE STANDINGS', Icons.table_chart),
                  const SizedBox(height: 12),
                  _buildPrintStandingsTable(divisionData.standings, filterTeam),

                  const SizedBox(height: 36),

                  // PAGE BREAK DIVIDER
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFF94A3B8), thickness: 1.5)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Text(
                              'PAGE BREAK  •  FIXTURES & RESULTS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFF94A3B8), thickness: 1.5)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SECTION 2: FIXTURES & RESULTS
                  _buildSectionHeader(
                    isTeamFiltered
                        ? '2. FIXTURES & RESULTS — ${filterTeam!.trim().toUpperCase()} (${activeFixtures.length} MATCHES)'
                        : '2. FIXTURES & RESULTS — ALL ROUNDS (${activeFixtures.length} MATCHES)',
                    Icons.event,
                  ),
                  const SizedBox(height: 12),
                  _buildPrintFixtures(activeFixtures, filterTeam),

                  const SizedBox(height: 32),

                  // Footer
                  const Center(
                    child: Text(
                      'Generated by RFU Hub • Official England Rugby League Data',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFB45309), size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPrintStandingsTable(List<StandingEntry> standings, String? highlightTeam) {
    final cleanHighlight = highlightTeam?.trim().toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(36), // Pos
          1: FlexColumnWidth(4),   // Team + Logo
          2: FixedColumnWidth(34), // P
          3: FixedColumnWidth(34), // W
          4: FixedColumnWidth(34), // D
          5: FixedColumnWidth(34), // L
          6: FixedColumnWidth(40), // F
          7: FixedColumnWidth(40), // A
          8: FixedColumnWidth(42), // Diff
          9: FixedColumnWidth(34), // TB
          10: FixedColumnWidth(34),// LB
          11: FixedColumnWidth(44),// Pts
        },
        children: [
          // Table Header
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
            ),
            children: [
              _buildHeaderCell('#', align: TextAlign.center),
              _buildHeaderCell('TEAM'),
              _buildHeaderCell('P'),
              _buildHeaderCell('W'),
              _buildHeaderCell('D'),
              _buildHeaderCell('L'),
              _buildHeaderCell('F'),
              _buildHeaderCell('A'),
              _buildHeaderCell('DIFF'),
              _buildHeaderCell('TB'),
              _buildHeaderCell('LB'),
              _buildHeaderCell('PTS', align: TextAlign.center, isHighlight: true),
            ],
          ),

          // Data Rows
          ...standings.asMap().entries.map((entry) {
            final index = entry.key;
            final s = entry.value;
            final isMatched = cleanHighlight != null &&
                cleanHighlight.isNotEmpty &&
                s.teamName.toLowerCase().contains(cleanHighlight);

            final isEven = index % 2 == 0;
            final rowBg = isMatched
                ? const Color(0xFFFEF3C7) // Light yellow highlight for matched team
                : (isEven ? Colors.white : const Color(0xFFF9FAFB));

            return TableRow(
              decoration: BoxDecoration(
                color: rowBg,
                border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              children: [
                _buildCell('${s.pos}', align: TextAlign.center, isBold: isMatched),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(
                    children: [
                      _buildTeamLogo(s.teamName, s.logoUrl, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.teamName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isMatched ? FontWeight.w900 : FontWeight.w600,
                            color: isMatched ? const Color(0xFF92400E) : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCell('${s.played}'),
                _buildCell('${s.won}'),
                _buildCell('${s.drawn}'),
                _buildCell('${s.lost}'),
                _buildCell('${s.pointsFor}'),
                _buildCell('${s.pointsAgainst}'),
                _buildCell('${s.pointsDiff > 0 ? "+" : ""}${s.pointsDiff}',
                    textColor: s.pointsDiff > 0
                        ? const Color(0xFF047857)
                        : (s.pointsDiff < 0 ? const Color(0xFFB91C1C) : const Color(0xFF4B5563))),
                _buildCell('${s.tryBonus}'),
                _buildCell('${s.lossBonus}'),
                _buildCell('${s.points}',
                    align: TextAlign.center,
                    isBold: true,
                    textColor: isMatched ? const Color(0xFF92400E) : const Color(0xFF111827)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {TextAlign align = TextAlign.center, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: isHighlight ? const Color(0xFFB45309) : const Color(0xFF475569),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCell(String text,
      {TextAlign align = TextAlign.center, bool isBold = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.w500,
          color: textColor ?? const Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _buildPrintFixtures(List<Fixture> fixtures, String? highlightTeam) {
    if (fixtures.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: Text(
            'No fixtures available for this selection.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
        ),
      );
    }

    final cleanHighlight = highlightTeam?.trim().toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: fixtures.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final f = fixtures[index];
          final isHomeMatched = cleanHighlight != null &&
              cleanHighlight.isNotEmpty &&
              f.homeTeam.toLowerCase().contains(cleanHighlight);
          final isAwayMatched = cleanHighlight != null &&
              cleanHighlight.isNotEmpty &&
              f.awayTeam.toLowerCase().contains(cleanHighlight);

          final isCompleted = f.status.toLowerCase() == 'completed' ||
              (f.homeScore != null && f.awayScore != null);

          final isEven = index % 2 == 0;
          final rowBg = (isHomeMatched || isAwayMatched)
              ? const Color(0xFFFFFBEB) // Light warm highlight
              : (isEven ? Colors.white : const Color(0xFFFAFAFA));

          return Container(
            color: rowBg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Date & Round Column
                SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        f.date,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      if (f.roundNum.isNotEmpty)
                        Text(
                          f.roundNum,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Home Team
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          f.homeTeam,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isHomeMatched ? FontWeight.w900 : FontWeight.w600,
                            color: isHomeMatched ? const Color(0xFF92400E) : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTeamLogo(f.homeTeam, f.homeLogoUrl, size: 22),
                    ],
                  ),
                ),

                // Score / VS Box
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  constraints: const BoxConstraints(minWidth: 58),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Center(
                    child: Text(
                      isCompleted
                          ? '${f.homeScore ?? 0} - ${f.awayScore ?? 0}'
                          : (f.time.isNotEmpty ? f.time : 'VS'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isCompleted ? const Color(0xFF92400E) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),

                // Away Team
                Expanded(
                  child: Row(
                    children: [
                      _buildTeamLogo(f.awayTeam, f.awayLogoUrl, size: 22),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          f.awayTeam,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isAwayMatched ? FontWeight.w900 : FontWeight.w600,
                            color: isAwayMatched ? const Color(0xFF92400E) : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    f.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? const Color(0xFF15803D) : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
