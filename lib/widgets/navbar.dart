import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import 'team_search_autocomplete.dart';

class Navbar extends StatelessWidget implements PreferredSizeWidget {
  final String selectedDivision;
  final List<String> divisions;
  final ValueChanged<String?> onDivisionChanged;
  final ValueChanged<String> onTeamSelected;
  final bool isAdmin;
  final VoidCallback onAdminToggle;
  final VoidCallback onAddFixture;
  final VoidCallback onUploadLogo;
  final VoidCallback onOpenBookletPrint;
  final VoidCallback onOpenPosterPrint;

  const Navbar({
    super.key,
    required this.selectedDivision,
    required this.divisions,
    required this.onDivisionChanged,
    required this.onTeamSelected,
    required this.isAdmin,
    required this.onAdminToggle,
    required this.onAddFixture,
    required this.onUploadLogo,
    required this.onOpenBookletPrint,
    required this.onOpenPosterPrint,
  });

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg.withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 1)),
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
          const SizedBox(width: 24),

          // Division Dropdown Selector & Team Search Autocomplete
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: divisions.contains(selectedDivision) ? selectedDivision : (divisions.isNotEmpty ? divisions.first : null),
                        dropdownColor: AppTheme.surfaceBg,
                        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.goldAccent),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        items: divisions.map((div) {
                          return DropdownMenuItem(
                            value: div,
                            child: Text(div),
                          );
                        }).toList(),
                        onChanged: onDivisionChanged,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Real-Time Team Search Autocomplete Dropdown
                  TeamSearchAutocomplete(
                    width: isDesktop ? 260 : 180,
                    onTeamSelected: onTeamSelected,
                  ),
                ],
              ),
            ),
          ),

          // Actions / Print / Admin Controls
          Row(
            children: [
              // Print Booklet Button
              IconButton(
                tooltip: 'A4 Booklet View',
                icon: const Icon(Icons.menu_book, color: AppTheme.goldAccent),
                onPressed: onOpenBookletPrint,
              ),
              // Print Poster Button
              IconButton(
                tooltip: 'A3 Poster View',
                icon: const Icon(Icons.picture_in_picture, color: AppTheme.emeraldAccent),
                onPressed: onOpenPosterPrint,
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
    );
  }
}
