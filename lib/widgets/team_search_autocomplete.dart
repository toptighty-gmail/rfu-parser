import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TeamSearchAutocomplete extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onTeamSelected;
  final double width;

  const TeamSearchAutocomplete({
    super.key,
    this.initialValue,
    required this.onTeamSelected,
    this.width = 240,
  });

  @override
  State<TeamSearchAutocomplete> createState() => _TeamSearchAutocompleteState();
}

class _TeamSearchAutocompleteState extends State<TeamSearchAutocomplete> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounceTimer;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  bool _showMenu = false;
  bool _isSelecting = false;

  static const List<Map<String, dynamic>> _localTeamDb = [
    {'name': 'Plymstock Oaks'},
    {'name': 'Plymstock Oaks II'},
    {'name': 'Plymstock Oaks Colts'},
    {'name': 'Devonport Services'},
    {'name': 'Devonport Services II'},
    {'name': 'Devonport Services Colts'},
    {'name': 'Plymouth Albion'},
    {'name': 'Exeter Chiefs'},
    {'name': 'Topsham'},
    {'name': 'Topsham II'},
    {'name': 'Topsham Colts'},
    {'name': 'Camborne'},
    {'name': 'Redruth'},
    {'name': 'Exmouth'},
    {'name': 'Barnstaple'},
    {'name': 'Bideford'},
    {'name': 'Ivybridge'},
    {'name': 'Newton Abbot'},
    {'name': 'Crediton'},
    {'name': 'Okehampton'},
    {'name': 'Sidmouth'},
    {'name': 'Teignmouth'},
    {'name': 'Tavistock'},
    {'name': 'Tavistock II'},
    {'name': 'Tavistock Colts'},
    {'name': 'Paignton'},
    {'name': 'Torquay Athletic'},
    {'name': 'Richmond'},
    {'name': 'Bath Rugby'},
    {'name': 'Gloucester Rugby'},
    {'name': 'Bristol Bears'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _textController.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    if (_isSelecting) return;
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
        _showMenu = false;
      });
      return;
    }

    // 1. Instant client-side match first
    final qLower = trimmed.toLowerCase();
    final localMatches = _localTeamDb
        .where((t) => (t['name'] as String).toLowerCase().contains(qLower))
        .toList();

    setState(() {
      _suggestions = localMatches;
      _showMenu = localMatches.isNotEmpty;
      _isLoading = true;
    });

    // 2. Fetch live suggestions from API
    _debounceTimer = Timer(const Duration(milliseconds: 150), () async {
      if (_isSelecting) return;
      final results = await ApiService.suggestTeams(trimmed);
      if (mounted && !_isSelecting) {
        final combined = results.isNotEmpty ? results : localMatches;
        setState(() {
          _suggestions = combined;
          _isLoading = false;
          _showMenu = combined.isNotEmpty;
        });
      }
    });
  }

  void _selectTeam(String teamName) {
    _isSelecting = true;
    _debounceTimer?.cancel();
    _textController.text = teamName;
    setState(() {
      _suggestions = [];
      _showMenu = false;
      _isLoading = false;
    });
    _focusNode.unfocus();
    widget.onTeamSelected(teamName);
    Future.microtask(() => _isSelecting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: widget.width,
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            onChanged: _onQueryChanged,
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                _selectTeam(val.trim());
              }
            },
            decoration: InputDecoration(
              hintText: 'Search Team (e.g. Plymstock)...',
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              fillColor: AppTheme.darkBg,
              filled: true,
              prefixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.goldAccent),
                      ),
                    )
                  : const Icon(Icons.search, color: AppTheme.goldAccent, size: 18),
              suffixIcon: _textController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                      onPressed: () {
                        _textController.clear();
                        setState(() {
                          _suggestions = [];
                          _isLoading = false;
                          _showMenu = false;
                        });
                      },
                    )
                  : null,
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
        ),

        // Responsive Dropdown Menu with instant onTap handler
        if (_showMenu && _suggestions.isNotEmpty)
          Container(
            width: widget.width,
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.goldAccent, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
              itemBuilder: (context, index) {
                final item = _suggestions[index];
                final teamName = item['name'] ?? item['team_name'] ?? '';

                return InkWell(
                  onTapDown: (_) => _selectTeam(teamName),
                  onTap: () => _selectTeam(teamName),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.sports_rugby, size: 18, color: AppTheme.goldAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            teamName,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
