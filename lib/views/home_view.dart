import 'package:flutter/material.dart';
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
import 'booklet_print_view.dart';
import 'poster_print_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final List<String> _divisions = [
    'Regional 1 Tribute South West',
    'Regional 2 Tribute Severn',
    'Counties 1 Tribute Western West',
    'Counties 2 Tribute Somerset',
  ];

  String _selectedDivision = 'Regional 1 Tribute South West';
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

    // 1. Fetch live or sample data from Python scraper API
    DivisionData? data = await ApiService.fetchDivisionData(
      division: queryTeam == null ? _selectedDivision : null,
      team: queryTeam,
    );

    // 2. Fetch custom fixtures from Supabase database
    final customFixtures = await SupabaseService.fetchCustomFixtures(_selectedDivision);

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
        divisionName: _selectedDivision,
        season: '2025-2026',
        standings: [],
        fixtures: customFixtures,
      );
    }

    if (mounted) {
      setState(() {
        _divisionData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: Navbar(
        selectedDivision: _selectedDivision,
        divisions: _divisions,
        onDivisionChanged: (newDiv) {
          if (newDiv != null) {
            setState(() {
              _selectedDivision = newDiv;
              _searchController.clear();
            });
            _loadData();
          }
        },
        searchController: _searchController,
        onSearchSubmitted: () {
          final q = _searchController.text.trim();
          if (q.isNotEmpty) {
            _loadData(queryTeam: q);
          }
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
                  Text('Loading RFU League Data & Fixtures...', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            )
          : SingleChildScrollView(
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

                  // Division Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: AppTheme.glassBoxDecoration(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
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
                              'Season: ${_divisionData?.season ?? "2025-2026"}',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppTheme.goldAccent),
                          tooltip: 'Refresh Data',
                          onPressed: () => _loadData(),
                        ),
                      ],
                    ),
                  ),

                  // Main Content Grid: Standings (Left) & Fixtures (Right)
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: StandingsTable(
                            standings: _divisionData?.standings ?? [],
                            highlightedTeam: _searchController.text.trim(),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 6,
                          child: FixtureList(
                            fixtures: _divisionData?.fixtures ?? [],
                            isAdmin: _isAdmin,
                            onEditFixture: (f) => _openAddFixtureDialog(existing: f),
                            onDeleteFixture: _deleteFixture,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        StandingsTable(
                          standings: _divisionData?.standings ?? [],
                          highlightedTeam: _searchController.text.trim(),
                        ),
                        const SizedBox(height: 24),
                        FixtureList(
                          fixtures: _divisionData?.fixtures ?? [],
                          isAdmin: _isAdmin,
                          onEditFixture: (f) => _openAddFixtureDialog(existing: f),
                          onDeleteFixture: _deleteFixture,
                        ),
                      ],
                    ),
                ],
              ),
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
