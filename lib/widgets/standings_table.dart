import 'package:flutter/material.dart';
import '../models/standing_entry.dart';
import '../theme/app_theme.dart';
import 'team_logo_image.dart';
import 'fixture_list.dart';

class StandingsTable extends StatelessWidget {
  final List<StandingEntry> standings;
  final String? highlightedTeam;
  final ValueChanged<String>? onTeamSelected;
  final String? Function(String teamName)? logoProvider;

  const StandingsTable({
    super.key,
    required this.standings,
    this.highlightedTeam,
    this.onTeamSelected,
    this.logoProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) {
      return Container(
        padding: EdgeInsets.all(32),
        decoration: AppTheme.glassBoxDecoration(),
        child: Center(
          child: Text(
            'No standings data available for this selection.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return Container(
      decoration: AppTheme.glassBoxDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Title Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: AppTheme.surfaceBg,
            child: Row(
              children: [
                Icon(Icons.leaderboard, color: AppTheme.goldAccent, size: 20),
                SizedBox(width: 10),
                Text(
                  'LEAGUE TABLE STANDINGS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Full-Width Data Table
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingRowColor: WidgetStateProperty.all(AppTheme.darkBg.withValues(alpha: 0.5)),
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    columnSpacing: 18,
                    columns: [
                      DataColumn(label: Text('POS', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.goldAccent))),
                      DataColumn(label: Text('TEAM', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                      DataColumn(label: Text('P', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                      DataColumn(label: Text('W', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emeraldAccent))),
                      DataColumn(label: Text('D', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                      DataColumn(label: Text('L', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.rubyAccent))),
                      DataColumn(label: Text('PF', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                      DataColumn(label: Text('PA', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                      DataColumn(label: Text('PD', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                      DataColumn(label: Text('TB', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                      DataColumn(label: Text('LB', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                      DataColumn(label: Text('PTS', style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.goldAccent, fontSize: 15))),
                    ],
                    rows: standings.map((entry) {
                      final isSelected = FixtureList.isExactTeamMatch(entry.teamName, highlightedTeam);

                      final isLeader = entry.pos == 1;

                      return DataRow(
                        onSelectChanged: onTeamSelected != null ? (_) => onTeamSelected!(entry.teamName) : null,
                        color: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (isSelected) return AppTheme.goldAccent.withValues(alpha: 0.2);
                          if (isLeader) return AppTheme.emeraldAccent.withValues(alpha: 0.08);
                          return null;
                        }),
                        cells: [
                          DataCell(
                            Text(
                              '${entry.pos}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isLeader ? AppTheme.goldAccent : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TeamLogoImage(
                                  logoUrl: (logoProvider != null ? logoProvider!(entry.teamName) : null) ?? entry.logoUrl,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  entry.teamName,
                                  style: TextStyle(
                                    fontWeight: isSelected || isLeader ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppTheme.goldAccent : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text('${entry.played}')),
                          DataCell(Text('${entry.won}', style: TextStyle(color: AppTheme.emeraldAccent, fontWeight: FontWeight.bold))),
                          DataCell(Text('${entry.drawn}')),
                          DataCell(Text('${entry.lost}', style: TextStyle(color: AppTheme.rubyAccent))),
                          DataCell(Text('${entry.pointsFor}')),
                          DataCell(Text('${entry.pointsAgainst}')),
                          DataCell(
                            Text(
                              '${entry.pointsDiff > 0 ? "+" : ""}${entry.pointsDiff}',
                              style: TextStyle(
                                color: entry.pointsDiff > 0 ? AppTheme.emeraldAccent : (entry.pointsDiff < 0 ? AppTheme.rubyAccent : AppTheme.textMuted),
                              ),
                            ),
                          ),
                          DataCell(Text('${entry.tryBonus}')),
                          DataCell(Text('${entry.lossBonus}')),
                          DataCell(
                            Text(
                              '${entry.points}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: AppTheme.goldAccent,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
