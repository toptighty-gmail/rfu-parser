import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
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

  static String _formatShortDate(Fixture f) {
    final dt = _parseFixtureDate(f);
    if (dt.year < 2090) {
      return DateFormat('EEE d MMM yyyy').format(dt); // e.g. "Sat 26 Sep 2026"
    }
    return f.date
        .replaceAll('Monday,', 'Mon')
        .replaceAll('Tuesday,', 'Tue')
        .replaceAll('Wednesday,', 'Wed')
        .replaceAll('Thursday,', 'Thu')
        .replaceAll('Friday,', 'Fri')
        .replaceAll('Saturday,', 'Sat')
        .replaceAll('Sunday,', 'Sun');
  }

  static String _formatShortRound(String round) {
    if (round.trim().isEmpty) return '';
    return round.trim()
        .replaceAll(RegExp(r'Round\s*', caseSensitive: false), 'R')
        .replaceAll(RegExp(r'Cup Matches', caseSensitive: false), 'Cup')
        .replaceAll(RegExp(r'Friendly Matches', caseSensitive: false), 'Friendly');
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

  Widget _buildTeamLogo(String teamName, String? directLogoUrl, {double size = 20}) {
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

    // Identify the next upcoming fixture (first uncompleted fixture chronologically)
    Fixture? nextUpcomingFixture;
    for (final f in sortedFixtures) {
      final isCompleted = f.status.toLowerCase() == 'completed' ||
          (f.homeScore != null && f.awayScore != null);
      if (!isCompleted) {
        nextUpcomingFixture = f;
        break;
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.only(top: 4),
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
            // SECTION 1: STANDINGS TABLE (EXPANDED TO COMFORTABLY FILL A4 PAGE 1)
            if (divisionData.standings.isNotEmpty) ...[
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  '1. LEAGUE TABLE STANDINGS',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#B45309'),
                  ),
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.8),
                columnWidths: const {
                  0: pw.FixedColumnWidth(28),  // Pos
                  1: pw.FlexColumnWidth(5.0),  // Club Name
                  2: pw.FixedColumnWidth(26),  // P
                  3: pw.FixedColumnWidth(26),  // W
                  4: pw.FixedColumnWidth(26),  // D
                  5: pw.FixedColumnWidth(26),  // L
                  6: pw.FixedColumnWidth(32),  // PF
                  7: pw.FixedColumnWidth(32),  // PA
                  8: pw.FixedColumnWidth(32),  // +/-
                  9: pw.FixedColumnWidth(26),  // TB
                  10: pw.FixedColumnWidth(26), // LB
                  11: pw.FixedColumnWidth(38), // PTS
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
                  // Table Rows with large clear typography & generous vertical padding
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
                        _buildPdfCell('${s.pos}', isBold: true, fontSize: 11),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8.5),
                          child: pw.Text(
                            s.teamName,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: isMatched ? pw.FontWeight.bold : pw.FontWeight.normal,
                              color: isMatched ? PdfColor.fromHex('#92400E') : PdfColor.fromHex('#111827'),
                            ),
                          ),
                        ),
                        _buildPdfCell('${s.played}', fontSize: 10.5),
                        _buildPdfCell('${s.won}', fontSize: 10.5),
                        _buildPdfCell('${s.drawn}', fontSize: 10.5),
                        _buildPdfCell('${s.lost}', fontSize: 10.5),
                        _buildPdfCell('${s.pointsFor}', fontSize: 10.5),
                        _buildPdfCell('${s.pointsAgainst}', fontSize: 10.5),
                        _buildPdfCell(
                          s.pointsDiff >= 0 ? '+${s.pointsDiff}' : '${s.pointsDiff}',
                          fontSize: 10.5,
                          textColor: s.pointsDiff >= 0 ? PdfColor.fromHex('#15803D') : PdfColor.fromHex('#DC2626'),
                        ),
                        _buildPdfCell('${s.tryBonus}', fontSize: 10.5),
                        _buildPdfCell('${s.lossBonus}', fontSize: 10.5),
                        _buildPdfCell('${s.points}', isBold: true, fontSize: 11.5, textColor: PdfColor.fromHex('#B45309')),
                      ],
                    );
                  }),
                ],
              ),
              // PAGE BREAK AFTER LEAGUE STANDINGS TABLE
              pw.NewPage(),
            ],

            // SECTION 2: FIXTURES & RESULTS (CONDENSED 1-LINE PER FIXTURE ON NEXT PAGE)
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 4, bottom: 6),
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
                0: pw.FixedColumnWidth(175), // Date, Round, KO & Next Match Badge
                1: pw.FlexColumnWidth(3),    // Home Team
                2: pw.FixedColumnWidth(48),  // Score / VS Box
                3: pw.FlexColumnWidth(3),    // Away Team
                4: pw.FixedColumnWidth(54),  // Status
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F172A')),
                  children: [
                    _buildPdfHeaderCell('DATE & ROUND', align: pw.TextAlign.left),
                    _buildPdfHeaderCell('HOME TEAM', align: pw.TextAlign.right),
                    _buildPdfHeaderCell('SCORE', align: pw.TextAlign.center),
                    _buildPdfHeaderCell('AWAY TEAM', align: pw.TextAlign.left),
                    _buildPdfHeaderCell('STATUS', align: pw.TextAlign.center),
                  ],
                ),
                // Condensed Single-Line Fixture Rows
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

                  final isNextUpcoming = identical(f, nextUpcomingFixture) ||
                      (nextUpcomingFixture != null && f.id == nextUpcomingFixture.id);

                  final rowBg = isNextUpcoming
                      ? PdfColor.fromHex('#FEF3C7') // Rich gold highlight for next fixture
                      : ((isHomeMatched || isAwayMatched)
                          ? PdfColor.fromHex('#FFFBEB')
                          : (idx % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#FAFAFA')));

                  final shortDate = _formatShortDate(f);
                  final shortRound = _formatShortRound(f.roundNum);

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowBg),
                    children: [
                      // Date, Round, KO Time & Next Match Badge on ONE Line
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Row(
                                children: [
                                  pw.Text(
                                    shortDate,
                                    style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                      color: isNextUpcoming ? PdfColor.fromHex('#92400E') : PdfColor.fromHex('#1F2937'),
                                    ),
                                  ),
                                  if (shortRound.isNotEmpty) ...[
                                    pw.SizedBox(width: 3),
                                    pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
                                      decoration: pw.BoxDecoration(
                                        color: isNextUpcoming ? PdfColor.fromHex('#FDE68A') : PdfColor.fromHex('#E2E8F0'),
                                        borderRadius: pw.BorderRadius.circular(2),
                                      ),
                                      child: pw.Text(
                                        shortRound,
                                        style: pw.TextStyle(
                                          fontSize: 6.5,
                                          fontWeight: pw.FontWeight.bold,
                                          color: isNextUpcoming ? PdfColor.fromHex('#92400E') : PdfColor.fromHex('#475569'),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (isNextUpcoming) ...[
                                    pw.SizedBox(width: 3),
                                    pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                      decoration: pw.BoxDecoration(
                                        color: PdfColor.fromHex('#B45309'),
                                        borderRadius: pw.BorderRadius.circular(2),
                                      ),
                                      child: pw.Text(
                                        'NEXT MATCH',
                                        style: pw.TextStyle(
                                          fontSize: 6,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: pw.BoxDecoration(
                                color: isNextUpcoming ? PdfColor.fromHex('#FDE68A') : PdfColor.fromHex('#FEF3C7'),
                                borderRadius: pw.BorderRadius.circular(2),
                                border: pw.Border.all(
                                  color: isNextUpcoming ? PdfColor.fromHex('#D97706') : PdfColor.fromHex('#F59E0B'),
                                  width: 0.5,
                                ),
                              ),
                              child: pw.Text(
                                'KO ${f.time.isNotEmpty ? f.time : "15:00"}',
                                style: pw.TextStyle(
                                  fontSize: 7,
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
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                        child: pw.Text(
                          f.homeTeam,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: (isHomeMatched || isNextUpcoming) ? pw.FontWeight.bold : pw.FontWeight.normal,
                            color: isNextUpcoming
                                ? PdfColor.fromHex('#92400E')
                                : (isHomeMatched ? PdfColor.fromHex('#92400E') : PdfColor.fromHex('#1F2937')),
                          ),
                        ),
                      ),

                      // Score / VS Center Box
                      pw.Center(
                        child: pw.Container(
                          margin: const pw.EdgeInsets.symmetric(vertical: 2),
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: pw.BoxDecoration(
                            color: isCompleted
                                ? PdfColor.fromHex('#0F172A')
                                : (isNextUpcoming ? PdfColor.fromHex('#F59E0B') : PdfColor.fromHex('#FEF3C7')),
                            borderRadius: pw.BorderRadius.circular(2),
                            border: pw.Border.all(
                              color: isCompleted
                                  ? PdfColor.fromHex('#334155')
                                  : (isNextUpcoming ? PdfColor.fromHex('#B45309') : PdfColor.fromHex('#F59E0B')),
                              width: 0.5,
                            ),
                          ),
                          child: pw.Text(
                            isCompleted ? '${f.homeScore ?? 0} - ${f.awayScore ?? 0}' : 'VS',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: isCompleted
                                  ? PdfColors.white
                                  : (isNextUpcoming ? PdfColors.white : PdfColor.fromHex('#B45309')),
                            ),
                          ),
                        ),
                      ),

                      // Away Team
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                        child: pw.Text(
                          f.awayTeam,
                          textAlign: pw.TextAlign.left,
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: (isAwayMatched || isNextUpcoming) ? pw.FontWeight.bold : pw.FontWeight.normal,
                            color: isNextUpcoming
                                ? PdfColor.fromHex('#92400E')
                                : (isAwayMatched ? PdfColor.fromHex('#92400E') : PdfColor.fromHex('#1F2937')),
                          ),
                        ),
                      ),

                      // Status Badge
                      pw.Center(
                        child: pw.Container(
                          margin: const pw.EdgeInsets.symmetric(vertical: 2),
                          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: pw.BoxDecoration(
                            color: isCompleted
                                ? PdfColor.fromHex('#DCFCE7')
                                : (isNextUpcoming ? PdfColor.fromHex('#FDE68A') : PdfColor.fromHex('#FEF3C7')),
                          ),
                          child: pw.Text(
                            isNextUpcoming ? 'UPCOMING' : f.status.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              color: isCompleted
                                  ? PdfColor.fromHex('#15803D')
                                  : (isNextUpcoming ? PdfColor.fromHex('#92400E') : PdfColor.fromHex('#B45309')),
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: isHighlight ? PdfColor.fromHex('#F59E0B') : PdfColor.fromHex('#CBD5E1'),
        ),
      ),
    );
  }

  pw.Widget _buildPdfCell(String text, {bool isBold = false, double fontSize = 10, PdfColor? textColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 8.5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? PdfColor.fromHex('#374151'),
        ),
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    List<Fixture> activeFixtures,
    bool isTeamFiltered,
  ) async {
    try {
      final safeName = (filterTeam ?? divisionData.divisionName)
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'RFU_Schedule_$safeName.pdf';

      final bytes = await _generatePdfDoc(
        PdfPageFormat.a4,
        activeFixtures,
        isTeamFiltered,
      );

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);

        // 1. Open PDF in a new tab for immediate viewing & printing
        html.window.open(url, '_blank');

        // 2. Download the file
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..style.display = 'none';
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF generated! Opened in new tab & download started.'),
              backgroundColor: AppTheme.emeraldAccent,
            ),
          );
        }
        return;
      }

      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      debugPrint('PDF Export Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: AppTheme.rubyAccent,
          ),
        );
      }
    }
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

    // Identify next upcoming fixture
    Fixture? nextUpcoming;
    for (final f in activeFixtures) {
      final isCompleted = f.status.toLowerCase() == 'completed' ||
          (f.homeScore != null && f.awayScore != null);
      if (!isCompleted) {
        nextUpcoming = f;
        break;
      }
    }

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
                'Print / Save as PDF',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () => _exportPdf(context, activeFixtures, isTeamFiltered),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Document Header Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isTeamFiltered
                                    ? 'TEAM CONTEXT: ${filterTeam!.trim().toUpperCase()}  •  SEASON: ${divisionData.season}'
                                    : 'OFFICIAL LEAGUE & FIXTURE SCHEDULE  •  SEASON: ${divisionData.season}',
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: const Text(
                            'RFU OFFICIAL',
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SECTION 1: LEAGUE TABLE STANDINGS (LARGE, PROMINENT & SPACIOUS)
                  _buildSectionHeader('1. LEAGUE TABLE STANDINGS', Icons.table_chart),
                  const SizedBox(height: 10),
                  _buildPrintStandingsTable(divisionData.standings, filterTeam),

                  const SizedBox(height: 28),

                  // PAGE BREAK DIVIDER
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFF94A3B8), thickness: 1.5)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_downward, size: 14, color: Color(0xFF475569)),
                                SizedBox(width: 6),
                                Text(
                                  'PAGE BREAK  •  FIXTURES & RESULTS START ON PAGE 2',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFF94A3B8), thickness: 1.5)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SECTION 2: FIXTURES & RESULTS
                  _buildSectionHeader(
                    isTeamFiltered
                        ? '2. FIXTURES & RESULTS — ${filterTeam!.trim().toUpperCase()} (${activeFixtures.length} MATCHES)'
                        : '2. FIXTURES & RESULTS — ALL ROUNDS (${activeFixtures.length} MATCHES)',
                    Icons.event,
                  ),
                  const SizedBox(height: 10),
                  _buildPrintFixtures(activeFixtures, filterTeam, nextUpcoming),

                  const SizedBox(height: 24),

                  // Footer
                  const Center(
                    child: Text(
                      'Generated by RFU Hub • Official England Rugby League Data',
                      style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic),
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
            fontSize: 14.5,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPrintStandingsTable(List<StandingEntry> standings, String? highlightTeam) {
    if (standings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: Text(
            'No league table data available.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
        ),
      );
    }

    final cleanHighlight = highlightTeam?.trim().toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(38), // Pos
          1: FlexColumnWidth(5.0), // Club Name
          2: FixedColumnWidth(38), // P
          3: FixedColumnWidth(38), // W
          4: FixedColumnWidth(38), // D
          5: FixedColumnWidth(38), // L
          6: FixedColumnWidth(46), // PF
          7: FixedColumnWidth(46), // PA
          8: FixedColumnWidth(46), // +/-
          9: FixedColumnWidth(38), // TB
          10: FixedColumnWidth(38), // LB
          11: FixedColumnWidth(52), // Pts
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

          // Data Rows with large typography and generous vertical padding to fill Page 1
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
                border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
              ),
              children: [
                _buildCell('${s.pos}', isBold: true, fontSize: 13),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  child: Row(
                    children: [
                      _buildTeamLogo(s.teamName, s.logoUrl, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.teamName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isMatched ? FontWeight.w900 : FontWeight.w700,
                            color: isMatched ? const Color(0xFF92400E) : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCell('${s.played}', fontSize: 12.5),
                _buildCell('${s.won}', fontSize: 12.5),
                _buildCell('${s.drawn}', fontSize: 12.5),
                _buildCell('${s.lost}', fontSize: 12.5),
                _buildCell('${s.pointsFor}', fontSize: 12.5),
                _buildCell('${s.pointsAgainst}', fontSize: 12.5),
                _buildCell(
                  s.pointsDiff >= 0 ? '+${s.pointsDiff}' : '${s.pointsDiff}',
                  fontSize: 12.5,
                  textColor: s.pointsDiff >= 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                ),
                _buildCell('${s.tryBonus}', fontSize: 12.5),
                _buildCell('${s.lossBonus}', fontSize: 12.5),
                _buildCell('${s.points}', isBold: true, fontSize: 14, textColor: const Color(0xFFB45309)),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: isHighlight ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCell(String text,
      {TextAlign align = TextAlign.center, bool isBold = false, double fontSize = 12.5, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
          color: textColor ?? const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildPrintFixtures(List<Fixture> fixtures, String? highlightTeam, Fixture? nextUpcoming) {
    if (fixtures.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Center(
          child: Text(
            'No fixtures available for this selection.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
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

          final isNextUpcoming = (nextUpcoming != null && (identical(f, nextUpcoming) || f.id == nextUpcoming.id));

          final isEven = index % 2 == 0;
          final rowBg = isNextUpcoming
              ? const Color(0xFFFEF3C7) // Rich gold highlight for next fixture
              : ((isHomeMatched || isAwayMatched)
                  ? const Color(0xFFFFFBEB)
                  : (isEven ? Colors.white : const Color(0xFFFAFAFA)));

          final shortDate = _formatShortDate(f);
          final shortRound = _formatShortRound(f.roundNum);

          return Container(
            decoration: BoxDecoration(
              color: rowBg,
              border: isNextUpcoming
                  ? const Border(
                      left: BorderSide(color: Color(0xFFD97706), width: 4),
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                // Date, Round, KO Time & Next Match Badge on ONE Single Line
                SizedBox(
                  width: 275,
                  child: Row(
                    children: [
                      Text(
                        shortDate,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isNextUpcoming ? const Color(0xFF92400E) : const Color(0xFF1F2937),
                        ),
                      ),
                      if (shortRound.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isNextUpcoming ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            shortRound,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isNextUpcoming ? const Color(0xFF92400E) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                      if (isNextUpcoming) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB45309),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 9, color: Colors.white),
                              SizedBox(width: 2),
                              Text(
                                'NEXT MATCH',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 5),
                      // KO Time Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: isNextUpcoming ? const Color(0xFFFDE68A) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: isNextUpcoming ? const Color(0xFFD97706) : const Color(0xFFF59E0B),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, size: 9.5, color: Color(0xFFB45309)),
                            const SizedBox(width: 2.5),
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

                const SizedBox(width: 8),

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
                            fontSize: 11.5,
                            fontWeight: (isHomeMatched || isNextUpcoming) ? FontWeight.w900 : FontWeight.w600,
                            color: isNextUpcoming
                                ? const Color(0xFF92400E)
                                : (isHomeMatched ? const Color(0xFF92400E) : const Color(0xFF1F2937)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildTeamLogo(f.homeTeam, f.homeLogoUrl, size: 18),
                    ],
                  ),
                ),

                // Score / VS Box
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  constraints: const BoxConstraints(minWidth: 52),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF0F172A)
                        : (isNextUpcoming ? const Color(0xFFF59E0B) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF334155)
                          : (isNextUpcoming ? const Color(0xFFB45309) : const Color(0xFFF59E0B)),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isCompleted
                          ? '${f.homeScore ?? 0} - ${f.awayScore ?? 0}'
                          : 'VS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: isCompleted
                            ? Colors.white
                            : (isNextUpcoming ? Colors.white : const Color(0xFFB45309)),
                      ),
                    ),
                  ),
                ),

                // Away Team
                Expanded(
                  child: Row(
                    children: [
                      _buildTeamLogo(f.awayTeam, f.awayLogoUrl, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          f.awayTeam,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: (isAwayMatched || isNextUpcoming) ? FontWeight.w900 : FontWeight.w600,
                            color: isNextUpcoming
                                ? const Color(0xFF92400E)
                                : (isAwayMatched ? const Color(0xFF92400E) : const Color(0xFF1F2937)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFDCFCE7)
                        : (isNextUpcoming ? const Color(0xFFFDE68A) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    isNextUpcoming ? 'UPCOMING' : f.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? const Color(0xFF15803D)
                          : (isNextUpcoming ? const Color(0xFF92400E) : const Color(0xFFB45309)),
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
