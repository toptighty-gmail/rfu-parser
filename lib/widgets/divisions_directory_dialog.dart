import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DivisionsDirectoryDialog extends StatefulWidget {
  final List<String> divisions;
  final String selectedDivision;
  final ValueChanged<String> onSelectDivision;

  const DivisionsDirectoryDialog({
    super.key,
    required this.divisions,
    required this.selectedDivision,
    required this.onSelectDivision,
  });

  @override
  State<DivisionsDirectoryDialog> createState() => _DivisionsDirectoryDialogState();
}

class _DivisionsDirectoryDialogState extends State<DivisionsDirectoryDialog> {
  final TextEditingController _filterController = TextEditingController();
  List<String> _filteredDivisions = [];
  String _selectedCategory = 'ALL';

  final List<String> _categories = [
    'ALL',
    'South West',
    'National',
    'London & SE',
    'Midlands',
    'Northern',
  ];

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  void _applyFilters() {
    final q = _filterController.text.trim().toLowerCase();
    setState(() {
      _filteredDivisions = widget.divisions.where((div) {
        final d = div.toLowerCase();
        
        // 1. Text search filter
        final matchesText = q.isEmpty || d.contains(q);
        if (!matchesText) return false;

        // 2. Category filter
        if (_selectedCategory == 'ALL') return true;
        if (_selectedCategory == 'South West') {
          return d.contains('south west') || d.contains('devon') || d.contains('cornwall') || d.contains('somerset') || d.contains('western') || d.contains('severn');
        }
        if (_selectedCategory == 'National') {
          return d.contains('national') || d.contains('premiership') || d.contains('championship');
        }
        if (_selectedCategory == 'London & SE') {
          return d.contains('london') || d.contains('se') || d.contains('kent') || d.contains('surrey') || d.contains('sussex') || d.contains('essex') || d.contains('herts');
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
    return AlertDialog(
      backgroundColor: AppTheme.surfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.cardBorder),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events, color: AppTheme.goldAccent),
              SizedBox(width: 10),
              Text(
                'RFU Divisions Directory',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 520,
        child: Column(
          children: [
            // Search Input
            TextField(
              controller: _filterController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: 'Search RFU Division (e.g. Regional 1, Tribute, Counties)...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppTheme.goldAccent, size: 20),
                filled: true,
                fillColor: AppTheme.darkBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
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
                          color: isSelected ? Colors.black : AppTheme.textMuted,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.goldAccent,
                      backgroundColor: AppTheme.surfaceBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? AppTheme.goldAccent : AppTheme.cardBorder,
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
                  ? const Center(
                      child: Text('No matching RFU divisions found', style: TextStyle(color: AppTheme.textMuted)),
                    )
                  : ListView.separated(
                      itemCount: _filteredDivisions.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.cardBorder),
                      itemBuilder: (context, index) {
                        final divName = _filteredDivisions[index];
                        final isSelected = divName.toLowerCase().trim() == widget.selectedDivision.toLowerCase().trim();
                        final tierBadge = _getTierBadge(divName);

                        return Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.goldAccent.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.6)) : null,
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.goldAccent : AppTheme.cardBorder,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tierBadge,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? Colors.black : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            title: Text(
                              divName,
                              style: TextStyle(
                                color: isSelected ? AppTheme.goldAccent : AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              ),
                            ),
                            trailing: isSelected
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.goldAccent,
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
                                : const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 16),
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
