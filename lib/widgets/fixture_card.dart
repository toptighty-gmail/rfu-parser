import 'package:flutter/material.dart';
import '../models/fixture.dart';
import '../theme/app_theme.dart';

class FixtureCard extends StatelessWidget {
  final Fixture fixture;
  final bool isAdmin;
  final String? filterTeam;
  final Function(Fixture)? onEdit;
  final Function(Fixture)? onDelete;

  const FixtureCard({
    super.key,
    required this.fixture,
    this.isAdmin = false,
    this.filterTeam,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = fixture.status.toLowerCase() == 'completed' ||
        (fixture.homeScore != null && fixture.awayScore != null);

    final cleanFilter = filterTeam?.trim().toLowerCase();
    final isHomeMatched = cleanFilter != null && cleanFilter.isNotEmpty && fixture.homeTeam.toLowerCase().contains(cleanFilter);
    final isAwayMatched = cleanFilter != null && cleanFilter.isNotEmpty && fixture.awayTeam.toLowerCase().contains(cleanFilter);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fixture.isCustom ? AppTheme.goldAccent.withValues(alpha: 0.4) : AppTheme.cardBorder,
          width: fixture.isCustom ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header: Date, Status Badge, Admin Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (fixture.isCustom) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.goldAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'FRIENDLY',
                        style: TextStyle(color: AppTheme.goldAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.calendar_today, size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    fixture.date,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                  ),
                  if (fixture.time.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      fixture.time,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ],
              ),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppTheme.emeraldAccent.withValues(alpha: 0.15)
                          : AppTheme.goldAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      fixture.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? AppTheme.emeraldAccent : AppTheme.goldAccent,
                      ),
                    ),
                  ),

                  if (isAdmin && fixture.isCustom) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => onEdit?.call(fixture),
                      child: const Icon(Icons.edit, size: 16, color: AppTheme.goldAccent),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => onDelete?.call(fixture),
                      child: const Icon(Icons.delete, size: 16, color: AppTheme.rubyAccent),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Main Scoreline & Teams Display
          Row(
            children: [
              // Home Team
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        fixture.homeTeam,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontWeight: isHomeMatched ? FontWeight.w900 : FontWeight.bold,
                          fontSize: 15,
                          color: isHomeMatched ? AppTheme.goldAccent : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (fixture.homeLogoUrl != null && fixture.homeLogoUrl!.isNotEmpty)
                      Image.network(
                        fixture.homeLogoUrl!,
                        width: 28,
                        height: 28,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 24, color: AppTheme.textMuted),
                      )
                    else
                      const Icon(Icons.shield, size: 24, color: AppTheme.textMuted),
                  ],
                ),
              ),

              // Score Box
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.darkBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Text(
                  isCompleted
                      ? '${fixture.homeScore ?? 0} - ${fixture.awayScore ?? 0}'
                      : 'VS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: isCompleted ? 16 : 13,
                    color: isCompleted ? AppTheme.goldAccent : AppTheme.textMuted,
                  ),
                ),
              ),

              // Away Team
              Expanded(
                child: Row(
                  children: [
                    if (fixture.awayLogoUrl != null && fixture.awayLogoUrl!.isNotEmpty)
                      Image.network(
                        fixture.awayLogoUrl!,
                        width: 28,
                        height: 28,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 24, color: AppTheme.textMuted),
                      )
                    else
                      const Icon(Icons.shield, size: 24, color: AppTheme.textMuted),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        fixture.awayTeam,
                        style: TextStyle(
                          fontWeight: isAwayMatched ? FontWeight.w900 : FontWeight.bold,
                          fontSize: 15,
                          color: isAwayMatched ? AppTheme.goldAccent : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
