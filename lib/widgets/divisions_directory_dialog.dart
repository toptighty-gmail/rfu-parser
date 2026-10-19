import 'package:flutter/material.dart';
import '../models/division_catalog_entry.dart';
import '../theme/app_theme.dart';

/// Picks a division from the season's catalogue: every league, merit table,
/// cup round and international series the RFU lists, grouped by competition
/// and filterable by competition group.
class DivisionsDirectoryDialog extends StatefulWidget {
  final List<DivisionCatalogEntry> entries;
  final String selectedDivision;
  final ValueChanged<String> onSelectDivision;

  const DivisionsDirectoryDialog({
    super.key,
    required this.entries,
    required this.selectedDivision,
    required this.onSelectDivision,
  });

  @override
  State<DivisionsDirectoryDialog> createState() =>
      _DivisionsDirectoryDialogState();
}

/// A row in the list: a competition heading or a division.
class _Row {
  final String? heading;
  final DivisionCatalogEntry? entry;
  const _Row.heading(this.heading) : entry = null;
  const _Row.entry(this.entry) : heading = null;
}

class _DivisionsDirectoryDialogState extends State<DivisionsDirectoryDialog> {
  static const String _all = 'All';
  static const String _other = 'Other';

  final TextEditingController _filterController = TextEditingController();
  String _selectedCategory = _all;
  late final List<String> _categories;
  late final List<DivisionCatalogEntry> _sorted;
  List<_Row> _rows = [];

  @override
  void initState() {
    super.initState();
    final present = widget.entries.map(_groupOf).toSet();
    _categories = [
      _all,
      ...DivisionCatalogEntry.categoryOrder.where(present.contains),
      if (present.contains(_other)) _other,
    ];
    _sorted = List.of(widget.entries)..sort(_compare);
    _applyFilters();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  static String _groupOf(DivisionCatalogEntry e) =>
      DivisionCatalogEntry.categoryOrder.contains(e.category) ? e.category : _other;

  static int _groupRank(DivisionCatalogEntry e) {
    final i = DivisionCatalogEntry.categoryOrder.indexOf(e.category);
    return i < 0 ? DivisionCatalogEntry.categoryOrder.length : i;
  }

  /// Group, then competition, then division: cup rounds in the order the
  /// RFU created them (Round 1 ... Final), everything else by name.
  static int _compare(DivisionCatalogEntry a, DivisionCatalogEntry b) {
    final byGroup = _groupRank(a).compareTo(_groupRank(b));
    if (byGroup != 0) return byGroup;
    final byComp = a.competition.toLowerCase().compareTo(b.competition.toLowerCase());
    if (byComp != 0) return byComp;
    if (a.isKnockout && a.rfuDivisionId != null && b.rfuDivisionId != null) {
      return a.rfuDivisionId!.compareTo(b.rfuDivisionId!);
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  void _applyFilters() {
    final q = _filterController.text.trim().toLowerCase();
    final rows = <_Row>[];
    String? lastHeading;
    for (final e in _sorted) {
      if (_selectedCategory != _all && _groupOf(e) != _selectedCategory) continue;
      if (q.isNotEmpty &&
          !e.name.toLowerCase().contains(q) &&
          !e.competition.toLowerCase().contains(q)) {
        continue;
      }
      final heading = e.competition.isNotEmpty ? e.competition : _groupOf(e);
      if (heading != lastHeading) {
        rows.add(_Row.heading(heading));
        lastHeading = heading;
      }
      rows.add(_Row.entry(e));
    }
    setState(() => _rows = rows);
  }

  String _badge(DivisionCatalogEntry e) {
    switch (e.category) {
      case 'Internationals':
        return 'INT';
      case 'Merit Tables':
        return 'MT';
      case 'Cups':
        return 'CUP';
      case "Women's Cups":
        return 'W CUP';
      case "Women's Leagues":
        return 'W';
    }
    final d = e.name.toLowerCase();
    if (d.contains('premiership')) return 'T1';
    if (d.contains('championship')) return 'T2';
    if (d.contains('national 1') || d.contains('national league 1')) return 'T3';
    if (d.contains('national 2') || d.contains('national league 2')) return 'T4';
    if (d.contains('regional 1')) return 'T5';
    if (d.contains('regional 2')) return 'T6';
    if (d.contains('counties 1')) return 'T7';
    if (d.contains('counties 2')) return 'T8';
    if (d.contains('counties 3')) return 'T9';
    if (d.contains('counties 4')) return 'T10';
    return 'LGE';
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.currentMode;
    final divisionCount = _rows.where((r) => r.entry != null).length;

    return AlertDialog(
      backgroundColor: theme.surfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.cardBorder, width: 1.2),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: theme.goldAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.emoji_events, color: theme.goldAccent, size: 20),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'RFU Competitions',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 600
            ? 560
            : MediaQuery.of(context).size.width * 0.92,
        height: (MediaQuery.of(context).size.height * 0.75).clamp(400.0, 640.0),
        child: Column(
          children: [
            TextField(
              controller: _filterController,
              style: TextStyle(color: theme.textPrimary, fontSize: 14),
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: 'Search league, cup or competition (e.g. Counties 2, Merit, Vase)...',
                hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: theme.goldAccent, size: 20),
                filled: true,
                fillColor: theme.darkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.goldAccent, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Competition group chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.black : theme.textMuted,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: theme.goldAccent,
                      backgroundColor: theme.surfaceBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? theme.goldAccent : theme.cardBorder,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          _selectedCategory = cat;
                          _applyFilters();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$divisionCount ${divisionCount == 1 ? 'division' : 'divisions'}',
                style: TextStyle(color: theme.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: _rows.isEmpty
                  ? Center(
                      child: Text(
                        'No matching RFU divisions found',
                        style: TextStyle(color: theme.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final row = _rows[index];
                        if (row.heading != null) {
                          return Padding(
                            padding: EdgeInsets.fromLTRB(8, index == 0 ? 2 : 14, 8, 4),
                            child: Text(
                              row.heading!.toUpperCase(),
                              style: TextStyle(
                                color: theme.goldAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          );
                        }
                        final entry = row.entry!;
                        final isSelected = entry.name.toLowerCase().trim() ==
                            widget.selectedDivision.toLowerCase().trim();
                        return Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.goldAccent.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: theme.goldAccent.withValues(alpha: 0.6))
                                : Border(
                                    bottom: BorderSide(color: theme.cardBorder, width: 0.6),
                                  ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              width: 44,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? theme.goldAccent : theme.cardBorder,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _badge(entry),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? Colors.black : theme.textPrimary,
                                ),
                              ),
                            ),
                            title: Text(
                              entry.name,
                              style: TextStyle(
                                color: isSelected ? theme.goldAccent : theme.textPrimary,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              ),
                            ),
                            trailing: isSelected
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: theme.goldAccent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  )
                                : Icon(Icons.chevron_right, color: theme.textMuted, size: 16),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onSelectDivision(entry.name);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
