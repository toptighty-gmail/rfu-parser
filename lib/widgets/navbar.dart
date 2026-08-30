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
  final VoidCallback onSyncRfuData;
  final VoidCallback? onOpenDatabaseMetrics;

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
    required this.onSyncRfuData,
    this.onOpenDatabaseMetrics,
  });

  @override
  Size get preferredSize => const Size.fromHeight(135);

  Widget _buildBrandLogo(BuildContext context, {bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppTheme.goldAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.sports_rugby, color: AppTheme.goldAccent, size: 22),
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
                    color: AppTheme.goldAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.goldAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.4), width: 1),
                  ),
                  child: const Text(
                    AppConfig.version,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.goldAccent,
                    ),
                  ),
                ),
              ],
            ),
            if (!compact)
              const Text(
                AppConfig.appSubTitle,
                style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeasonSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.goldAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: seasons.contains(selectedSeason) ? selectedSeason : (seasons.isNotEmpty ? seasons.first : '2025-2026'),
          dropdownColor: AppTheme.surfaceBg,
          isDense: true,
          icon: const Icon(Icons.calendar_month, color: AppTheme.goldAccent, size: 15),
          style: const TextStyle(color: AppTheme.goldAccent, fontSize: 12, fontWeight: FontWeight.bold),
          items: seasons.map((s) {
            return DropdownMenuItem(
              value: s,
              child: Text('Season $s'),
            );
          }).toList(),
          onChanged: onSeasonChanged,
        ),
      ),
    );
  }

  Widget _buildDivisionButton(bool hasSelectedDivision) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: hasSelectedDivision ? AppTheme.goldAccent : AppTheme.goldAccent.withValues(alpha: 0.12),
        foregroundColor: hasSelectedDivision ? Colors.black : AppTheme.goldAccent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(
          color: hasSelectedDivision ? AppTheme.goldAccent : AppTheme.goldAccent.withValues(alpha: 0.5),
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(
        Icons.emoji_events,
        size: 16,
        color: hasSelectedDivision ? Colors.black : AppTheme.goldAccent,
      ),
      label: Text(
        hasSelectedDivision ? 'Div: $selectedDivision' : 'Select Division...',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: hasSelectedDivision ? Colors.black : AppTheme.goldAccent,
        ),
      ),
      onPressed: onOpenDivisionsDirectory,
    );
  }

  Widget _buildTeamButton(bool hasSearchedTeam) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: hasSearchedTeam ? AppTheme.goldAccent : AppTheme.goldAccent.withValues(alpha: 0.12),
        foregroundColor: hasSearchedTeam ? Colors.black : AppTheme.goldAccent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(
          color: hasSearchedTeam ? AppTheme.goldAccent : AppTheme.goldAccent.withValues(alpha: 0.5),
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(
        Icons.search,
        size: 16,
        color: hasSearchedTeam ? Colors.black : AppTheme.goldAccent,
      ),
      label: Text(
        hasSearchedTeam ? 'Team: ${searchedTeam!.trim()}' : 'Search Team...',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: hasSearchedTeam ? Colors.black : AppTheme.goldAccent,
        ),
      ),
      onPressed: onOpenTeamsDirectory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1000;
    final hasSearchedTeam = searchedTeam != null && searchedTeam!.trim().isNotEmpty;
    final hasSelectedDivision = selectedDivision != 'ALL / Select Division';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg.withValues(alpha: 0.97),
        border: const Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ResponsiveLayout.maxContentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 12,
                vertical: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Brand Title & Global Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildBrandLogo(context, compact: !isDesktop),
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.goldAccent.withValues(alpha: 0.12),
                                  foregroundColor: AppTheme.goldAccent,
                                  side: BorderSide(color: AppTheme.goldAccent.withValues(alpha: 0.5), width: 1),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.cloud_sync, size: 16, color: AppTheme.goldAccent),
                                label: const Text('Sync RFU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: onSyncRfuData,
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.goldAccent.withValues(alpha: 0.12),
                                  foregroundColor: AppTheme.goldAccent,
                                  side: BorderSide(color: AppTheme.goldAccent.withValues(alpha: 0.5), width: 1),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.picture_as_pdf, size: 16, color: AppTheme.goldAccent),
                                label: const Text('Print A4 Booklet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: onOpenBookletPrint,
                              ),
                              const SizedBox(width: 6),
                              if (isAdmin) ...[
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: AppTheme.emeraldAccent,
                                    side: const BorderSide(color: AppTheme.emeraldAccent, width: 1.1),
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.analytics_outlined, size: 16, color: AppTheme.emeraldAccent),
                                  label: const Text('DB Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: onOpenDatabaseMetrics,
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.emeraldAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Fixture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: onAddFixture,
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.goldAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.black),
                                  label: const Text('Upload Logo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: onUploadLogo,
                                ),
                                const SizedBox(width: 6),
                              ],
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isAdmin ? AppTheme.rubyAccent : AppTheme.goldAccent,
                                  side: BorderSide(color: isAdmin ? AppTheme.rubyAccent : AppTheme.goldAccent),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: Icon(isAdmin ? Icons.lock_open : Icons.lock, size: 15),
                                label: Text(isAdmin ? 'Logout' : 'Admin Login', style: const TextStyle(fontSize: 12)),
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
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildDivisionButton(hasSelectedDivision),
                      ),
                      const SizedBox(width: 8),
                      _buildSeasonSelector(),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: _buildTeamButton(hasSearchedTeam),
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
  }
}
