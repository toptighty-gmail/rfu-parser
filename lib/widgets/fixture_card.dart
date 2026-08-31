import 'package:flutter/material.dart';
import '../models/fixture.dart';
import '../theme/app_theme.dart';
import 'team_logo_image.dart';
import 'fixture_list.dart';

class FixtureCard extends StatelessWidget {
  final Fixture fixture;
  final bool isAdmin;
  final bool isNextFixture;
  final String? filterTeam;
  final String? Function(String teamName)? logoProvider;
  final ValueChanged<String>? onTeamSelected;
  final Function(Fixture)? onEdit;
  final Function(Fixture)? onDelete;

  const FixtureCard({
    super.key,
    required this.fixture,
    this.isAdmin = false,
    this.isNextFixture = false,
    this.filterTeam,
    this.logoProvider,
    this.onTeamSelected,
    this.onEdit,
    this.onDelete,
  });

  String? _resolveLogo(String teamName, String? defaultUrl) {
    if (defaultUrl != null && defaultUrl.trim().isNotEmpty) return defaultUrl.trim();
    if (logoProvider != null) {
      final custom = logoProvider!(teamName);
      if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    }
    return null;
  }

  Widget _buildTeamLogo(String teamName, String? directLogoUrl) {
    final logoUrl = _resolveLogo(teamName, directLogoUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: TeamLogoImage(
        logoUrl: logoUrl,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final isCompleted = fixture.status.toLowerCase() == 'completed' ||
        (fixture.homeScore != null && fixture.awayScore != null);

    final cleanFilter = filterTeam?.trim();
    final isHomeMatched = FixtureList.isExactTeamMatch(fixture.homeTeam, cleanFilter) ||
        (fixture.isCustom && fixture.contextTeam != null && FixtureList.isExactTeamMatch(fixture.contextTeam!, cleanFilter));
    final isAwayMatched = FixtureList.isExactTeamMatch(fixture.awayTeam, cleanFilter) ||
        (fixture.isCustom && fixture.contextTeam != null && FixtureList.isExactTeamMatch(fixture.contextTeam!, cleanFilter));

    if (isDesktop) {
      // Desktop / Tablet Single-Row Sleek Layout
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isNextFixture
              ? AppTheme.rubyAccent.withValues(alpha: 0.08)
              : AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isNextFixture
                ? AppTheme.rubyAccent.withValues(alpha: 0.85)
                : fixture.isCustom
                    ? AppTheme.tertiaryAccent.withValues(alpha: 0.7)
                    : (isHomeMatched || isAwayMatched)
                        ? AppTheme.goldAccent.withValues(alpha: 0.3)
                        : AppTheme.cardBorder,
            width: isNextFixture ? 1.5 : (fixture.isCustom ? 1.5 : 1),
          ),
        ),
        child: Row(
          children: [
            // Date & Time & Round & Next-Up Badge
            SizedBox(
              width: 335,
              child: Row(
                children: [
                  if (isNextFixture)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF1E27), // Vivid Bright Red
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF1E27).withValues(alpha: 0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'NEXT ROUND',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (fixture.isCustom)
                    Builder(
                      builder: (context) {
                        final isCup = fixture.competition.toLowerCase().contains('cup') ||
                            fixture.roundNum.toLowerCase().contains('cup');
                        final badgeBg = isCup ? const Color(0xFFA855F7) : const Color(0xFFFACC15); // Vivid Purple / Vivid Yellow
                        final badgeFg = isCup ? Colors.white : const Color(0xFF0F172A); // High Contrast Dark on Yellow
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: badgeBg.withValues(alpha: 0.35),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCup ? Icons.emoji_events : Icons.sports_rugby,
                                size: 10.5,
                                color: badgeFg,
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                isCup ? 'CUP' : 'FRIENDLY',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: badgeFg,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  else if (fixture.roundNum.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Text(
                        fixture.roundNum,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      fixture.date,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Prominent Kickoff Time using EXACT same style as the VS box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.goldAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.goldAccent.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 12, color: AppTheme.goldAccent),
                        SizedBox(width: 5),
                        Text(
                          'KO ${fixture.time.isNotEmpty ? fixture.time : "15:00"}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: AppTheme.goldAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // Home Team
            Expanded(
              child: MouseRegion(
                cursor: onTeamSelected != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: InkWell(
                  onTap: onTeamSelected != null ? () => onTeamSelected!(fixture.homeTeam) : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          fixture.homeTeam,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isHomeMatched ? FontWeight.w900 : FontWeight.w600,
                            color: isHomeMatched ? AppTheme.goldAccent : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTeamLogo(fixture.homeTeam, fixture.homeLogoUrl),
                    ],
                  ),
                ),
              ),
            ),

            // Score / VS Box (Always 'VS' for upcoming matches, Score for completed)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isCompleted ? AppTheme.darkBg : AppTheme.goldAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCompleted ? AppTheme.cardBorder : AppTheme.goldAccent.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Text(
                isCompleted
                    ? '${fixture.homeScore ?? 0} - ${fixture.awayScore ?? 0}'
                    : 'VS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isCompleted ? AppTheme.textPrimary : AppTheme.goldAccent,
                ),
              ),
            ),

            // Away Team
            Expanded(
              child: MouseRegion(
                cursor: onTeamSelected != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: InkWell(
                  onTap: onTeamSelected != null ? () => onTeamSelected!(fixture.awayTeam) : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      _buildTeamLogo(fixture.awayTeam, fixture.awayLogoUrl),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          fixture.awayTeam,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isAwayMatched ? FontWeight.w900 : FontWeight.w600,
                            color: isAwayMatched ? AppTheme.goldAccent : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Status & Admin
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF22C55E).withValues(alpha: 0.18) // Vivid Green – always
                        : const Color(0xFF38BDF8).withValues(alpha: 0.15), // Vivid Sky Blue – always
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                          : const Color(0xFF38BDF8).withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    fixture.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? const Color(0xFF22C55E) // Vivid Green
                          : const Color(0xFF38BDF8), // Vivid Sky Blue
                    ),
                  ),
                ),
                if (isAdmin && fixture.isCustom) ...[
                  SizedBox(width: 6),
                  InkWell(
                    onTap: () => onEdit?.call(fixture),
                    child: Icon(Icons.edit, size: 14, color: AppTheme.goldAccent),
                  ),
                  SizedBox(width: 6),
                  InkWell(
                    onTap: () => onDelete?.call(fixture),
                    child: Icon(Icons.delete, size: 14, color: AppTheme.rubyAccent),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    // Mobile Responsive Compact Layout
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isNextFixture ? AppTheme.rubyAccent.withValues(alpha: 0.08) : AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isNextFixture
              ? AppTheme.rubyAccent.withValues(alpha: 0.85)
              : (fixture.isCustom ? AppTheme.tertiaryAccent.withValues(alpha: 0.6) : AppTheme.cardBorder),
          width: isNextFixture ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isNextFixture)
                      Container(
                        margin: const EdgeInsets.only(right: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF1E27), // Vivid Bright Red
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF1E27).withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Text(
                          'NEXT UP',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (fixture.isCustom) ...[
                      Builder(
                        builder: (_) {
                          final isCup = fixture.competition.toLowerCase().contains('cup') ||
                              fixture.roundNum.toLowerCase().contains('cup');
                          final badgeBg = isCup ? const Color(0xFFA855F7) : const Color(0xFFFACC15); // Vivid Yellow for Friendly
                          final badgeFg = isCup ? Colors.white : const Color(0xFF0F172A); // High Contrast Dark
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              isCup ? 'CUP' : 'FRIENDLY',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                                color: badgeFg,
                              ),
                            ),
                          );
                        },
                      ),
                    ] else if (fixture.roundNum.isNotEmpty) ...[
                      Text(
                        '${fixture.roundNum} • ',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        fixture.date,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mobile Prominent Kickoff Box using same styling as VS
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.goldAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppTheme.goldAccent.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 10, color: AppTheme.goldAccent),
                        SizedBox(width: 4),
                        Text(
                          'KO ${fixture.time.isNotEmpty ? fixture.time : "15:00"}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: AppTheme.goldAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF22C55E).withValues(alpha: 0.18) // Vivid Green
                          : const Color(0xFF38BDF8).withValues(alpha: 0.15), // Vivid Sky Blue
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isCompleted
                            ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                            : const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      fixture.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? const Color(0xFF22C55E) // Vivid Green
                            : const Color(0xFF38BDF8), // Vivid Sky Blue
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: onTeamSelected != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                  child: InkWell(
                    onTap: onTeamSelected != null ? () => onTeamSelected!(fixture.homeTeam) : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            fixture.homeTeam,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isHomeMatched ? FontWeight.w900 : FontWeight.w600,
                              color: isHomeMatched ? AppTheme.goldAccent : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildTeamLogo(fixture.homeTeam, fixture.homeLogoUrl),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted ? AppTheme.darkBg : AppTheme.goldAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isCompleted ? AppTheme.cardBorder : AppTheme.goldAccent.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: Text(
                  isCompleted
                      ? '${fixture.homeScore ?? 0} - ${fixture.awayScore ?? 0}'
                      : 'VS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isCompleted ? AppTheme.textPrimary : AppTheme.goldAccent,
                  ),
                ),
              ),
              Expanded(
                child: MouseRegion(
                  cursor: onTeamSelected != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                  child: InkWell(
                    onTap: onTeamSelected != null ? () => onTeamSelected!(fixture.awayTeam) : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        _buildTeamLogo(fixture.awayTeam, fixture.awayLogoUrl),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            fixture.awayTeam,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isAwayMatched ? FontWeight.w900 : FontWeight.w600,
                              color: isAwayMatched ? AppTheme.goldAccent : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (fixture.venue.isNotEmpty) ...[
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 11, color: AppTheme.textMuted),
                SizedBox(width: 3),
                Flexible(
                  child: Text(
                    fixture.venue.replaceAll(RegExp(r'\[.*?\]'), '').trim(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
