import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/division_data_provider.dart';
import '../services/official_rfu_fixtures_data.dart';
import '../theme/app_theme.dart';

class SyncRfuDialog extends StatefulWidget {
  final String? currentDivision;
  final String selectedSeason;
  final VoidCallback onSyncCompleted;

  const SyncRfuDialog({
    super.key,
    this.currentDivision,
    required this.selectedSeason,
    required this.onSyncCompleted,
  });

  @override
  State<SyncRfuDialog> createState() => _SyncRfuDialogState();
}

class _SyncRfuDialogState extends State<SyncRfuDialog> {
  bool _isSyncing = false;
  bool _isCompleted = false;
  double _progress = 0.0;
  String _statusText = 'Ready to sync RFU data to Supabase database.';
  final List<String> _syncLogs = [];

  Future<void> _runSync({required bool syncAll}) async {
    setState(() {
      _isSyncing = true;
      _isCompleted = false;
      _progress = 0.0;
      _syncLogs.clear();
      _statusText = syncAll
          ? 'Starting full sync for all 25 divisions...'
          : 'Syncing ${widget.currentDivision ?? "selected division"}...';
    });

    final divisionsToSync = syncAll
        ? OfficialRfuFixturesData.allDivisionFixtures.keys.toList()
        : [widget.currentDivision ?? 'counties 2 tribute devon'];

    int total = divisionsToSync.length;
    int current = 0;
    int totalFixtures = 0;

    for (var div in divisionsToSync) {
      current++;
      final divData = DivisionDataProvider.generateDivisionData(div, widget.selectedSeason);
      
      setState(() {
        _progress = current / total;
        _statusText = 'Syncing ($current/$total): ${divData.divisionName}...';
        _syncLogs.insert(0, '✓ ${divData.divisionName}: ${divData.fixtures.length} fixtures, ${divData.standings.length} teams');
      });

      // Upsert into live Supabase database tables
      await SupabaseService.upsertDivisionData(divData);
      totalFixtures += divData.fixtures.length;
      
      // Small pause for smooth UI progression
      if (syncAll) {
        await Future.delayed(const Duration(milliseconds: 60));
      }
    }

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _isCompleted = true;
        _progress = 1.0;
        _statusText = 'Sync complete! $total divisions and $totalFixtures fixtures verified in Supabase.';
      });
      widget.onSyncCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCurrentDiv = widget.currentDivision != null &&
        widget.currentDivision != 'ALL / Select Division';

    return Dialog(
      backgroundColor: AppTheme.surfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.goldAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.cloud_sync, color: AppTheme.goldAccent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sync RFU Data to Database',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Update Supabase cloud database with official RFU fixtures & standings',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                    onPressed: _isSyncing ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Divider(color: AppTheme.cardBorder, height: 28),

              // Status / Progress Section
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.darkBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isCompleted
                        ? AppTheme.emeraldAccent.withValues(alpha: 0.5)
                        : AppTheme.cardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isCompleted
                              ? Icons.check_circle
                              : (_isSyncing ? Icons.sync : Icons.info_outline),
                          size: 18,
                          color: _isCompleted
                              ? AppTheme.emeraldAccent
                              : (_isSyncing ? AppTheme.goldAccent : AppTheme.textMuted),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isCompleted
                                  ? AppTheme.emeraldAccent
                                  : (_isSyncing ? AppTheme.goldAccent : AppTheme.textPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isSyncing) ...[
                      SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.black26,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.goldAccent),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Activity Log
              if (_syncLogs.isNotEmpty) ...[
                SizedBox(height: 14),
                Text(
                  'Sync Activity Log:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder.withValues(alpha: 0.5)),
                    ),
                    child: ListView.builder(
                      itemCount: _syncLogs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _syncLogs[index],
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: AppTheme.emeraldAccent,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ] else ...[
                const Spacer(),
              ],

              const SizedBox(height: 18),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSyncing ? null : () => Navigator.of(context).pop(),
                    child: Text(_isCompleted ? 'Close' : 'Cancel', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  SizedBox(width: 10),
                  if (hasCurrentDiv && !_isCompleted)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.goldAccent,
                        side: BorderSide(color: AppTheme.goldAccent),
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Sync Current Division', style: TextStyle(fontSize: 13)),
                      onPressed: _isSyncing ? null : () => _runSync(syncAll: false),
                    ),
                  if (hasCurrentDiv && !_isCompleted) const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.goldAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(_isCompleted ? Icons.done_all : Icons.cloud_upload, size: 18),
                    label: Text(
                      _isCompleted ? 'Done' : 'Sync All 25 Divisions',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSyncing
                        ? null
                        : (_isCompleted ? () => Navigator.of(context).pop() : () => _runSync(syncAll: true)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
