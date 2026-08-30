import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class AdminDatabaseMetricsDialog extends StatefulWidget {
  const AdminDatabaseMetricsDialog({super.key});

  @override
  State<AdminDatabaseMetricsDialog> createState() => _AdminDatabaseMetricsDialogState();
}

class _AdminDatabaseMetricsDialogState extends State<AdminDatabaseMetricsDialog> {
  List<TableMetric> _metrics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.fetchDatabaseMetrics();
      if (mounted) {
        setState(() {
          _metrics = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return 'No sync timestamp available';
    final now = DateTime.now();
    final difference = now.difference(dt);

    final formattedDate = DateFormat('EEE d MMM yyyy, HH:mm:ss').format(dt);
    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$formattedDate (${mins == 0 ? "Just now" : "$mins min ago"})';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$formattedDate ($hours hour${hours > 1 ? "s" : ""} ago)';
    }
    return formattedDate;
  }

  @override
  Widget build(BuildContext context) {
    final totalRecords = _metrics.fold<int>(0, (sum, item) => sum + item.recordCount);
    final numberFormatter = NumberFormat('#,###');

    return AlertDialog(
      backgroundColor: AppTheme.surfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.analytics_outlined, color: AppTheme.emeraldAccent, size: 22),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supabase Database Health',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Live Table Record Counts & Last Sync Timestamps',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 680 ? 620 : MediaQuery.of(context).size.width * 0.94,
        child: _isLoading
            ? SizedBox(
                height: 240,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.emeraldAccent),
                      SizedBox(height: 16),
                      Text('Querying Supabase live table metrics...', style: TextStyle(color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Total database summary banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.emeraldAccent.withValues(alpha: 0.15),
                            AppTheme.goldAccent.withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.emeraldAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.storage, color: AppTheme.emeraldAccent, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'TOTAL REPOSITORIES & DATA RECORDS',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.emeraldAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${numberFormatter.format(totalRecords)} TOTAL',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Individual table cards
                    ..._metrics.map((m) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Icon(m.icon, color: AppTheme.goldAccent, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        m.displayName,
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'public.${m.tableName}',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Last updated: ${_formatTimestamp(m.lastUpdated)}',
                                          style: TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.goldAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    numberFormatter.format(m.recordCount),
                                    style: TextStyle(
                                      color: AppTheme.goldAccent,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'records',
                                    style: TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
      ),
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: BorderSide(color: AppTheme.cardBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: Icon(Icons.refresh, size: 16, color: AppTheme.emeraldAccent),
          label: Text('Refresh Counts'),
          onPressed: _isLoading ? null : _loadMetrics,
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emeraldAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
