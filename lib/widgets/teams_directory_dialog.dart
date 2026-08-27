import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TeamsDirectoryDialog extends StatefulWidget {
  final ValueChanged<String> onSelectTeam;

  const TeamsDirectoryDialog({super.key, required this.onSelectTeam});

  @override
  State<TeamsDirectoryDialog> createState() => _TeamsDirectoryDialogState();
}

class _TeamsDirectoryDialogState extends State<TeamsDirectoryDialog> {
  final TextEditingController _filterController = TextEditingController();
  
  final List<String> _indexedTeams = [
    'Coventry',
    'Coventry Welsh',
    'Coventry Welsh Ladies',
    'Exeter Chiefs',
    'Bath Rugby',
    'Gloucester Rugby',
    'Bristol Bears',
    'Leicester Tigers',
    'Northampton Saints',
    'Saracens',
    'Harlequins',
    'Sale Sharks',
    'Newcastle Falcons',
    'Cornish Pirates',
    'Ealing Trailfinders',
    'Bedford Blues',
    'Doncaster Knights',
    'Richmond',
    'Plymouth Albion',
    'Plymstock Oaks',
    'Plymstock Oaks II',
    'Plymstock Oaks Colts',
    'Devonport Services',
    'Devonport Services II',
    'Devonport Services Colts',
    'Topsham',
    'Topsham II',
    'Topsham Colts',
    'Camborne',
    'Redruth',
    'Exmouth',
    'Barnstaple',
    'Bideford',
    'Brixham',
    'Ivybridge',
    'Launceston',
    'Newton Abbot',
    'Newton Abbot II',
    'Crediton',
    'Cullompton',
    'Okehampton',
    'Sidmouth',
    'Teignmouth',
    'Paignton',
    'Paignton II',
    'Torquay Athletic',
    'Torquay Athletic II',
    'Tavistock',
    'Tavistock II',
    'Tavistock Colts',
    'Honiton',
    'Withycombe',
    'Tiverton',
    'South Molton',
    'Ilfracombe',
    'Totnes',
    'Salcombe',
  ];

  List<String> _filteredTeams = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _filteredTeams = List.from(_indexedTeams);
  }

  void _filter(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredTeams = List.from(_indexedTeams));
      return;
    }

    // 1. Local filter
    final matches = _indexedTeams.where((t) => t.toLowerCase().contains(q)).toList();

    setState(() {
      _filteredTeams = matches;
      _isLoading = true;
    });

    // 2. Query England Rugby API
    final apiResults = await ApiService.suggestTeams(query.trim());
    if (mounted) {
      final apiNames = apiResults.map((e) => (e['name'] ?? '').toString()).where((name) => name.isNotEmpty).toList();
      final combined = {...matches, ...apiNames}.toList()..sort();
      setState(() {
        _filteredTeams = combined;
        _isLoading = false;
      });
    }
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
              Icon(Icons.sports_rugby, color: AppTheme.goldAccent),
              SizedBox(width: 10),
              Text('RFU Teams Directory', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
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
                hintText: 'Search RFU Teams (e.g. Coventry, Plymstock)...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppTheme.goldAccent, size: 20),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.goldAccent)),
                      )
                    : null,
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
              child: _filteredTeams.isEmpty
                  ? const Center(
                      child: Text('No matching RFU teams found', style: TextStyle(color: AppTheme.textMuted)),
                    )
                  : ListView.separated(
                      itemCount: _filteredTeams.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
                      itemBuilder: (context, index) {
                        final teamName = _filteredTeams[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.shield, color: AppTheme.goldAccent, size: 18),
                          title: Text(
                            teamName,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textMuted),
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onSelectTeam(teamName);
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
