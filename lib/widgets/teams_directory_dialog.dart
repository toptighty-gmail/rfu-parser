import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';
import '../services/rfu_team_registry.dart';
import '../theme/app_theme.dart';

class TeamsDirectoryDialog extends StatefulWidget {
  final ValueChanged<String> onSelectTeam;

  const TeamsDirectoryDialog({super.key, required this.onSelectTeam});

  @override
  State<TeamsDirectoryDialog> createState() => _TeamsDirectoryDialogState();
}

class _TeamsDirectoryDialogState extends State<TeamsDirectoryDialog> {
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<String> _indexedTeams = [
    'Plymstock Oaks',
    'Plymstock Oaks II',
    'Plymstock Oaks Colts',
    'OPMs',
    'OPMs II',
    'Withycombe',
    'Honiton',
    'South Molton',
    'Brixham',
    'Brixham II',
    'Tavistock',
    'Tavistock II',
    'Exeter Saracens',
    'Bideford',
    'Bideford II',
    'Topsham',
    'Topsham II',
    'Crediton',
    'Crediton II',
    'Exmouth',
    'Exmouth II',
    'Barnstaple',
    'Barnstaple II',
    'Cullompton',
    'Cullompton II',
    'Devonport Services',
    'Devonport Services II',
    'Ivybridge',
    'Paignton',
    'Paignton II',
    'Torquay Athletic',
    'Torquay Athletic II',
    'Newton Abbot',
    'Newton Abbot II',
    'Okehampton',
    'Sidmouth',
    'Teignmouth',
    'Camborne',
    'Redruth',
    'Cornish Pirates',
    'Plymouth Albion',
    'Saltash',
    'Saltash II',
    'Coventry',
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
    'Ealing Trailfinders',
    'Bedford Blues',
    'Doncaster Knights',
  ];

  List<String> _filteredTeams = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _filteredTeams = List.from(_indexedTeams);
    _loadDatabaseTeams();
    
    // Automatically focus the search box on dialog open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadDatabaseTeams() async {
    try {
      final dbTeams = await SupabaseService.fetchAllDistinctTeams();
      if (mounted && dbTeams.isNotEmpty) {
        final combined = {..._indexedTeams, ...dbTeams}.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        setState(() {
          _filteredTeams = combined;
        });
      }
    } catch (_) {}
  }

  void _filter(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      _loadDatabaseTeams();
      return;
    }

    final allTeams = {..._indexedTeams, ...RfuTeamRegistry.allKnownTeamNames}.toList();
    final matches = allTeams.where((t) => t.toLowerCase().contains(q)).toList();

    setState(() {
      _filteredTeams = matches;
      _isLoading = true;
    });

    // Query England Rugby API
    try {
      final apiResults = await ApiService.suggestTeams(query.trim());
      if (mounted) {
        final apiNames = apiResults
            .map((e) => RfuTeamRegistry.normalizeTeamName((e['name'] ?? '').toString()))
            .where((name) => name.isNotEmpty)
            .toList();
        final combined = {...matches, ...apiNames}.toList()..sort();
        setState(() {
          _filteredTeams = combined;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
              Text(
                'Search RFU Teams',
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
        width: MediaQuery.of(context).size.width > 600 ? 480 : MediaQuery.of(context).size.width * 0.92,
        height: (MediaQuery.of(context).size.height * 0.72).clamp(380.0, 560.0),
        child: Column(
          children: [
            TextField(
              controller: _filterController,
              focusNode: _searchFocusNode,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              onChanged: _filter,
              onSubmitted: (val) {
                final query = val.trim();
                if (query.isEmpty) return;
                if (_filteredTeams.isNotEmpty) {
                  Navigator.of(context).pop();
                  widget.onSelectTeam(_filteredTeams.first);
                } else {
                  Navigator.of(context).pop();
                  widget.onSelectTeam(query);
                }
              },
              decoration: InputDecoration(
                hintText: 'Search RFU Teams (e.g. Plymstock, OPMs, Coventry)...',
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.goldAccent, width: 1.5),
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
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.cardBorder),
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
