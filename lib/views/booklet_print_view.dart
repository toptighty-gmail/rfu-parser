import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/division_data.dart';
import '../models/fixture.dart';
import '../models/standing_entry.dart';
import '../widgets/team_logo_image.dart';
import '../theme/app_theme.dart';

class BookletPrintView extends StatelessWidget {
  final DivisionData divisionData;
  final String? filterTeam;
  final Map<String, String> customLogosMap;

  const BookletPrintView({
    super.key,
    required this.divisionData,
    this.filterTeam,
    this.customLogosMap = const {},
  });

  static DateTime _parseFixtureDate(Fixture f) {
    if (f.dateIso.isNotEmpty) {
      final dt = DateTime.tryParse(f.dateIso);
      if (dt != null) return dt;
    }
    try {
      final clean = f.date.replaceAll(RegExp(r'^[A-Za-z]+,\s*'), '').trim();
      return DateFormat('d MMM yyyy').parse(clean);
    } catch (_) {}
    try {
      final clean = f.date.replaceAll(RegExp(r'^[A-Za-z]+,\s*'), '').trim();
      return DateFormat('MMMM d, yyyy').parse(clean);
    } catch (_) {}
    try {
      return DateFormat('dd/MM/yyyy').parse(f.date);
    } catch (_) {}
    return DateTime(2099);
  }

  String? _resolveLogo(String teamName, String? defaultLogoUrl) {
    if (defaultLogoUrl != null && defaultLogoUrl.trim().isNotEmpty) {
      return defaultLogoUrl.trim();
    }
    final clean = teamName.trim().toLowerCase();
    if (customLogosMap.containsKey(clean)) {
      return customLogosMap[clean];
    }
    for (var s in divisionData.standings) {
      if (s.teamName.trim().toLowerCase() == clean && s.logoUrl != null && s.logoUrl!.isNotEmpty) {
        return s.logoUrl;
      }
    }
    for (var s in divisionData.standings) {
      if ((s.teamName.toLowerCase().contains(clean) || clean.contains(s.teamName.toLowerCase())) &&
          s.logoUrl != null &&
          s.logoUrl!.isNotEmpty) {
        return s.logoUrl;
      }
    }
    return null;
  }

  Widget _buildTeamLogo(String teamName, String? directLogoUrl, {double size = 22}) {
    final logoUrl = _resolveLogo(teamName, directLogoUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: TeamLogoImage(
        logoUrl: logoUrl,
        size: size,
      ),
    );
  }

  Future<Uint8List> _generatePdfDoc(
    PdfPageFormat format,
    List<Fixture> sortedFixtures,
    bool isTeamFiltered,
  ) async {
    final doc = pw.Document();

    final cleanHighlight = filterTeam?.trim().toLowerCase();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#0F172A'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      divisionData.divisionName.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('#F59E0B'),
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      isTeamFiltered
                          ? 'TEAM CONTEXT: ${filterTeam!.trim().toUpperCase()}  •  SEASON: ${divisionData.season}'
                          : 'OFFICIAL FIXTURE & LEAGUE SCHEDULE  •  SEASON: ${divisionData.season}',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('#CBD5E1'),
                        fontSize: 9,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1E293B'),
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColor.fromHex('#334155')),
                  ),
                  child: pw.Text(
                    'RFU OFFICIAL',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#F59E0B'),
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 14),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated by RFU Hub • Official England Rugby League Data',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // SECTION 1: STANDINGS TABLE
            if (divisionData.standings.isNotEmpty) ...[
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  '1. LEAGUE TABLE STANDINGS',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#B45309'),
                  ),
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.5),
                columnWidths: const {
                  0: pw.FixedColumnWidth(24),  // Pos
                  1: pw.FlexColumnWidth(4),    // Club
                  2: pw.FixedColumnWidth(24),  // P
                  3: pw.FixedColumnWidth(24),  // W
                  4: pw.FixedColumnWidth(24),  // D
                  5: pw.FixedColumnWidth(24),  // L
                  6: pw.FixedColumnWidth(28),  // PF
                  7: pw.FixedColumnWidth(28),  // PA
                  8: pw.FixedColumnWidth(28),  // +/-
                  9: pw.FixedColumnWidth(24),  // TB
                  10: pw.FixedColumnWidth(24), // LB
                  11: pw.FixedColumnWidth(30), // PTS
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F172A')),
                    children: [
                      _buildPdfHeaderCell('#'),
                      _buildPdfHeaderCell('CLUB', align: pw.TextAlign.left),
                      _buildPdfHeaderCell('P'),
                      _buildPdfHeaderCell('W'),
                      _buildPdfHeaderCell('D'),
                      _buildPdfHeaderCell('L'),
                      _buildPdfHeaderCell('PF'),
                      _buildPdfHeaderCell('PA'),
                      _buildPdfHeaderCell('+/-'),
                      _buildPdfHeaderCell('TB'),
                      _buildPdfHeaderCell('LB'),
                      _buildPdfHeaderCell('PTS', isHighlight: true),
                    ],
                  ),
                  // Table Rows
                  ...divisionData.standings.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    final isMatched = cleanHighlight != null &&
                        cleanHighlight.isNotEmpty &&
                        s.teamName.toLowerCase().contains(cleanHighlight);

                    final rowBg = isMatched
                        ? PdfColor.fromHex('#FEF3C7')
                        : (idx % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F9FAFB'));

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: rowBg),
                      children: [
                        _buildPdfCell('${s.pos}', isBold: true),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: pw.Text(
                            s.teamName,
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: isMatched ? pw.FontWeight.bold : pw.FontWeight.normal,
                              color: isMatched ? PdfColor.fromHex('#92400E') : PdfColor.fromHex('#111827'),
                            ),
                          ),
                        ),
                        _buildPdfCell('${s.played}'),
                        _buildPdfCell('${s.won}'),
                        _buildPdfCell('${s.drawn}'),
                        _buildPdfCell('${s.lost}'),
                        _buildPdfCell('${s.pointsFor}'),
                        _buildPdfCell('${s.pointsAgainst}'),
                        _buildPdfCell(
                          s.pointsDiff >= 0 ? '+${s.pointsDiff}' : '${s.pointsDiff}',
                          textColor: s.pointsDiff >= 0 ? PdfColor.fromHex('#15803D') : PdfColor.fromHex('#DC2626'),
                        ),
                        _buildPdfCell('${s.tryBonus}'),
                        _buildPdfCell('${s.lossBonus}'),
                        _buildPdfCell('${s.points}', isBold: true, textColor: PdfColor.fromHex('#B45309')),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // SECTION 2: FIXTURES & RESULTS
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 6, bottom: 6),
              child: pw.Text(
                isTeamFiltered
                    ? '2. FIXTURES & RESULTS — ${filterTeam!.trim().toUpperCase()} (${sortedFixtures.length} MATCHES)'
                    : '2. FIXTURES & RESULTS — ALL ROUNDS (${sortedFixtures.length} MATCHES)',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#B45309'),
                ),
              ),
            ),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(130), // Date & KO Time
                1: pw.FlexColumnWidth(3),    // Home Team
                2: pw.FixedColumnWidth(52),  // Score / VS Box
                3: pw.FlexColumnWidth(3),    // Away Team
                4: pw.FixedColumnWidth(64),  // Status
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F172A')),
                  children: [
                    _buildPdfHeaderCell('DATE & TIME', align: pw.TextAlign.left),
                    _buildPdfHeaderCell('HOME TEAM', align: pw.TextAlign.right),
                    _buildPdfHeaderCell('SCORE', align: pw.TextAlign.center),
                    _buildPdfHeaderCell('AWAY TEAM', align: pw.TextAlign.left),
                    _buildPdfHeaderCell('STATUS', align: pw.TextAlign.center),
                  ],
                ),
                // Fixture Rows
                ...sortedFixtures.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final f = entry.value;
                  final isHomeMatched = cleanHighlight != null &&
                      cleanHighlight.isNotEmpty &&
                      f.homeTeam.toLowerCase().contains(cleanHighlight);
                  final isAwayMatched = cleanHighlight != null &&
                      cleanHighlight.isNotEmpty &&
                      f.awayTeam.toLowerCase().contains(cleanHighlight);

                  final isCompleted = f.status.toLowerCase() == 'completed' ||
                      (f.homeScore != null && f.awayScore != null);

                  final rowBg = (isHomeMatched || isAwayMatched)
                      ? PdfColor.fromHex('#FFFBEB')
                      : (idx % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#FAFAFA'));

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowBg),
                    children: [
                      // Date & KO Time (Left)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    f.date,
                                    style: pw.TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColor.fromHex('#1F2937'),
                                    ),
                                  ),
                                  if (f.roundNum.isNotEmpty)
                                    pw.Text(
                                      f.roundNum,
                                      style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#6B7280')),
                                    ),
                                ],
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromHex('#FEF3C7'),
                                borderRadius: pw.BorderRadius.circular(3),
                                border: pw.Border.all(color: PdfColor.fromHex('#F59E0B'), width: 0.5),
                              ),
                              child: pw.Text(
                                'KO ${f.time.isNotEmpty ? f.time : "15:00"}',
                                style: pw.TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#B45309'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Home Team
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(
                          f.homeTeam,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: isHomeMatched ? pw.FontWeight.bold : pw.FontWeight.normal,
                            color: isHomeMatched ? PdfColor.fromHex('#92400E') : PdfColor.fromHex('#1F2937'),
                          ),
                        ),
                      ),

                      // Score / VS Center Box
                      pw.Center(
                        child: pw.Container(
                          margin: const pw.EdgeInsets.symmetric(vertical: 4),
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: isCompleted ? PdfColor.fromHex('#0F172A') : PdfColor.fromHex('#FEF3C7'),
                            borderRadius: pw.BorderRadius.circular(3),
                            border: pw.Border.all(
                              color: isCompleted ? PdfColor.fromHex('#334155') : PdfColor.fromHex('#F59E0B'),
                              width: 0.5,
                            ),
                          ),
                          child: pw.Text(
                            isCompleted ? '${f.homeScore ?? 0} - ${f.awayScore ?? 0}' : 'VS',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: isCompleted ? PdfColors.white : PdfColor.fromHex('#B45309'),
                            ),
                          ),
                        ),
                      ),

                      // Away Team
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: pw.Text(
                          f.awayTeam,
                          textAlign: pw.TextAlign.left,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: isAwayMatched ? pw.FontWeight.bold : pw.FontWeight.normal,
                            color: isAwayMatched ? PdfColor.fromHex('#92400E') : PdfColor.fromHex('#1F2937'),
                          ),
                        ),
                      ),

                      // Status Badge
                      pw.Center(
                        child: pw.Container(
                          margin: const pw.EdgeInsets.symmetric(vertical: 4),
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: isCompleted ? PdfColor.fromHex('#DCFCE7') : PdfColor.fromHex('#FEF3C7'),
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pw.Text(
                            f.status.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: isCompleted ? PdfColor.fromHex('#15803D') : PdfColor.fromHex('#B45309'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _buildPdfHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.center, bool isHighlight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: isHighlight ? PdfColor.fromHex('#F59E0B') : PdfColor.fromHex('#CBD5E1'),
        ),
      ),
    );
  }

  pw.Widget _buildPdfCell(String text, {bool isBold = false, PdfColor? textColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? PdfColor.fromHex('#374151'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanFilter = filterTeam?.trim().toLowerCase();
    final isTeamFiltered = cleanFilter != null && cleanFilter.isNotEmpty;

    final rawFixtures = isTeamFiltered
        ? divisionData.fixtures.where((f) {
            return f.homeTeam.toLowerCase().contains(cleanFilter) ||
                f.awayTeam.toLowerCase().contains(cleanFilter);
          }).toList()
        : divisionData.fixtures;

    // Strict chronological sort by calendar date and KO time
    final activeFixtures = List<Fixture>.from(rawFixtures)
      ..sort((a, b) {
        final dtA = _parseFixtureDate(a);
        final dtB = _parseFixtureDate(b);
        final dateComp = dtA.compareTo(dtB);
        if (dateComp != 0) return dateComp;
        return a.time.compareTo(b.time);
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 1,
        title: Text(
          isTeamFiltered
              ? 'A4 Print: ${filterTeam!.trim().toUpperCase()}'
              : 'A4 Print: ${divisionData.divisionName}',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text(
                'Print / Save to PDF',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () async {
                try {
                  await Printing.layoutPdf(
                    onLayout: (PdfPageFormat format) => _generatePdfDoc(format, activeFixtures, isTeamFiltered),
                    name: 'RFU_Schedule_${(filterTeam ?? divisionData.divisionName).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf',
                  );
                } catch (e) {
                  debugPrint('PDF print error: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error launching PDF viewer: $e'),
                        backgroundColor: AppTheme.rubyAccent,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Document Header Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                divisionData.divisionName.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isTeamFiltered
                                    ? 'TEAM CONTEXT: ${filterTeam!.trim().toUpperCase()}  •  SEASON: ${divisionData.season}'
                                    : 'OFFICIAL LEAGUE & FIXTURE SCHEDULE  •  SEASON: ${divisionData.season}',
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: const Text(
                            'RFU OFFICIAL',
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // SECTION 1: LEAGUE TABLE STANDINGS
                  _buildSectionHeader('1. LEAGUE TABLE STANDINGS', Icons.table_chart),
                  const SizedBox(height: 12),
                  _buildPrintStandingsTable(divisionData.standings, filterTeam),

                  const SizedBox(height: 36),

                  // PAGE BREAK DIVIDER
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFF94A3B8), thickness: 1.5)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Text(
                              'PAGE BREAK  •  FIXTURES & RESULTS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFF94A3B8), thickness: 1.5)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SECTION 2: FIXTURES & RESULTS
                  _buildSectionHeader(
                    isTeamFiltered
                        ? '2. FIXTURES & RESULTS — ${filterTeam!.trim().toUpperCase()} (${activeFixtures.length} MATCHES)'
                        : '2. FIXTURES & RESULTS — ALL ROUNDS (${activeFixtures.length} MATCHES)',
                    Icons.event,
                  ),
                  const SizedBox(height: 12),
                  _buildPrintFixtures(activeFixtures, filterTeam),

                  const SizedBox(height: 32),

                  // Footer
                  const Center(
                    child: Text(
                      'Generated by RFU Hub • Official England Rugby League Data',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFB45309), size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPrintStandingsTable(List<StandingEntry> standings, String? highlightTeam) {
    if (standings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: Text(
            'No league table data available.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
        ),
      );
    }

    final cleanHighlight = highlightTeam?.trim().toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(36), // Pos
          1: FlexColumnWidth(4),   // Club Name
          2: FixedColumnWidth(38), // P
          3: FixedColumnWidth(38), // W
          4: FixedColumnWidth(38), // D
          5: FixedColumnWidth(38), // L
          6: FixedColumnWidth(44), // PF
          7: FixedColumnWidth(44), // PA
          8: FixedColumnWidth(44), // +/-
          9: FixedColumnWidth(38), // TB
          10: FixedColumnWidth(38), // LB
          11: FixedColumnWidth(48), // Pts
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // Header Row
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
            children: [
              _buildHeaderCell('#'),
              _buildHeaderCell('CLUB', align: TextAlign.left),
              _buildHeaderCell('P'),
              _buildHeaderCell('W'),
              _buildHeaderCell('D'),
              _buildHeaderCell('L'),
              _buildHeaderCell('PF'),
              _buildHeaderCell('PA'),
              _buildHeaderCell('+/-'),
              _buildHeaderCell('TB'),
              _buildHeaderCell('LB'),
              _buildHeaderCell('PTS', isHighlight: true),
            ],
          ),

          // Data Rows
          ...standings.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final isMatched = cleanHighlight != null &&
                cleanHighlight.isNotEmpty &&
                s.teamName.toLowerCase().contains(cleanHighlight);

            final isEven = idx % 2 == 0;
            final rowColor = isMatched
                ? const Color(0xFFFEF3C7) // Light Amber highlight
                : (isEven ? Colors.white : const Color(0xFFF9FAFB));

            return TableRow(
              decoration: BoxDecoration(
                color: rowColor,
                border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
              ),
              children: [
                _buildCell('${s.pos}', isBold: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      _buildTeamLogo(s.teamName, s.logoUrl, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.teamName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isMatched ? FontWeight.w900 : FontWeight.w600,
                            color: isMatched ? const Color(0xFF92400E) : const Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCell('${s.played}'),
                _buildCell('${s.won}'),
                _buildCell('${s.drawn}'),
                _buildCell('${s.lost}'),
                _buildCell('${s.pointsFor}'),
                _buildCell('${s.pointsAgainst}'),
                _buildCell(
                  s.pointsDiff >= 0 ? '+${s.pointsDiff}' : '${s.pointsDiff}',
                  textColor: s.pointsDiff >= 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                ),
                _buildCell('${s.tryBonus}'),
                _buildCell('${s.lossBonus}'),
                _buildCell('${s.points}', isBold: true, textColor: const Color(0xFFB45309)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text,
      {TextAlign align = TextAlign.center, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: isHighlight ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCell(String text,
      {TextAlign align = TextAlign.center, bool isBold = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.w500,
          color: textColor ?? const Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _buildPrintFixtures(List<Fixture> fixtures, String? highlightTeam) {
    if (fixtures.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: Text(
            'No fixtures available for this selection.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
        ),
      );
    }

    final cleanHighlight = highlightTeam?.trim().toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: fixtures.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final f = fixtures[index];
          final isHomeMatched = cleanHighlight != null &&
              cleanHighlight.isNotEmpty &&
              f.homeTeam.toLowerCase().contains(cleanHighlight);
          final isAwayMatched = cleanHighlight != null &&
              cleanHighlight.isNotEmpty &&
              f.awayTeam.toLowerCase().contains(cleanHighlight);

          final isCompleted = f.status.toLowerCase() == 'completed' ||
              (f.homeScore != null && f.awayScore != null);

          final isEven = index % 2 == 0;
          final rowBg = (isHomeMatched || isAwayMatched)
              ? const Color(0xFFFFFBEB) // Light warm highlight
              : (isEven ? Colors.white : const Color(0xFFFAFAFA));

          return Container(
            color: rowBg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Date & KO Time Column (Left Side)
                SizedBox(
                  width: 220,
                  child: Row(
                    children: [
                      // Date & Round
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              f.date,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            if (f.roundNum.isNotEmpty)
                              Text(
                                f.roundNum,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // KO Time Badge (Left side next to date)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, size: 10, color: Color(0xFFB45309)),
                            const SizedBox(width: 3),
                            Text(
                              'KO ${f.time.isNotEmpty ? f.time : "15:00"}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Home Team
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          f.homeTeam,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isHomeMatched ? FontWeight.w900 : FontWeight.w600,
                            color: isHomeMatched ? const Color(0xFF92400E) : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTeamLogo(f.homeTeam, f.homeLogoUrl, size: 22),
                    ],
                  ),
                ),

                // Score / VS Box (Always 'VS' for upcoming matches, Final score for completed)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  constraints: const BoxConstraints(minWidth: 58),
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFF0F172A) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isCompleted ? const Color(0xFF334155) : const Color(0xFFF59E0B),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isCompleted
                          ? '${f.homeScore ?? 0} - ${f.awayScore ?? 0}'
                          : 'VS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isCompleted ? Colors.white : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ),

                // Away Team
                Expanded(
                  child: Row(
                    children: [
                      _buildTeamLogo(f.awayTeam, f.awayLogoUrl, size: 22),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          f.awayTeam,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isAwayMatched ? FontWeight.w900 : FontWeight.w600,
                            color: isAwayMatched ? const Color(0xFF92400E) : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    f.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? const Color(0xFF15803D) : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
