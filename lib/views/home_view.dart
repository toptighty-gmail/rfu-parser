import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/division_data.dart';
import '../models/fixture.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/navbar.dart';
import '../widgets/standings_table.dart';
import '../widgets/fixture_list.dart';
import '../widgets/admin_dialog.dart';
import '../widgets/add_fixture_dialog.dart';
import '../widgets/logo_upload_dialog.dart';
import '../widgets/teams_directory_dialog.dart';
import '../widgets/divisions_directory_dialog.dart';
import 'booklet_print_view.dart';
import 'poster_print_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final List<String> _divisions = [
    'ALL / Select Division',
    'Gallagher Premiership',
    'RFU Championship',
    'National 1',
    'National 2 West',
    'National 2 East',
    'National 2 North',
    'Regional 1 Tribute South West',
    'Regional 1 South East',
    'Regional 1 Midlands',
    'Regional 1 North West',
    'Regional 1 North East',
    'Regional 2 Tribute Severn',
    'Regional 2 Tribute South West',
    'Counties 1 Tribute Western West',
    'Counties 1 Tribute Southern South',
    'Counties 1 Tribute Somerset',
    'Counties 2 Tribute Somerset',
    'Counties 2 Tribute Devon',
    'Counties 2 Tribute Cornwall',
    'Counties 3 Tribute Ale Devon South & West',
    'Counties 3 Tribute Somerset',
    'Counties 3 Tribute Cornwall',
    'Counties 4 Tribute Devon',
    'Counties 4 Tribute Somerset',
    'PWR Premiership Women',
  ];

  final List<String> _seasons = [
    '2026-2027',
    '2025-2026',
    '2024-2025',
    '2023-2024',
    '2022-2023',
    '2021-2022',
  ];

  String _selectedDivision = 'ALL / Select Division';
  String _selectedSeason = '2025-2026';
  String _activeTab = 'Standings'; // 'Standings', 'Fixtures'
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = false;
  bool _isAdmin = false;
  DivisionData? _divisionData;
  Map<String, String> _customLogosMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadSupabaseLogos();
  }

  Future<void> _loadSupabaseLogos() async {
    final logos = await SupabaseService.fetchTeamLogos();
    if (mounted && logos.isNotEmpty) {
      setState(() {
        _customLogosMap = logos;
      });
    }
  }

  Future<void> _loadData({String? queryTeam}) async {
    setState(() => _isLoading = true);

    final targetDivision = _selectedDivision == 'ALL / Select Division' ? null : _selectedDivision;

    // 1. Fetch live or sample data from Python scraper API for selected season
    DivisionData? data = await ApiService.fetchDivisionData(
      division: queryTeam == null ? targetDivision : null,
      team: queryTeam,
      season: _selectedSeason,
    );

    // 2. Fetch custom fixtures from Supabase database
    final customFixtures = await SupabaseService.fetchCustomFixtures(
      targetDivision ?? 'General',
    );

    if (data != null) {
      // Merge custom fixtures into fixtures list
      final existingIds = data.fixtures.map((f) => f.id).toSet();
      for (var cf in customFixtures) {
        if (!existingIds.contains(cf.id)) {
          data.fixtures.insert(0, cf);
        }
      }
    } else {
      // Fallback empty container with custom fixtures if offline
      data = DivisionData(
        divisionName: targetDivision ?? 'RFU Leagues',
        season: _selectedSeason,
        standings: [],
        fixtures: customFixtures,
      );
    }

    if (mounted) {
      setState(() {
        _divisionData = data;
        // Highlight crawled division name in header division selector as well
        if (data != null && data.divisionName.isNotEmpty && data.divisionName != 'RFU Leagues') {
          _selectedDivision = data.divisionName;
        }
        _isLoading = false;
      });
    }
  }

  Widget _buildTabButton(String tabId, String label, IconData icon) {
    final isActive = _activeTab == tabId;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabId),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.goldAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.black : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? Colors.black : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: Navbar(
        selectedDivision: _selectedDivision,
        divisions: _divisions,
        onDivisionSelected: (newDiv) {
          setState(() {
            _selectedDivision = newDiv;
            _searchController.clear();
          });
          _loadData();
        },
        selectedSeason: _selectedSeason,
        seasons: _seasons,
        onSeasonChanged: (newSeason) {
          if (newSeason != null) {
            setState(() {
              _selectedSeason = newSeason;
            });
            _loadData(queryTeam: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null);
          }
        },
        searchedTeam: _searchController.text.trim(),
        onTeamSelected: (selectedTeam) {
          if (selectedTeam.trim().isNotEmpty) {
            setState(() {
              _searchController.text = selectedTeam;
            });
            _loadData(queryTeam: selectedTeam.trim());
          }
        },
        onOpenDivisionsDirectory: _openDivisionsDirectory,
        onOpenTeamsDirectory: _openTeamsDirectory,
        onParseLeague: () {
          final queryTeam = _searchController.text.trim();
          _loadData(queryTeam: queryTeam.isNotEmpty ? queryTeam : null);
        },
        isAdmin: _isAdmin,
        onAdminToggle: _toggleAdmin,
        onAddFixture: _openAddFixtureDialog,
        onUploadLogo: _openUploadLogoDialog,
        onOpenBookletPrint: _openBookletPrint,
        onOpenPosterPrint: _openPosterPrint,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.goldAccent),
                  SizedBox(height: 16),
                  Text('Crawling RFU League Data & Live Fixtures...', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: double.infinity),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : 16,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dedicated Admin Mode Control Banner
                      if (_isAdmin)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppTheme.emeraldAccent.withValues(alpha: 0.2), AppTheme.goldAccent.withValues(alpha: 0.2)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.emeraldAccent, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.shield, color: AppTheme.emeraldAccent, size: 22),
                                  SizedBox(width: 10),
                                  Text(
                                    'ADMIN MODE ACTIVE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.emeraldAccent,
                                      letterSpacing: 1.2,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.emeraldAccent,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.add_circle, size: 18),
                                    label: const Text('Add Friendly Fixture', style: TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: () => _openAddFixtureDialog(),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.goldAccent,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.cloud_upload, size: 18),
                                    label: const Text('Upload Team Logo', style: TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: _openUploadLogoDialog,
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.rubyAccent,
                                      side: const BorderSide(color: AppTheme.rubyAccent),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.lock_open, size: 16),
                                    label: const Text('Logout Admin'),
                                    onPressed: _toggleAdmin,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      // Division Banner with Source URL Badge
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: AppTheme.glassBoxDecoration(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _divisionData?.divisionName ?? _selectedDivision,
                                    style: TextStyle(
                                      fontSize: isDesktop ? 22 : 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.goldAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Season: ${_divisionData?.season ?? _selectedSeason}',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                  ),
                                  if (_divisionData?.sourceUrl != null && _divisionData!.sourceUrl!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    InkWell(
                                      onTap: () async {
                                        final uri = Uri.parse(_divisionData!.sourceUrl!);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.darkBg,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.35)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.link, size: 15, color: AppTheme.goldAccent),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Parsing Source URL: ${_divisionData!.sourceUrl}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.goldAccent,
                                                  decoration: TextDecoration.underline,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: AppTheme.goldAccent),
                              tooltip: 'Refresh Data',
                              onPressed: () => _loadData(),
                            ),
                          ],
                        ),
                      ),

                      // View Selection 2-Tab Bar (Standings vs Fixtures)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTabButton('Standings', '📊 League Standings', Icons.table_chart),
                            const SizedBox(width: 4),
                            _buildTabButton('Fixtures', '📅 Fixtures & Results', Icons.event),
                          ],
                        ),
                      ),

                      // Main Content Area (100% Full Width Rendering per Tab)
                      if (_activeTab == 'Fixtures')
                        SizedBox(
                          width: double.infinity,
                          child: FixtureList(
                            fixtures: _divisionData?.fixtures ?? [],
                            isAdmin: _isAdmin,
                            onEditFixture: (f) => _openAddFixtureDialog(existing: f),
                            onDeleteFixture: _deleteFixture,
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: StandingsTable(
                            standings: _divisionData?.standings ?? [],
                            highlightedTeam: _searchController.text.trim(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  void _openDivisionsDirectory() {
    showDialog(
      context: context,
      builder: (_) => DivisionsDirectoryDialog(
        divisions: _divisions,
        selectedDivision: _selectedDivision,
        onSelectDivision: (div) {
          setState(() {
            _selectedDivision = div;
            _searchController.clear();
          });
          _loadData();
        },
      ),
    );
  }

  void _openTeamsDirectory() {
    showDialog(
      context: context,
      builder: (_) => TeamsDirectoryDialog(
        onSelectTeam: (team) {
          setState(() {
            _searchController.text = team;
          });
          _loadData(queryTeam: team);
        },
      ),
    );
  }

  void _toggleAdmin() {
    if (_isAdmin) {
      setState(() => _isAdmin = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out of Admin Mode')),
      );
    } else {
      showDialog(
        context: context,
        builder: (dialogCtx) => AdminDialog(
          onLogin: (pass) async {
            final isValid = await ApiService.verifyAdminPassword(pass);
            if (isValid) {
              setState(() => _isAdmin = true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Admin Mode Authenticated Successfully! You can now add friendly fixtures and upload logos.'),
                    backgroundColor: AppTheme.emeraldAccent,
                  ),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid Admin Password. Please enter "rugby2026" or your custom password.'),
                    backgroundColor: AppTheme.rubyAccent,
                  ),
                );
              }
            }
          },
        ),
      );
    }
  }

  void _openAddFixtureDialog({Fixture? existing}) {
    showDialog(
      context: context,
      builder: (_) => AddFixtureDialog(
        existingFixture: existing,
        onSave: (fixture) async {
          if (existing != null && existing.id != null) {
            await SupabaseService.updateCustomFixture(existing.id!, fixture.toJson());
          } else {
            await SupabaseService.addCustomFixture(fixture, _selectedDivision);
          }
          _loadData();
        },
      ),
    );
  }

  void _deleteFixture(Fixture fixture) async {
    if (fixture.id != null) {
      await SupabaseService.deleteCustomFixture(fixture.id!);
      _loadData();
    }
  }

  void _openUploadLogoDialog() {
    showDialog(
      context: context,
      builder: (_) => LogoUploadDialog(
        onUploaded: (teamName, logoUrl) {
          setState(() {
            _customLogosMap[teamName.toLowerCase()] = logoUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Uploaded logo for $teamName to Supabase Storage!')),
          );
        },
      ),
    );
  }

  void _openBookletPrint() {
    if (_divisionData == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookletPrintView(divisionData: _divisionData!)),
    );
  }

  void _openPosterPrint() {
    if (_divisionData == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PosterPrintView(divisionData: _divisionData!)),
    );
  }
}
