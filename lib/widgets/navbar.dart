import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../theme/responsive_layout.dart';

class Navbar extends StatelessWidget implements PreferredSizeWidget {
  final String selectedDivision;
  final List<String> divisions;
  final ValueChanged<String> onDivisionSelected;

  final String selectedSeason;
  final List<String> seasons;
  final ValueChanged<String?> onSeasonChanged;

  final String? searchedTeam;
  final ValueChanged<String> onTeamSelected;

  final VoidCallback onOpenDivisionsDirectory;
  final VoidCallback onOpenTeamsDirectory;
  final bool isAdmin;
  final VoidCallback onAdminToggle;
  final VoidCallback onAddFixture;
  final VoidCallback onUploadLogo;
  final VoidCallback onOpenBookletPrint;
  final VoidCallback? onOpenDatabaseMetrics;
  final VoidCallback? onOpenThemeSelector;

  const Navbar({
    super.key,
    required this.selectedDivision,
    required this.divisions,
    required this.onDivisionSelected,
    required this.selectedSeason,
    required this.seasons,
    required this.onSeasonChanged,
    this.searchedTeam,
    required this.onTeamSelected,
    required this.onOpenDivisionsDirectory,
    required this.onOpenTeamsDirectory,
    required this.isAdmin,
    required this.onAdminToggle,
    required this.onAddFixture,
    required this.onUploadLogo,
    required this.onOpenBookletPrint,
    this.onOpenDatabaseMetrics,
    this.onOpenThemeSelector,
  });

  @override
  Size get preferredSize => Size.fromHeight(_baseHeight);

  static const double _baseHeight = 135;
  static const double _mobileBaseHeight = 190;

  /// The AppBar slot height this navbar actually needs at the current width,
  /// including the device's top safe-area inset (notch/status bar) - the
  /// content stacks into an extra row on mobile, so a fixed height overflows
  /// there. Callers should wrap with `PreferredSize(preferredSize:
  /// Size.fromHeight(Navbar.heightFor(context)), child: Navbar(...))`.
  static double heightFor(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final base = isMobile ? _mobileBaseHeight : _baseHeight;
    return base + MediaQuery.of(context).padding.top;
  }

  Widget _buildBrandLogo(
    BuildContext context,
    AppThemeMode theme, {
    bool compact = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: theme.goldAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.sports_rugby, color: theme.goldAccent, size: 22),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(
                  AppConfig.appName,
                  style: TextStyle(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: theme.goldAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.goldAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: theme.goldAccent.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    AppConfig.version,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: theme.goldAccent,
                    ),
                  ),
                ),
              ],
            ),
            if (!compact)
              Text(
                AppConfig.appSubTitle,
                style: TextStyle(fontSize: 10.5, color: theme.textMuted),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeasonSelector(AppThemeMode theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: theme.goldAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.goldAccent.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: seasons.contains(selectedSeason)
              ? selectedSeason
              : (seasons.isNotEmpty ? seasons.first : '2025-2026'),
          dropdownColor: theme.surfaceBg,
          isDense: true,
          icon: Icon(Icons.calendar_month, color: theme.textPrimary, size: 15),
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          items: seasons.map((s) {
            return DropdownMenuItem(value: s, child: Text('Season $s'));
          }).toList(),
          onChanged: onSeasonChanged,
        ),
      ),
    );
  }

  Widget _buildDivisionButton(AppThemeMode theme, bool hasSelectedDivision) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: hasSelectedDivision
            ? theme.goldAccent
            : theme.goldAccent.withValues(alpha: 0.12),
        foregroundColor: hasSelectedDivision ? Colors.black : theme.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(
          color: hasSelectedDivision
              ? theme.goldAccent
              : theme.goldAccent.withValues(alpha: 0.5),
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(
        Icons.emoji_events,
        size: 16,
        color: hasSelectedDivision ? Colors.black : theme.textPrimary,
      ),
      label: Text(
        hasSelectedDivision ? 'Div: $selectedDivision' : 'Select Division...',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: hasSelectedDivision ? Colors.black : theme.textPrimary,
        ),
      ),
      onPressed: onOpenDivisionsDirectory,
    );
  }

  Widget _buildTeamButton(AppThemeMode theme, bool hasSearchedTeam) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: hasSearchedTeam
            ? theme.goldAccent
            : theme.goldAccent.withValues(alpha: 0.12),
        foregroundColor: hasSearchedTeam ? Colors.black : theme.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(
          color: hasSearchedTeam
              ? theme.goldAccent
              : theme.goldAccent.withValues(alpha: 0.5),
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(
        Icons.search,
        size: 16,
        color: hasSearchedTeam ? Colors.black : theme.textPrimary,
      ),
      label: Text(
        hasSearchedTeam ? 'Team: ${searchedTeam!.trim()}' : 'Search Team...',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: hasSearchedTeam ? Colors.black : theme.textPrimary,
        ),
      ),
      onPressed: onOpenTeamsDirectory,
    );
  }

  Widget _mobileActionTile(
    BuildContext context,
    AppThemeMode theme,
    IconData icon,
    String label,
    VoidCallback? onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? theme.goldAccent),
      title: Text(
        label,
        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
      ),
      onTap: onTap == null
          ? null
          : () {
              Navigator.of(context).pop();
              onTap();
            },
    );
  }

  void _showMobileActionsSheet(BuildContext context, AppThemeMode theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              _mobileActionTile(
                sheetContext,
                theme,
                Icons.picture_as_pdf,
                'Print A4 Booklet',
                onOpenBookletPrint,
              ),
              _mobileActionTile(
                sheetContext,
                theme,
                Icons.palette_outlined,
                theme.title,
                onOpenThemeSelector,
              ),
              if (isAdmin) ...[
                _mobileActionTile(
                  sheetContext,
                  theme,
                  Icons.analytics_outlined,
                  'DB Metrics',
                  onOpenDatabaseMetrics,
                ),
                _mobileActionTile(
                  sheetContext,
                  theme,
                  Icons.add,
                  'Add Fixture',
                  onAddFixture,
                ),
                _mobileActionTile(
                  sheetContext,
                  theme,
                  Icons.cloud_upload,
                  'Upload Logo',
                  onUploadLogo,
                ),
              ],
              _mobileActionTile(
                sheetContext,
                theme,
                isAdmin ? Icons.lock_open : Icons.lock,
                isAdmin ? 'Logout' : 'Admin Login',
                onAdminToggle,
                color: isAdmin ? theme.rubyAccent : theme.goldAccent,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;
    final hasSearchedTeam =
        searchedTeam != null && searchedTeam!.trim().isNotEmpty;
    final hasSelectedDivision = selectedDivision != 'ALL / Select Division';

    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, theme, _) {
        return Container(
          decoration: BoxDecoration(
            color: theme.surfaceBg.withValues(alpha: 0.98),
            border: Border(
              bottom: BorderSide(color: theme.cardBorder, width: 1.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ResponsiveLayout.maxContentWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : 12,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: Brand Title & Global Action Buttons
                      if (isMobile)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildBrandLogo(context, theme, compact: true),
                            IconButton(
                              icon: Icon(
                                Icons.more_vert,
                                color: theme.textPrimary,
                              ),
                              tooltip: 'More actions',
                              onPressed: () =>
                                  _showMobileActionsSheet(context, theme),
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildBrandLogo(
                              context,
                              theme,
                              compact: !isDesktop,
                            ),
                            Flexible(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.goldAccent
                                            .withValues(alpha: 0.12),
                                        foregroundColor: theme.textPrimary,
                                        side: BorderSide(
                                          color: theme.goldAccent.withValues(
                                            alpha: 0.5,
                                          ),
                                          width: 1,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        Icons.picture_as_pdf,
                                        size: 16,
                                        color: theme.textPrimary,
                                      ),
                                      label: Text(
                                        'Print A4 Booklet',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: theme.textPrimary,
                                        ),
                                      ),
                                      onPressed: onOpenBookletPrint,
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.goldAccent
                                            .withValues(alpha: 0.15),
                                        foregroundColor: theme.textPrimary,
                                        side: BorderSide(
                                          color: theme.goldAccent,
                                          width: 1.2,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        Icons.palette_outlined,
                                        size: 16,
                                        color: theme.textPrimary,
                                      ),
                                      label: Text(
                                        theme.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: theme.textPrimary,
                                        ),
                                      ),
                                      onPressed: onOpenThemeSelector,
                                    ),
                                    const SizedBox(width: 6),
                                    if (isAdmin) ...[
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.darkBg,
                                          foregroundColor: theme.textPrimary,
                                          side: BorderSide(
                                            color: theme.emeraldAccent,
                                            width: 1.1,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 7,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        icon: Icon(
                                          Icons.analytics_outlined,
                                          size: 16,
                                          color: theme.textPrimary,
                                        ),
                                        label: Text(
                                          'DB Metrics',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: theme.textPrimary,
                                          ),
                                        ),
                                        onPressed: onOpenDatabaseMetrics,
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.emeraldAccent,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text(
                                          'Add Fixture',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        onPressed: onAddFixture,
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.goldAccent,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.cloud_upload,
                                          size: 16,
                                          color: Colors.black,
                                        ),
                                        label: const Text(
                                          'Upload Logo',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        onPressed: onUploadLogo,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isAdmin
                                            ? theme.rubyAccent
                                            : theme.textPrimary,
                                        side: BorderSide(
                                          color: isAdmin
                                              ? theme.rubyAccent
                                              : theme.goldAccent,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        isAdmin ? Icons.lock_open : Icons.lock,
                                        size: 15,
                                      ),
                                      label: Text(
                                        isAdmin ? 'Logout' : 'Admin Login',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onPressed: onAdminToggle,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),

                      // Row 2: Prominent Division, Season, and Team Search Controls
                      if (isMobile)
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: _buildDivisionButton(
                                theme,
                                hasSelectedDivision,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildSeasonSelector(theme),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTeamButton(
                                    theme,
                                    hasSearchedTeam,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildDivisionButton(
                                theme,
                                hasSelectedDivision,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildSeasonSelector(theme),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: _buildTeamButton(theme, hasSearchedTeam),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
