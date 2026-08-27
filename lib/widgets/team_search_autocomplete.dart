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
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showDropdown = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _showDropdown = false;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await ApiService.suggestTeams(query.trim());
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
          _showDropdown = results.isNotEmpty;
        });
      }
    });
  }

  void _selectTeam(String teamName) {
    _controller.text = teamName;
    setState(() => _showDropdown = false);
    widget.onTeamSelected(teamName);
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
            controller: _controller,
            focusNode: _focusNode,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            onChanged: _onTextChanged,
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                _selectTeam(val.trim());
              }
            },
            decoration: InputDecoration(
              hintText: 'Search Team (e.g. Exeter)...',
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
                  : const Icon(Icons.search, color: AppTheme.textMuted, size: 18),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _suggestions = [];
                          _showDropdown = false;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.cardBorder),
              ),
            ),
          ),
        ),

        // Autocomplete Suggestions Dropdown Popup
        if (_showDropdown && _suggestions.isNotEmpty)
          Container(
            width: widget.width,
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
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
                final isClub = item['type'] == 'club';

                return ListTile(
                  dense: true,
                  leading: Icon(
                    isClub ? Icons.sports_rugby : Icons.shield,
                    size: 16,
                    color: AppTheme.goldAccent,
                  ),
                  title: Text(
                    teamName,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onTap: () => _selectTeam(teamName),
                );
              },
            ),
          ),
      ],
    );
  }
}
