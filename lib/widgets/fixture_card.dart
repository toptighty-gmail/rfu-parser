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
              ? AppTheme.emeraldAccent.withValues(alpha: 0.05)
              : AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isNextFixture
                ? AppTheme.emeraldAccent.withValues(alpha: 0.75)
                : fixture.isCustom
                    ? AppTheme.goldAccent.withValues(alpha: 0.5)
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
              width: 290,
              child: Row(
                children: [
                  if (isNextFixture)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldAccent.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.emeraldAccent.withValues(alpha: 0.8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.emeraldAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'NEXT UP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: AppTheme.emeraldAccent,
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
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCup
                                ? AppTheme.emeraldAccent.withValues(alpha: 0.2)
                                : AppTheme.goldAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isCup
                                  ? AppTheme.emeraldAccent.withValues(alpha: 0.5)
                                  : AppTheme.goldAccent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCup ? Icons.emoji_events : Icons.sports_rugby,
                                size: 10,
                                color: isCup ? AppTheme.emeraldAccent : AppTheme.goldAccent,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isCup ? 'CUP' : 'FRIENDLY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isCup ? AppTheme.emeraldAccent : AppTheme.goldAccent,
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Text(
                        fixture.roundNum,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      fixture.date,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text(
                      'KO ${fixture.time.isNotEmpty ? fixture.time : "15:00"}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.goldAccent),
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

            // Score / VS Box
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isCompleted ? AppTheme.darkBg : AppTheme.goldAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCompleted ? AppTheme.cardBorder : AppTheme.goldAccent.withValues(alpha: 0.4),
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
                        ? AppTheme.emeraldAccent.withValues(alpha: 0.15)
                        : (isNextFixture
                            ? AppTheme.emeraldAccent.withValues(alpha: 0.2)
                            : AppTheme.goldAccent.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    fixture.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: (isCompleted || isNextFixture) ? AppTheme.emeraldAccent : AppTheme.goldAccent,
                    ),
                  ),
                ),
                if (isAdmin && fixture.isCustom) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => onEdit?.call(fixture),
                    child: const Icon(Icons.edit, size: 14, color: AppTheme.goldAccent),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => onDelete?.call(fixture),
                    child: const Icon(Icons.delete, size: 14, color: AppTheme.rubyAccent),
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
        color: isNextFixture ? AppTheme.emeraldAccent.withValues(alpha: 0.05) : AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isNextFixture
              ? AppTheme.emeraldAccent.withValues(alpha: 0.75)
              : (fixture.isCustom ? AppTheme.goldAccent.withValues(alpha: 0.4) : AppTheme.cardBorder),
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
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.emeraldAccent.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: AppTheme.emeraldAccent.withValues(alpha: 0.8)),
                        ),
                        child: const Text(
                          'NEXT UP',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: AppTheme.emeraldAccent,
                          ),
                        ),
                      ),
                    if (fixture.isCustom) ...[
                      Builder(
                        builder: (_) {
                          final isCup = fixture.competition.toLowerCase().contains('cup') ||
                              fixture.roundNum.toLowerCase().contains('cup');
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isCup
                                  ? AppTheme.emeraldAccent.withValues(alpha: 0.2)
                                  : AppTheme.goldAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              isCup ? 'CUP' : 'FRIENDLY',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: isCup ? AppTheme.emeraldAccent : AppTheme.goldAccent,
                              ),
                            ),
                          );
                        },
                      ),
                    ] else if (fixture.roundNum.isNotEmpty) ...[
                      Text(
                        '${fixture.roundNum} • ',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        fixture.date,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Text(
                      'KO ${fixture.time.isNotEmpty ? fixture.time : "15:00"}',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.goldAccent),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted ? AppTheme.emeraldAccent.withValues(alpha: 0.15) : AppTheme.goldAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      fixture.status.toUpperCase(),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isCompleted ? AppTheme.emeraldAccent : AppTheme.goldAccent),
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
                    color: isCompleted ? AppTheme.cardBorder : AppTheme.goldAccent.withValues(alpha: 0.4),
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
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 11, color: AppTheme.textMuted),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    fixture.venue.replaceAll(RegExp(r'\[.*?\]'), '').trim(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
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
