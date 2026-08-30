import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/rfu_team_registry.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class TeamsDirectoryDialog extends StatefulWidget {
  final ValueChanged<String> onSelectTeam;

  const TeamsDirectoryDialog({
    super.key,
    required this.onSelectTeam,
  });

  @override
  State<TeamsDirectoryDialog> createState() => _TeamsDirectoryDialogState();
}

class _TeamsDirectoryDialogState extends State<TeamsDirectoryDialog> {
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<String> _filteredTeams = [];
  bool _isLoading = false;

  final List<String> _indexedTeams = [
    // Championship & National Leagues
    'Coventry', 'Ealing Trailfinders', 'Doncaster Knights', 'Bedford Blues',
    'Cornish Pirates', 'Hartpury University', 'Ampthill', 'London Scottish',
    'Nottingham', 'Caldy', 'Cambridge', 'Chinnor', 'Richmond',
    'Plymouth Albion', 'Rams', 'Sale FC', 'Rosslyn Park', 'Blackheath',
    'Bishop\'s Stortford', 'Leicester Lions', 'Cinderford', 'Sedgley Park',
    'Taunton Titans', 'Birmingham Moseley', 'Darlington Mowden Park', 'Esher',
    
    // Regional & Counties Leagues
    'Devonport Services', 'Exmouth', 'Barnstaple', 'Brixham', 'Camborne',
    'Launceston', 'Okehampton', 'Chew Valley', 'St Austell', 'Matson',
    'Lydney', 'Weston-super-Mare', 'Ivybridge', 'Newton Abbot',
    'Cullompton', 'Teignmouth', 'Wellington', 'Wadebridge Camels',
    'Truro', 'Sidmouth', 'Crediton', 'Topsham', 'Kingsbridge',
    'Tiverton', 'Bideford', 'Torquay Athletic', 'Paignton', 'Penryn',
    'Falmouth', 'Penzance & Newlyn', 'Redruth', 'Hayle', 'Saltash',
    
    // Plymouth & District / Local Clubs
    'Plymstock Oaks', 'Plymouth Argaum', 'Plymstock Albion Oaks', 'OPMs', 'Tamar Saracens',
    'Old Techs', 'Salcombe', 'Totnes', 'Dartmouth', 'Buckfastleigh Ramblers',
    'South Molton', 'North Tawton', 'Ilfracombe', 'Torrington',
    'Honiton', 'Ottery St Mary', 'Exeter Athletic', 'Exeter Saracens',
    'Withycombe', 'Newquay Hornets', 'St Ives', 'Helston', 'Bodmin',
    'Liskeard-Looe', 'Stithians', 'Veor', 'Lankelly-Fowey', 'Camelford',
    'St Just', 'Redruth Albany', 'Perranporth', 'Roseland',
  ];

  @override
  void initState() {
    super.initState();
    _filteredTeams = List.from(_indexedTeams)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _loadDatabaseTeams();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
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
                child: Icon(Icons.sports_rugby, color: theme.goldAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Search RFU Teams',
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
        width: MediaQuery.of(context).size.width > 600 ? 480 : MediaQuery.of(context).size.width * 0.92,
        height: (MediaQuery.of(context).size.height * 0.72).clamp(380.0, 560.0),
        child: Column(
          children: [
            TextField(
              controller: _filterController,
              focusNode: _searchFocusNode,
              autofocus: true,
              style: TextStyle(color: theme.textPrimary, fontSize: 14),
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
                hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: theme.goldAccent, size: 20),
                suffixIcon: _isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.goldAccent)),
                      )
                    : null,
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
            const SizedBox(height: 12),
            Expanded(
              child: _filteredTeams.isEmpty
                  ? Center(
                      child: Text('No matching RFU teams found', style: TextStyle(color: theme.textMuted)),
                    )
                  : ListView.separated(
                      itemCount: _filteredTeams.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: theme.cardBorder),
                      itemBuilder: (context, index) {
                        final teamName = _filteredTeams[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.shield, color: theme.goldAccent, size: 18),
                          title: Text(
                            teamName,
                            style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 12, color: theme.textMuted),
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
