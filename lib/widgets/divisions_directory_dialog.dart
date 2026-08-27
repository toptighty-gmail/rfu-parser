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

  @override
  void initState() {
    super.initState();
    _filteredDivisions = List.from(widget.divisions);
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredDivisions = List.from(widget.divisions));
      return;
    }

    setState(() {
      _filteredDivisions = widget.divisions
          .where((div) => div.toLowerCase().contains(q))
          .toList();
    });
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
        width: 450,
        height: 480,
        child: Column(
          children: [
            TextField(
              controller: _filterController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              onChanged: _filter,
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
            const SizedBox(height: 12),
            Expanded(
              child: _filteredDivisions.isEmpty
                  ? const Center(
                      child: Text('No matching RFU divisions found', style: TextStyle(color: AppTheme.textMuted)),
                    )
                  : ListView.separated(
                      itemCount: _filteredDivisions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
                      itemBuilder: (context, index) {
                        final divName = _filteredDivisions[index];
                        final isSelected = divName == widget.selectedDivision;

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.emoji_events_outlined,
                            color: isSelected ? AppTheme.emeraldAccent : AppTheme.goldAccent,
                            size: 18,
                          ),
                          title: Text(
                            divName,
                            style: TextStyle(
                              color: isSelected ? AppTheme.emeraldAccent : AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onSelectDivision(divName);
                          },
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
