import 'package:flutter/material.dart';
import '../models/division_data.dart';
import '../widgets/standings_table.dart';
import '../widgets/fixture_list.dart';
import '../theme/app_theme.dart';

class PosterPrintView extends StatelessWidget {
  final DivisionData divisionData;

  const PosterPrintView({super.key, required this.divisionData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('A3 Poster Print View', style: TextStyle(color: AppTheme.goldAccent, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(Icons.print, color: AppTheme.goldAccent),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use Browser Print (Ctrl+P / Cmd+P) for A3 Poster printing.')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.goldAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.goldAccent.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Large Poster Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.darkBg, AppTheme.goldAccent.withValues(alpha: 0.2)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      divisionData.divisionName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppTheme.goldAccent,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'OFFICIAL FIXTURES & LEAGUE STANDINGS HUB • ${divisionData.season}',
                      style: TextStyle(color: AppTheme.textMuted, letterSpacing: 1.2, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Poster Layout Grid
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: StandingsTable(standings: divisionData.standings),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 6,
                    child: FixtureList(fixtures: divisionData.fixtures),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
