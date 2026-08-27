import 'package:flutter/material.dart';
import '../models/division_data.dart';
import '../widgets/standings_table.dart';
import '../widgets/fixture_list.dart';
import '../theme/app_theme.dart';

class BookletPrintView extends StatelessWidget {
  final DivisionData divisionData;

  const BookletPrintView({super.key, required this.divisionData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('A4 Booklet 2-Page Print View', style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: AppTheme.goldAccent),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use Browser Print (Ctrl+P / Cmd+P) to print A4 Booklet layout.')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      divisionData.divisionName.toUpperCase(),
                      style: const TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'Season: ${divisionData.season}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2-Column Split: Page 1 (Standings) & Page 2 (Fixtures)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Page: Standings
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'PAGE 1: LEAGUE TABLE',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                          ),
                          const Divider(),
                          Theme(
                            data: ThemeData.light(),
                            child: StandingsTable(standings: divisionData.standings),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right Page: Fixtures
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'PAGE 2: FIXTURES & RESULTS',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                          ),
                          const Divider(),
                          Theme(
                            data: ThemeData.light(),
                            child: FixtureList(fixtures: divisionData.fixtures),
                          ),
                        ],
                      ),
                    ),
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
