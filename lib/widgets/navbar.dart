import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';

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
  });

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final hasSearchedTeam = searchedTeam != null && searchedTeam!.trim().isNotEmpty;
    final hasSelectedDivision = selectedDivision != 'ALL / Select Division';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg.withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 1)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1350),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 40 : 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                // Brand Logo / Title & Version Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.goldAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sports_rugby, color: AppTheme.goldAccent, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              AppConfig.appName,
                              style: TextStyle(
                                fontSize: isDesktop ? 20 : 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: AppTheme.goldAccent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.goldAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.4), width: 1),
                              ),
                              child: const Text(
                                AppConfig.version,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.goldAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          AppConfig.appSubTitle,
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 20),

                // Division Selector, Season Selector, Team Search, & Parse Button
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Division Selection Button (Opens DivisionsDirectoryDialog)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasSelectedDivision ? AppTheme.goldAccent : AppTheme.darkBg,
                            foregroundColor: hasSelectedDivision ? Colors.black : AppTheme.textPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            side: BorderSide(
                              color: hasSelectedDivision ? AppTheme.goldAccent : AppTheme.cardBorder,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(
                            Icons.emoji_events,
                            size: 18,
                            color: hasSelectedDivision ? Colors.black : AppTheme.goldAccent,
                          ),
                          label: Text(
                            hasSelectedDivision ? 'Div: $selectedDivision' : 'Select Division...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: hasSelectedDivision ? Colors.black : AppTheme.textPrimary,
                            ),
                          ),
                          onPressed: onOpenDivisionsDirectory,
                        ),
                        const SizedBox(width: 12),

                        // Season Dropdown Selector
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.darkBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.4)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: seasons.contains(selectedSeason) ? selectedSeason : (seasons.isNotEmpty ? seasons.first : '2025-2026'),
                              dropdownColor: AppTheme.surfaceBg,
                              icon: const Icon(Icons.calendar_month, color: AppTheme.goldAccent, size: 16),
                              style: const TextStyle(color: AppTheme.goldAccent, fontSize: 13, fontWeight: FontWeight.bold),
                              items: seasons.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text('Season $s'),
                                );
                              }).toList(),
                              onChanged: onSeasonChanged,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Search RFU Team Button (Opens TeamsDirectoryDialog)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasSearchedTeam ? AppTheme.goldAccent : AppTheme.darkBg,
                            foregroundColor: hasSearchedTeam ? Colors.black : AppTheme.textPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            side: BorderSide(
                              color: hasSearchedTeam ? AppTheme.goldAccent : AppTheme.cardBorder,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(
                            Icons.search,
                            size: 18,
                            color: hasSearchedTeam ? Colors.black : AppTheme.goldAccent,
                          ),
                          label: Text(
                            hasSearchedTeam ? 'Team: ${searchedTeam!.trim()}' : 'Search RFU Team...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: hasSearchedTeam ? Colors.black : AppTheme.textPrimary,
                            ),
                          ),
                          onPressed: onOpenTeamsDirectory,
                        ),
                      ],
                    ),
                  ),
                ),

                // Actions / Print / Admin Controls
                Row(
                  children: [
                    // Sync RFU Data to Database Button
                    if (isDesktop)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldAccent.withValues(alpha: 0.15),
                          foregroundColor: AppTheme.goldAccent,
                          side: BorderSide(color: AppTheme.goldAccent.withValues(alpha: 0.6), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.cloud_sync, size: 18, color: AppTheme.goldAccent),
                        label: const Text(
                          'Sync RFU Data',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: onSyncRfuData,
                      )
                    else
                      IconButton(
                        tooltip: 'Sync RFU Data',
                        icon: const Icon(Icons.cloud_sync, color: AppTheme.goldAccent),
                        onPressed: onSyncRfuData,
                      ),
                    const SizedBox(width: 6),

                    // Print Booklet Button
                    IconButton(
                      tooltip: 'A4 Booklet View',
                      icon: const Icon(Icons.menu_book, color: AppTheme.goldAccent),
                      onPressed: onOpenBookletPrint,
                    ),
                    const SizedBox(width: 8),

                    if (isAdmin) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Fixture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: onAddFixture,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Upload Team Logo',
                        icon: const Icon(Icons.image, color: AppTheme.goldAccent),
                        onPressed: onUploadLogo,
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Admin Login/Logout Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isAdmin ? AppTheme.rubyAccent : AppTheme.goldAccent,
                        side: BorderSide(color: isAdmin ? AppTheme.rubyAccent : AppTheme.goldAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(isAdmin ? Icons.lock_open : Icons.lock, size: 16),
                      label: Text(isAdmin ? 'Admin Mode' : 'Admin Login', style: const TextStyle(fontSize: 13)),
                      onPressed: onAdminToggle,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
