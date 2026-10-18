import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/player_appearance.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

enum PlayerSearchMode { player, team }

/// Search player appearances for a season, either by player name (one card
/// per player listing every team they turned out for) or by team (that
/// team's squad, most appearances first).
class PlayerSearchDialog extends StatefulWidget {
  final List<String> seasons;
  final String initialSeason;

  /// When set, the dialog opens in team mode showing this team's squad.
  final String? initialTeam;

  const PlayerSearchDialog({
    super.key,
    required this.seasons,
    required this.initialSeason,
    this.initialTeam,
  });

  @override
  State<PlayerSearchDialog> createState() => _PlayerSearchDialogState();
}

class _PlayerSearchDialogState extends State<PlayerSearchDialog> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  late String _season;
  PlayerSearchMode _mode = PlayerSearchMode.player;
  List<PlayerSeasonAppearance> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  /// Bumped per search so a slow earlier response can't overwrite a newer one.
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _season = widget.seasons.contains(widget.initialSeason)
        ? widget.initialSeason
        : (widget.seasons.isNotEmpty ? widget.seasons.first : widget.initialSeason);
    final team = widget.initialTeam?.trim() ?? '';
    if (team.isNotEmpty) {
      _mode = PlayerSearchMode.team;
      _queryController.text = team;
      _search();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocusNode.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final query = _queryController.text.trim();
    final generation = ++_searchGeneration;
    if (query.length < 2) {
      setState(() {
        _results = [];
        _isLoading = false;
        _hasSearched = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final results = await SupabaseService.searchPlayerAppearances(
      season: _season,
      playerQuery: _mode == PlayerSearchMode.player ? query : null,
      teamQuery: _mode == PlayerSearchMode.team ? query : null,
    );
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _results = results;
      _isLoading = false;
      _hasSearched = true;
    });
  }

  Future<void> _openRfuProfile(PlayerSeasonAppearance row) async {
    if (row.nameWithheld) return;
    await launchUrl(Uri.parse(row.rfuProfileUrl), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.currentMode;
    final screen = MediaQuery.of(context).size;

    return AlertDialog(
      backgroundColor: theme.surfaceBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.cardBorder, width: 1.2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: theme.goldAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person_search, color: theme.goldAccent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Player Appearances',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: screen.width > 640 ? 580 : screen.width * 0.94,
        height: (screen.height * 0.75).clamp(400.0, 680.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildModeChip(theme, PlayerSearchMode.player, Icons.person, 'By player'),
                _buildModeChip(theme, PlayerSearchMode.team, Icons.shield, 'By team'),
                _buildSeasonSelector(theme),
              ],
            ),
            const SizedBox(height: 10),
            _buildSearchField(theme),
            const SizedBox(height: 10),
            Expanded(child: _buildResults(theme)),
            const SizedBox(height: 8),
            Text(
              'From RFU electronic match cards. Bench = named as a replacement; '
              'lineups don\'t show whether they came on.',
              style: TextStyle(color: theme.textMuted, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(
    AppThemeMode theme,
    PlayerSearchMode mode,
    IconData icon,
    String label,
  ) {
    final selected = _mode == mode;
    final fg = selected ? (theme.isCustom ? Colors.white : Colors.black) : theme.textPrimary;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(icon, size: 16, color: fg),
      label: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      selectedColor: theme.goldAccent,
      backgroundColor: theme.goldAccent.withValues(alpha: 0.12),
      side: BorderSide(color: theme.goldAccent.withValues(alpha: selected ? 1 : 0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) {
        if (selected) return;
        setState(() => _mode = mode);
        _search();
        _searchFocusNode.requestFocus();
      },
    );
  }

  Widget _buildSeasonSelector(AppThemeMode theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.goldAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.goldAccent.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _season,
          dropdownColor: theme.surfaceBg,
          isDense: true,
          icon: Icon(Icons.calendar_month, color: theme.textPrimary, size: 15),
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          items: widget.seasons
              .map((s) => DropdownMenuItem(value: s, child: Text('Season $s')))
              .toList(),
          onChanged: (s) {
            if (s == null || s == _season) return;
            setState(() => _season = s);
            _search();
          },
        ),
      ),
    );
  }

  Widget _buildSearchField(AppThemeMode theme) {
    return TextField(
      controller: _queryController,
      focusNode: _searchFocusNode,
      style: TextStyle(color: theme.textPrimary, fontSize: 14),
      onChanged: _onQueryChanged,
      onSubmitted: (_) => _search(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: _mode == PlayerSearchMode.player
            ? 'Player name (e.g. Harry Toghill)...'
            : 'Team name (e.g. Plymstock Oaks)...',
        hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
        prefixIcon: Icon(Icons.search, color: theme.goldAccent, size: 20),
        suffixIcon: _isLoading
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: theme.goldAccent),
                ),
              )
            : (_queryController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: theme.textMuted, size: 18),
                    onPressed: () {
                      _queryController.clear();
                      _search();
                    },
                  )
                : null),
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
    );
  }

  Widget _buildMessage(AppThemeMode theme, IconData icon, String title, String detail) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.textMuted, size: 36),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(AppThemeMode theme) {
    if (!_hasSearched) {
      if (_isLoading) {
        return Center(child: CircularProgressIndicator(color: theme.goldAccent));
      }
      return _buildMessage(
        theme,
        Icons.groups_outlined,
        _mode == PlayerSearchMode.player
            ? 'Search for a player by name'
            : 'Search for a team to see its squad',
        'Shows starts and bench appearances for the $_season season.',
      );
    }
    if (_results.isEmpty) {
      return _buildMessage(
        theme,
        Icons.search_off,
        'No appearances found for $_season',
        'Lineups are synced club by club, so this team or player may not '
            'have been synced yet.',
      );
    }
    return _mode == PlayerSearchMode.player
        ? _buildPlayerResults(theme)
        : _buildTeamResults(theme);
  }

  /// One card per player, listing each team they appeared for.
  Widget _buildPlayerResults(AppThemeMode theme) {
    final byPlayer = <int, List<PlayerSeasonAppearance>>{};
    for (final row in _results) {
      byPlayer.putIfAbsent(row.playerId, () => []).add(row);
    }
    final players = byPlayer.values.toList()
      ..sort((a, b) {
        final total = _total(b).compareTo(_total(a));
        return total != 0 ? total : a.first.displayName.compareTo(b.first.displayName);
      });

    return ListView.separated(
      itemCount: players.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final rows = players[index];
        final player = rows.first;
        return Material(
          color: theme.darkBg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openRfuProfile(player),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: theme.goldAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          player.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _countBadge(theme, '${_total(rows)} ${_total(rows) == 1 ? 'app' : 'apps'}'),
                      const SizedBox(width: 4),
                      Icon(Icons.open_in_new, size: 14, color: theme.textMuted),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.only(left: 26, top: 3),
                      child: Row(
                        children: [
                          Icon(Icons.shield, size: 13, color: theme.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              row.teamName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: theme.textPrimary, fontSize: 13),
                            ),
                          ),
                          Text(
                            '${row.starts} ${row.starts == 1 ? 'start' : 'starts'} · ${row.bench} bench',
                            style: TextStyle(color: theme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// A squad table per matching team, most appearances first.
  Widget _buildTeamResults(AppThemeMode theme) {
    final byTeam = <String, List<PlayerSeasonAppearance>>{};
    for (final row in _results) {
      byTeam.putIfAbsent(row.teamId?.toString() ?? row.teamName, () => []).add(row);
    }
    final teams = byTeam.values.toList()
      ..sort((a, b) => a.first.teamName.compareTo(b.first.teamName));

    final numberStyle = TextStyle(color: theme.textPrimary, fontSize: 13);
    final headerStyle = TextStyle(
      color: theme.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );

    Widget statCell(String text, TextStyle style) =>
        SizedBox(width: 48, child: Text(text, textAlign: TextAlign.center, style: style));

    return ListView(
      children: [
        for (final squad in teams) ...[
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.goldAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.shield, color: theme.goldAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    squad.first.teamName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${squad.length} players',
                  style: TextStyle(color: theme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text('PLAYER', style: headerStyle)),
                statCell('APPS', headerStyle),
                statCell('START', headerStyle),
                statCell('BENCH', headerStyle),
              ],
            ),
          ),
          for (final row in squad)
            InkWell(
              onTap: row.nameWithheld ? null : () => _openRfuProfile(row),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.cardBorder, width: 0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: row.nameWithheld ? theme.textMuted : theme.textPrimary,
                          fontSize: 13,
                          fontStyle: row.nameWithheld ? FontStyle.italic : FontStyle.normal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    statCell('${row.appearances}', numberStyle.copyWith(fontWeight: FontWeight.bold)),
                    statCell('${row.starts}', numberStyle),
                    statCell('${row.bench}', numberStyle),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _countBadge(AppThemeMode theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.goldAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.goldAccent.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: theme.goldAccent, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  static int _total(List<PlayerSeasonAppearance> rows) =>
      rows.fold(0, (sum, r) => sum + r.appearances);
}
