import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DivisionsDirectoryDialog extends StatefulWidget {
  final List<String> divisions;
  final String selectedDivision;
  final ValueChanged<String> onSelectDivision;
  final Map<String, int?> divisionIds;

  const DivisionsDirectoryDialog({
    super.key,
    required this.divisions,
    required this.selectedDivision,
    required this.onSelectDivision,
    this.divisionIds = const {},
  });

  @override
  State<DivisionsDirectoryDialog> createState() => _DivisionsDirectoryDialogState();
}

class _DivisionsDirectoryDialogState extends State<DivisionsDirectoryDialog> {
  final TextEditingController _filterController = TextEditingController();
  String _selectedCategory = 'All';
  List<String> _filteredDivisions = [];

  final List<String> _categories = [
    'All',
    'National',
    'South West',
    'London & SE',
    'Midlands',
    'Northern',
  ];

  @override
  void initState() {
    super.initState();
    _filteredDivisions = List.from(widget.divisions);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final q = _filterController.text.trim().toLowerCase();
    setState(() {
      _filteredDivisions = widget.divisions.where((div) {
        final d = div.toLowerCase();
        // Query match
        if (q.isNotEmpty && !d.contains(q)) return false;

        // Category match
        if (_selectedCategory == 'All') return true;
        if (_selectedCategory == 'National') {
          return d.contains('premiership') || d.contains('championship') || d.contains('national');
        }
        if (_selectedCategory == 'South West') {
          return d.contains('south west') || d.contains('tribute') || d.contains('western') || d.contains('devon') || d.contains('cornwall');
        }
        if (_selectedCategory == 'London & SE') {
          return d.contains('london') || d.contains('south east') || d.contains('surrey') || d.contains('kent') || d.contains('essex') || d.contains('sussex');
        }
        if (_selectedCategory == 'Midlands') {
          return d.contains('midlands') || d.contains('warwick') || d.contains('leicester') || d.contains('nottingham');
        }
        if (_selectedCategory == 'Northern') {
          return d.contains('north') || d.contains('yorkshire') || d.contains('lancs') || d.contains('cumbria') || d.contains('durham');
        }
        return true;
      }).toList();
    });
  }

  String _getTierBadge(String divName) {
    final d = divName.toLowerCase();
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

    return AlertDialog(
      backgroundColor: theme.surfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.cardBorder, width: 1.2),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
              Text(
                'RFU Divisions Directory',
                style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 600 ? 540 : MediaQuery.of(context).size.width * 0.92,
        height: (MediaQuery.of(context).size.height * 0.75).clamp(400.0, 600.0),
        child: Column(
          children: [
            // Search Input
            TextField(
              controller: _filterController,
              style: TextStyle(color: theme.textPrimary, fontSize: 14),
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: 'Search RFU Division (e.g. Regional 1, Tribute, Counties)...',
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
            
            // Regional / Competition Chips
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
                          setState(() {
                            _selectedCategory = cat;
                          });
                          _applyFilters();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Divisions List
            Expanded(
              child: _filteredDivisions.isEmpty
                  ? Center(
                      child: Text('No matching RFU divisions found', style: TextStyle(color: theme.textMuted)),
                    )
                  : ListView.separated(
                      itemCount: _filteredDivisions.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: theme.cardBorder),
                      itemBuilder: (context, index) {
                        final divName = _filteredDivisions[index];
                        final isSelected = divName.toLowerCase().trim() == widget.selectedDivision.toLowerCase().trim();
                        final tierBadge = _getTierBadge(divName);
                        final divId = widget.divisionIds[divName.toLowerCase().trim()];

                        return Container(
                          decoration: BoxDecoration(
                            color: isSelected ? theme.goldAccent.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: theme.goldAccent.withValues(alpha: 0.6)) : null,
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? theme.goldAccent : theme.cardBorder,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tierBadge,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? Colors.black : theme.textPrimary,
                                ),
                              ),
                            ),
                            title: Text(
                              divId != null ? '$divName ($divId)' : divName,
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
                              widget.onSelectDivision(divName);
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
