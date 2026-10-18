import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/player_appearance.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

enum PlayerSearchMode { player, team }

/// Search player appearances for one or more seasons, either by player name
/// (one card per player listing every team and season they turned out for)
/// or by team (picked from a dropdown of teams with synced lineups, showing
/// that team's squad, most appearances first).
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
  final TextEditingController _playerController = TextEditingController();
  final TextEditingController _teamController = TextEditingController();
  final FocusNode _playerFocusNode = FocusNode();
  final FocusNode _teamFocusNode = FocusNode();
  Timer? _debounce;

  late Set<String> _selectedSeasons;
  PlayerSearchMode _mode = PlayerSearchMode.player;
  List<PlayerSeasonAppearance> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  /// Teams with synced lineups in the selected seasons (team dropdown).
  List<AppearanceTeam> _teams = [];
  bool _teamsLoading = false;
  AppearanceTeam? _selectedTeam;

  /// Bumped per request so a slow earlier response can't overwrite a newer one.
  int _searchGeneration = 0;
  int _teamsGeneration = 0;

  /// Player whose match-by-match appearances are shown in place of the
  /// search results (null = showing results).
  PlayerSeasonAppearance? _detailPlayer;
  List<PlayerMatchAppearance> _detailMatches = [];
  bool _detailLoading = false;
  int _detailGeneration = 0;

  bool get _allSeasons => _selectedSeasons.length == widget.seasons.length;

  /// Season filter for queries; null means every season (including any not
  /// in [PlayerSearchDialog.seasons]).
  List<String>? get _seasonFilter => _allSeasons ? null : _selectedSeasons.toList();

  bool get _multiSeason => _allSeasons || _selectedSeasons.length > 1;

  @override
  void initState() {
    super.initState();
    final initial = widget.seasons.contains(widget.initialSeason)
        ? widget.initialSeason
        : (widget.seasons.isNotEmpty ? widget.seasons.first : widget.initialSeason);
    _selectedSeasons = {initial};

    final team = widget.initialTeam?.trim() ?? '';
    if (team.isNotEmpty) {
      _mode = PlayerSearchMode.team;
      _teamController.text = team;
    }
    _loadTeams(selectByName: team.isNotEmpty ? team : null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      (_mode == PlayerSearchMode.player ? _playerFocusNode : _teamFocusNode).requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _playerFocusNode.dispose();
    _teamFocusNode.dispose();
    _playerController.dispose();
    _teamController.dispose();
    super.dispose();
  }

  // --- Data ---------------------------------------------------------------

  /// Reloads the team dropdown for the selected seasons. [selectByName]
  /// picks a team by exact name once loaded (e.g. the main screen's team).
  Future<void> _loadTeams({String? selectByName}) async {
    final generation = ++_teamsGeneration;
    setState(() => _teamsLoading = true);
    final teams = await SupabaseService.fetchAppearanceTeams(seasons: _seasonFilter);
    if (!mounted || generation != _teamsGeneration) return;

    AppearanceTeam? selected;
    final wantedId = _selectedTeam?.teamId;
    final wantedName = selectByName?.toLowerCase();
    for (final t in teams) {
      if ((wantedId != null && t.teamId == wantedId) ||
          (wantedName != null && t.teamName.toLowerCase() == wantedName)) {
        selected = t;
        break;
      }
    }
    setState(() {
      _teams = teams;
      _teamsLoading = false;
      // Keep the current team selected if it still has lineups in these seasons
      _selectedTeam = selected ?? (wantedId != null ? _selectedTeam : null);
      if (selected != null) _teamController.text = selected.teamName;
    });
    if (_mode == PlayerSearchMode.team) {
      if (_selectedTeam != null || selectByName != null) _search();
    }
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final isPlayer = _mode == PlayerSearchMode.player;
    final query = (isPlayer ? _playerController : _teamController).text.trim();
    final teamId = isPlayer ? null : _selectedTeam?.teamId;
    final generation = ++_searchGeneration;
    if (teamId == null && query.length < 2) {
      setState(() {
        _results = [];
        _isLoading = false;
        _hasSearched = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final results = await SupabaseService.searchPlayerAppearances(
      seasons: _seasonFilter,
      playerQuery: isPlayer ? query : null,
      teamId: teamId,
      // Typed text that wasn't picked from the dropdown: match by name
      teamQuery: !isPlayer && teamId == null ? query : null,
    );
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _results = results;
      _isLoading = false;
      _hasSearched = true;
    });
  }

  void _setMode(PlayerSearchMode mode) {
    if (_mode == mode) {
      if (_detailPlayer != null) setState(() => _detailPlayer = null);
      return;
    }
    setState(() {
      _detailPlayer = null;
      _mode = mode;
      _results = [];
      _hasSearched = false;
    });
    _search();
    (mode == PlayerSearchMode.player ? _playerFocusNode : _teamFocusNode).requestFocus();
  }

  void _setSeasons(Set<String> seasons) {
    if (seasons.isEmpty) return; // at least one season stays selected
    setState(() => _selectedSeasons = seasons);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadTeams();
      if (_mode == PlayerSearchMode.player) _search();
      if (_detailPlayer != null) _loadPlayerMatches();
    });
  }

  void _selectTeam(AppearanceTeam team) {
    setState(() => _selectedTeam = team);
    _teamFocusNode.unfocus();
    _search();
  }

  Future<void> _openRfuProfile(PlayerSeasonAppearance row) async {
    if (row.nameWithheld) return;
    await launchUrl(Uri.parse(row.rfuProfileUrl), mode: LaunchMode.externalApplication);
  }

  void _openPlayerDetail(PlayerSeasonAppearance player) {
    setState(() {
      _detailPlayer = player;
      _detailMatches = [];
    });
    _loadPlayerMatches();
  }

  void _closePlayerDetail() => setState(() => _detailPlayer = null);

  Future<void> _loadPlayerMatches() async {
    final player = _detailPlayer;
    if (player == null) return;
    final generation = ++_detailGeneration;
    setState(() => _detailLoading = true);
    final matches = await SupabaseService.fetchPlayerMatches(
      playerId: player.playerId,
      seasons: _seasonFilter,
    );
    if (!mounted || generation != _detailGeneration) return;
    setState(() {
      _detailMatches = matches;
      _detailLoading = false;
    });
  }

  // --- Text helpers -------------------------------------------------------

  /// "2025-2026" -> "2025-26"
  static String _shortSeason(String season) {
    final m = RegExp(r'^(\d{4})-\d{2}(\d{2})$').firstMatch(season);
    return m == null ? season : '${m.group(1)}-${m.group(2)}';
  }

  String get _seasonsLabel {
    if (_allSeasons) return 'All seasons';
    if (_selectedSeasons.length == 1) return 'Season ${_selectedSeasons.first}';
    return '${_selectedSeasons.length} seasons';
  }

  String get _seasonsPhrase {
    if (_allSeasons) return 'across all seasons';
    if (_selectedSeasons.length == 1) return 'for ${_selectedSeasons.first}';
    final ordered = widget.seasons.where(_selectedSeasons.contains).map(_shortSeason);
    return 'for ${ordered.join(', ')}';
  }

  static String _plural(int n, String one, [String? many]) =>
      '$n ${n == 1 ? one : (many ?? '${one}s')}';

  static bool _matchesWords(String text, String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    var from = 0;
    final lower = text.toLowerCase();
    for (final w in words) {
      final at = lower.indexOf(w, from);
      if (at < 0) return false;
      from = at + w.length;
    }
    return true;
  }

  // --- Layout -------------------------------------------------------------

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
                _buildSeasonPicker(theme),
              ],
            ),
            const SizedBox(height: 10),
            if (_detailPlayer != null)
              Expanded(child: _buildPlayerDetail(theme, _detailPlayer!))
            else ...[
              _mode == PlayerSearchMode.player
                  ? _buildPlayerField(theme)
                  : _buildTeamField(theme),
              const SizedBox(height: 10),
              Expanded(child: _buildResults(theme)),
            ],
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
      onSelected: (_) => _setMode(mode),
    );
  }

  /// Button opening a checklist of seasons (plus "All seasons") that stays
  /// open while ticking, so several seasons can be picked in one go.
  Widget _buildSeasonPicker(AppThemeMode theme) {
    final textStyle = TextStyle(
      color: theme.textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(theme.surfaceBg),
        side: WidgetStatePropertyAll(BorderSide(color: theme.cardBorder)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      menuChildren: [
        CheckboxMenuButton(
          value: _allSeasons,
          closeOnActivate: false,
          onChanged: (checked) => _setSeasons(
            checked == true ? widget.seasons.toSet() : {widget.seasons.first},
          ),
          child: Text('All seasons', style: textStyle),
        ),
        Divider(height: 1, color: theme.cardBorder),
        for (final season in widget.seasons)
          CheckboxMenuButton(
            value: _selectedSeasons.contains(season),
            closeOnActivate: false,
            onChanged: (checked) {
              final next = {..._selectedSeasons};
              checked == true ? next.add(season) : next.remove(season);
              _setSeasons(next);
            },
            child: Text(
              season,
              style: textStyle.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
      ],
      builder: (context, controller, _) {
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: theme.goldAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.goldAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month, color: theme.textPrimary, size: 15),
                const SizedBox(width: 6),
                Text(_seasonsLabel, style: textStyle),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down, color: theme.textPrimary, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration(
    AppThemeMode theme, {
    required String hint,
    required bool loading,
    required TextEditingController controller,
    required VoidCallback onClear,
    Widget? trailing,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
      prefixIcon: Icon(Icons.search, color: theme.goldAccent, size: 20),
      suffixIcon: loading
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: theme.goldAccent),
              ),
            )
          : (controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: theme.textMuted, size: 18),
                  onPressed: onClear,
                )
              : trailing),
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
    );
  }

  Widget _buildPlayerField(AppThemeMode theme) {
    return TextField(
      controller: _playerController,
      focusNode: _playerFocusNode,
      style: TextStyle(color: theme.textPrimary, fontSize: 14),
      onChanged: (_) => _scheduleSearch(),
      onSubmitted: (_) => _search(),
      textInputAction: TextInputAction.search,
      decoration: _fieldDecoration(
        theme,
        hint: 'Player name (e.g. Harry Toghill)...',
        loading: _isLoading,
        controller: _playerController,
        onClear: () {
          _playerController.clear();
          _search();
        },
      ),
    );
  }

  /// Team name field with a dropdown of teams that have synced lineups,
  /// filtered as you type (like the main screen's team search).
  Widget _buildTeamField(AppThemeMode theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth;
        return RawAutocomplete<AppearanceTeam>(
          textEditingController: _teamController,
          focusNode: _teamFocusNode,
          displayStringForOption: (t) => t.teamName,
          optionsBuilder: (value) {
            final q = value.text.trim();
            // Showing the picked team's name: offer the full list again
            if (q.isEmpty || q == _selectedTeam?.teamName) return _teams;
            return _teams.where((t) => _matchesWords(t.teamName, q));
          },
          onSelected: _selectTeam,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(color: theme.textPrimary, fontSize: 14),
              textInputAction: TextInputAction.search,
              onChanged: (text) {
                if (_selectedTeam != null && text != _selectedTeam!.teamName) {
                  setState(() => _selectedTeam = null);
                } else {
                  setState(() {}); // refresh the clear button
                }
              },
              onSubmitted: (text) {
                // Enter picks the highlighted dropdown entry if there is one;
                // otherwise fall back to a name search for the typed text.
                onFieldSubmitted();
                if (_selectedTeam == null) _search();
              },
              decoration: _fieldDecoration(
                theme,
                hint: _teamsLoading
                    ? 'Loading teams...'
                    : 'Pick or type a team (${_plural(_teams.length, 'team')} with lineups)',
                loading: _isLoading || _teamsLoading,
                controller: controller,
                onClear: () {
                  controller.clear();
                  setState(() {
                    _selectedTeam = null;
                    _results = [];
                    _hasSearched = false;
                  });
                  focusNode.requestFocus();
                },
                trailing: Icon(Icons.arrow_drop_down, color: theme.textMuted),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final highlighted = AutocompleteHighlightedOption.of(context);
            final list = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: theme.surfaceBg,
                elevation: 8,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: fieldWidth,
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.goldAccent, width: 1.2),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: theme.cardBorder),
                    itemBuilder: (context, index) {
                      final team = list[index];
                      final details = [
                        _plural(team.matches, 'match', 'matches'),
                        if (_multiSeason) _plural(team.seasons.length, 'season'),
                      ].join(' · ');
                      return InkWell(
                        onTap: () => onSelected(team),
                        child: Container(
                          color: index == highlighted
                              ? theme.goldAccent.withValues(alpha: 0.12)
                              : null,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.shield, size: 16, color: theme.goldAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  team.teamName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                details,
                                style: TextStyle(color: theme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
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
            : 'Pick a team to see its squad',
        'Shows starts and bench appearances $_seasonsPhrase.',
      );
    }
    if (_results.isEmpty) {
      return _buildMessage(
        theme,
        Icons.search_off,
        'No appearances found $_seasonsPhrase',
        'Lineups are synced club by club, so this team or player may not '
            'have been synced yet.',
      );
    }
    return _mode == PlayerSearchMode.player
        ? _buildPlayerResults(theme)
        : _buildTeamResults(theme);
  }

  /// One card per player, listing each team (and season, when several are
  /// selected) they appeared for.
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
    for (final rows in players) {
      rows.sort((a, b) {
        final bySeason = b.season.compareTo(a.season);
        return bySeason != 0 ? bySeason : b.appearances.compareTo(a.appearances);
      });
    }

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
            onTap: () => _openPlayerDetail(player),
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
                      _countBadge(theme, _plural(_total(rows), 'app')),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18, color: theme.textMuted),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.only(left: 26, top: 3),
                      child: Row(
                        children: [
                          if (_multiSeason)
                            SizedBox(
                              width: 58,
                              child: Text(
                                _shortSeason(row.season),
                                style: TextStyle(
                                  color: theme.goldAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
                            '${_plural(row.starts, 'start')} · ${row.bench} bench',
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

  /// A squad table per team, most appearances first. With several seasons
  /// selected, each player's totals are summed across them.
  Widget _buildTeamResults(AppThemeMode theme) {
    final byTeam = <String, Map<int, _SquadLine>>{};
    // Each team is named as in its most recent selected season
    final latestName = <String, ({String season, String name})>{};
    for (final row in _results) {
      final key = row.teamId?.toString() ?? row.teamName;
      final current = latestName[key];
      if (current == null || row.season.compareTo(current.season) > 0) {
        latestName[key] = (season: row.season, name: row.teamName);
      }
      byTeam.putIfAbsent(key, () => {}).putIfAbsent(row.playerId, () => _SquadLine(row)).add(row);
    }
    String teamName(String key) => latestName[key]!.name;
    final teams = byTeam.entries.toList()
      ..sort((a, b) => teamName(a.key).compareTo(teamName(b.key)));

    final numberStyle = TextStyle(color: theme.textPrimary, fontSize: 13);
    final headerStyle = TextStyle(
      color: theme.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );

    Widget statCell(String text, TextStyle style, {double width = 48}) =>
        SizedBox(width: width, child: Text(text, textAlign: TextAlign.center, style: style));

    return ListView(
      children: [
        for (final team in teams) ...[
          Builder(builder: (_) {
            final squad = team.value.values.toList()
              ..sort((a, b) {
                final apps = b.appearances.compareTo(a.appearances);
                return apps != 0 ? apps : a.player.displayName.compareTo(b.player.displayName);
              });
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                          teamName(team.key),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _plural(squad.length, 'player'),
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
                      if (_multiSeason) statCell('SEASONS', headerStyle, width: 64),
                      statCell('APPS', headerStyle),
                      statCell('START', headerStyle),
                      statCell('BENCH', headerStyle),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
                for (final line in squad)
                  InkWell(
                    onTap: () => _openPlayerDetail(line.player),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: theme.cardBorder, width: 0.6)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              line.player.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: line.player.nameWithheld ? theme.textMuted : theme.textPrimary,
                                fontSize: 13,
                                fontStyle: line.player.nameWithheld ? FontStyle.italic : FontStyle.normal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_multiSeason) statCell('${line.seasons.length}', numberStyle, width: 64),
                          statCell('${line.appearances}', numberStyle.copyWith(fontWeight: FontWeight.bold)),
                          statCell('${line.starts}', numberStyle),
                          statCell('${line.bench}', numberStyle),
                          Icon(Icons.chevron_right, size: 16, color: theme.textMuted),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
              ],
            );
          }),
        ],
      ],
    );
  }

  /// Match-by-match appearances for one player in the selected seasons,
  /// newest first, grouped by season.
  Widget _buildPlayerDetail(AppThemeMode theme, PlayerSeasonAppearance player) {
    final matches = _detailMatches;
    final starts = matches.where((m) => !m.isSubstitute).length;
    final results = matches.map((m) => m.result).where((r) => r.isNotEmpty).toList();
    String count(String r) => '${results.where((x) => x == r).length}$r';

    final bySeason = <String, List<PlayerMatchAppearance>>{};
    for (final m in matches) {
      bySeason.putIfAbsent(m.season, () => []).add(m);
    }
    final seasons = bySeason.keys.toList()..sort((a, b) => b.compareTo(a));
    final playedForSeveralTeams = matches.map((m) => m.teamId ?? m.teamName).toSet().length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back to results',
              icon: Icon(Icons.arrow_back, color: theme.goldAccent),
              onPressed: _closePlayerDetail,
            ),
            Expanded(
              child: Text(
                player.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: player.nameWithheld ? theme.textMuted : theme.textPrimary,
                  fontStyle: player.nameWithheld ? FontStyle.italic : FontStyle.normal,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!player.nameWithheld)
              TextButton.icon(
                onPressed: () => _openRfuProfile(player),
                icon: Icon(Icons.open_in_new, size: 14, color: theme.goldAccent),
                label: Text(
                  'RFU stats',
                  style: TextStyle(color: theme.goldAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        if (!_detailLoading && matches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _countBadge(theme, _plural(matches.length, 'app')),
                _countBadge(theme, '${_plural(starts, 'start')} · ${matches.length - starts} bench'),
                if (results.isNotEmpty)
                  _countBadge(theme, '${count('W')} ${count('D')} ${count('L')}'),
              ],
            ),
          ),
        Expanded(
          child: _detailLoading
              ? Center(child: CircularProgressIndicator(color: theme.goldAccent))
              : matches.isEmpty
                  ? _buildMessage(
                      theme,
                      Icons.search_off,
                      'No appearances $_seasonsPhrase',
                      'Try ticking more seasons.',
                    )
                  : ListView(
                      children: [
                        if (playedForSeveralTeams || _multiSeason)
                          _buildTeamTotals(theme, matches),
                        for (final season in seasons) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.goldAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Season $season',
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  _plural(bySeason[season]!.length, 'app'),
                                  style: TextStyle(color: theme.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          for (final m in bySeason[season]!)
                            _buildMatchRow(theme, m, showTeam: playedForSeveralTeams),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  /// Appearances per team over the selected seasons ("all time" when every
  /// season is ticked). Teams are keyed by RFU team id, so a renamed club
  /// (e.g. Plymstock Albion Oaks -> Plymstock Oaks) counts as one team under
  /// its most recent name.
  Widget _buildTeamTotals(AppThemeMode theme, List<PlayerMatchAppearance> matches) {
    final byTeam = <Object, List<PlayerMatchAppearance>>{};
    for (final m in matches) {
      byTeam.putIfAbsent(m.teamId ?? m.teamName, () => []).add(m);
    }
    final teams = byTeam.values.toList()
      ..sort((a, b) {
        final apps = b.length.compareTo(a.length);
        return apps != 0 ? apps : a.first.teamName.compareTo(b.first.teamName);
      });

    // The player's own matches may only go up to a team's old name (e.g. one
    // game for "Plymstock Albion Oaks II" in 2022-23); the team dropdown data
    // carries each team's latest name in the selected seasons.
    final latestNames = {for (final t in _teams) t.teamId: t.teamName};
    String teamName(List<PlayerMatchAppearance> rows) =>
        latestNames[rows.first.teamId] ?? rows.first.teamName;

    final headerStyle = TextStyle(color: theme.textMuted, fontSize: 11, fontWeight: FontWeight.bold);
    final numberStyle = TextStyle(color: theme.textPrimary, fontSize: 13);
    Widget cell(String text, TextStyle style, {double width = 48}) =>
        SizedBox(width: width, child: Text(text, textAlign: TextAlign.center, style: style));

    Widget line(String name, String seasonsText, int apps, int starts, int bench, {bool bold = false}) {
      final weight = bold ? FontWeight.bold : FontWeight.normal;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.cardBorder, width: 0.6)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (seasonsText.isNotEmpty)
                    Text(seasonsText, style: TextStyle(color: theme.textMuted, fontSize: 11)),
                ],
              ),
            ),
            cell('$apps', numberStyle.copyWith(fontWeight: FontWeight.bold)),
            cell('$starts', numberStyle.copyWith(fontWeight: weight)),
            cell('$bench', numberStyle.copyWith(fontWeight: weight)),
          ],
        ),
      );
    }

    String seasonSpan(List<PlayerMatchAppearance> rows) {
      final seasons = rows.map((m) => m.season).toSet().toList()..sort();
      final span = seasons.length == 1
          ? _shortSeason(seasons.first)
          : '${_shortSeason(seasons.first)} to ${_shortSeason(seasons.last)}';
      return '$span · ${_plural(seasons.length, 'season')}';
    }

    int startsOf(List<PlayerMatchAppearance> rows) => rows.where((m) => !m.isSubstitute).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4, bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.goldAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _allSeasons ? 'All-time totals by team' : 'Totals by team $_seasonsPhrase',
            style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text('TEAM', style: headerStyle)),
              cell('APPS', headerStyle),
              cell('START', headerStyle),
              cell('BENCH', headerStyle),
            ],
          ),
        ),
        for (final rows in teams)
          line(
            teamName(rows),
            seasonSpan(rows),
            rows.length,
            startsOf(rows),
            rows.length - startsOf(rows),
          ),
        if (teams.length > 1)
          line('Total', '', matches.length, startsOf(matches), matches.length - startsOf(matches), bold: true),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMatchRow(AppThemeMode theme, PlayerMatchAppearance m, {required bool showTeam}) {
    final resultColor = switch (m.result) {
      'W' => theme.emeraldAccent,
      'L' => theme.rubyAccent,
      _ => theme.textMuted,
    };
    final score = m.teamScore != null && m.opponentScore != null
        ? '${m.teamScore}-${m.opponentScore}'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.cardBorder, width: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              m.matchDate == null ? '' : DateFormat('EEE d MMM').format(m.matchDate!),
              style: TextStyle(color: theme.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m.isHome ? 'v' : '@'} ${m.opponent}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showTeam)
                  Text(
                    'for ${m.teamName}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (score.isNotEmpty) ...[
            Text(score, style: TextStyle(color: theme.textPrimary, fontSize: 12)),
            const SizedBox(width: 6),
            Container(
              width: 20,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                m.result,
                style: TextStyle(color: resultColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Tooltip(
            message: m.isSubstitute ? 'Named on the bench' : 'Started, shirt ${m.shirt}',
            child: Container(
              width: 34,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: m.isSubstitute ? null : theme.goldAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: m.isSubstitute ? theme.cardBorder : theme.goldAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                m.shirt,
                style: TextStyle(
                  color: m.isSubstitute ? theme.textMuted : theme.goldAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
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

/// One player's totals for one team, summed over the selected seasons.
class _SquadLine {
  final PlayerSeasonAppearance player;
  final Set<String> seasons = {};
  int appearances = 0;
  int starts = 0;
  int bench = 0;

  _SquadLine(this.player);

  void add(PlayerSeasonAppearance row) {
    seasons.add(row.season);
    appearances += row.appearances;
    starts += row.starts;
    bench += row.bench;
  }
}
