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
  final LayerLink _layerLink = LayerLink();

  Timer? _debounceTimer;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _suggestions.isNotEmpty) {
        _showOverlay();
      } else if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _hideOverlay();
        });
      }
    });
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _hideOverlay();
      return;
    }

    setState(() => _isLoading = true);

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      final results = await ApiService.suggestTeams(trimmed);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
        if (results.isNotEmpty && _focusNode.hasFocus) {
          _showOverlay();
        } else {
          _hideOverlay();
        }
      }
    });
  }

  void _showOverlay() {
    _hideOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size(widget.width, 40);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
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
                  final isClub = item['type'] == 'club' || item['listType'] == 'TeamType';

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: Icon(
                      isClub ? Icons.sports_rugby : Icons.shield,
                      size: 18,
                      color: AppTheme.goldAccent,
                    ),
                    title: Text(
                      teamName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => _selectTeam(teamName),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectTeam(String teamName) {
    _controller.text = teamName;
    _hideOverlay();
    _focusNode.unfocus();
    widget.onTeamSelected(teamName);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
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
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _suggestions = [];
                        _isLoading = false;
                      });
                      _hideOverlay();
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
    );
  }
}
