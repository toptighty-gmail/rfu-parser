import 'package:flutter/material.dart';
import '../models/fixture.dart';
import '../theme/app_theme.dart';
import 'fixture_card.dart';

class FixtureList extends StatelessWidget {
  final List<Fixture> fixtures;
  final bool isAdmin;
  final Function(Fixture)? onEditFixture;
  final Function(Fixture)? onDeleteFixture;

  const FixtureList({
    super.key,
    required this.fixtures,
    this.isAdmin = false,
    this.onEditFixture,
    this.onDeleteFixture,
  });

  @override
  Widget build(BuildContext context) {
    if (fixtures.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: AppTheme.glassBoxDecoration(),
        child: const Center(
          child: Text(
            'No fixtures available for this selection.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    // Group fixtures by round or match category
    final Map<String, List<Fixture>> grouped = {};
    for (var f in fixtures) {
      final key = f.isCustom ? 'Friendly Matches' : f.roundNum;
      grouped.putIfAbsent(key, () => []).add(f);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: grouped.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: AppTheme.glassBoxDecoration(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Round / Category Header
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    const Icon(Icons.sports_rugby, color: AppTheme.goldAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        fontSize: 14,
                        color: AppTheme.goldAccent,
                      ),
                    ),
                  ],
                ),
              ),

              ...entry.value.map((f) => FixtureCard(
                    fixture: f,
                    isAdmin: isAdmin,
                    onEdit: onEditFixture,
                    onDelete: onDeleteFixture,
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }
}
