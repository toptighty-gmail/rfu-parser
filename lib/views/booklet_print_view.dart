import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/division_data.dart';
import '../models/fixture.dart';
import '../models/standing_entry.dart';
import '../widgets/team_logo_image.dart';
import '../theme/app_theme.dart';

class PdfLogoItem {
  final pw.MemoryImage? rasterImage;
  final String? svgString;

  const PdfLogoItem({this.rasterImage, this.svgString});

  pw.Widget buildWidget(
    String teamName, {
    double size = 16,
    required PdfColor fallbackBg,
    required PdfColor accentColor,
  }) {
    if (svgString != null && svgString!.isNotEmpty) {
      try {
        return pw.Container(
          width: size,
          height: size,
          child: pw.SvgImage(svg: svgString!),
        );
      } catch (_) {}
    }

    if (rasterImage != null) {
      try {
        return pw.Container(
          width: size,
          height: size,
          child: pw.Image(
            rasterImage!,
            width: size,
            height: size,
            fit: pw.BoxFit.contain,
          ),
        );
      } catch (_) {}
    }

    // Clean circle initial badge fallback (NEVER an empty box or cross)
    final initial = teamName.trim().isNotEmpty ? teamName.trim().substring(0, 1).toUpperCase() : 'R';
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: fallbackBg,
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: accentColor, width: 0.8),
      ),
      child: pw.Center(
        child: pw.Text(
          initial,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: size * 0.55,
          ),
        ),
      ),
    );
  }
}

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

  static PdfColor _toPdfColor(Color c) {
    return PdfColor(c.r, c.g, c.b, c.a);
  }

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

  static String _formatFullDate(Fixture f) {
    final dt = _parseFixtureDate(f);
    if (dt.year < 2090) {
      return DateFormat('EEE d MMM yyyy').format(dt); // e.g. "Sat 20 Mar 2026"
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

  static String _formatFullRound(String round) {
    if (round.trim().isEmpty) return '';
    final clean = round.trim();
    if (clean.toLowerCase().contains('cup')) return 'Cup';
    if (clean.toLowerCase().contains('friendly')) return 'Friendly';
    final match = RegExp(r'(\d+)').firstMatch(clean);
    if (match != null) {
      return 'Round ${match.group(1)}';
    }
    return clean;
  }

  String? _resolveLogo(String teamName, String? defaultLogoUrl) {
    if (defaultLogoUrl != null && defaultLogoUrl.trim().isNotEmpty) {
      return defaultLogoUrl.trim();
    }
    final clean = teamName.trim().toLowerCase();
    if (customLogosMap.containsKey(clean)) {
      return customLogosMap[clean];
    }
    // Alias match for OPMs / Old Plymothian
    if (clean == 'opms' || clean == 'opm' || clean == 'opms ii' || clean.contains('plymothian')) {
      for (var entry in customLogosMap.entries) {
        final k = entry.key.toLowerCase();
        if (k.contains('plymothian') || k == 'opms' || k == 'opm') {
          return entry.value;
        }
      }
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

  Future<Map<String, PdfLogoItem>> _preloadAllLogos(
    List<StandingEntry> standings,
    List<Fixture> fixtures,
    String? filterTeam,
  ) async {
    final Map<String, PdfLogoItem> cache = {};
    final Set<String> allTeams = {};

    if (filterTeam != null && filterTeam.trim().isNotEmpty) {
      allTeams.add(filterTeam.trim());
    }
    for (var s in standings) {
      allTeams.add(s.teamName.trim());
    }
    for (var f in fixtures) {
      allTeams.add(f.homeTeam.trim());
      allTeams.add(f.awayTeam.trim());
    }

    final client = http.Client();
    try {
      final futures = allTeams.map((teamName) async {
        final logoUrl = _resolveLogo(teamName, null);
        if (logoUrl == null || logoUrl.trim().isEmpty) return;

        final url = logoUrl.trim();
        try {
          if (url.startsWith('data:image/svg') || url.contains('image/svg+xml')) {
            final base64Part = url.split(',').last;
            final bytes = base64Decode(base64Part);
            final svgStr = utf8.decode(bytes);
            cache[teamName.toLowerCase()] = PdfLogoItem(svgString: svgStr);
          } else if (url.startsWith('data:image')) {
            final base64Part = url.split(',').last;
            final bytes = base64Decode(base64Part);
            cache[teamName.toLowerCase()] = PdfLogoItem(rasterImage: pw.MemoryImage(bytes));
          } else if (url.startsWith('http://') || url.startsWith('https://')) {
            final res = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
            if (res.statusCode == 200) {
              final bytes = res.bodyBytes;
              final isSvg = url.toLowerCase().contains('.svg') || (res.headers['content-type']?.contains('svg') == true);
              if (isSvg) {
                final svgStr = utf8.decode(bytes);
                cache[teamName.toLowerCase()] = PdfLogoItem(svgString: svgStr);
              } else {
                cache[teamName.toLowerCase()] = PdfLogoItem(rasterImage: pw.MemoryImage(bytes));
              }
            }
          }
        } catch (_) {}
      });

      await Future.wait(futures);
    } finally {
      client.close();
    }

    return cache;
  }

  Future<Uint8List> _generatePdfDoc(
    PdfPageFormat format,
    List<Fixture> sortedFixtures,
    bool isTeamFiltered,
    Map<String, PdfLogoItem> logoCache,
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

    final theme = AppTheme.currentMode;
    final primaryPdf = _toPdfColor(theme.darkBg);
    final surfacePdf = _toPdfColor(theme.surfaceBg);
    final accentPdf = _toPdfColor(theme.goldAccent);
    final tertiaryPdf = _toPdfColor(theme.tertiaryAccent);
    final borderPdf = _toPdfColor(theme.cardBorder);
    final textPrimaryPdf = _toPdfColor(theme.textPrimary);
    final textMutedPdf = _toPdfColor(theme.textMuted);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              color: surfacePdf,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: accentPdf, width: 1.2),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      if (isTeamFiltered) ...[
                        pw.Container(
                          margin: const pw.EdgeInsets.only(right: 10),
                          child: (logoCache[filterTeam!.trim().toLowerCase()] ?? const PdfLogoItem()).buildWidget(
                            filterTeam!,
                            size: 28,
                            fallbackBg: primaryPdf,
                            accentColor: accentPdf,
                          ),
                        ),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            divisionData.divisionName.toUpperCase(),
                            style: pw.TextStyle(
                              color: accentPdf,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            isTeamFiltered
                                ? 'TEAM CONTEXT: ${filterTeam!.trim().toUpperCase()}  |  SEASON: ${divisionData.season}'
                                : 'OFFICIAL FIXTURE & LEAGUE SCHEDULE  |  SEASON: ${divisionData.season}',
                            style: pw.TextStyle(
                              color: textPrimaryPdf,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: primaryPdf,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: accentPdf),
                  ),
                  child: pw.Text(
                    'Copyrighted Sean Cook 2026',
                    style: pw.TextStyle(
                      color: accentPdf,
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
                  'Generated by RFU Hub | Official England Rugby League Data',
                  style: pw.TextStyle(fontSize: 8, color: textMutedPdf),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: textMutedPdf),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // SECTION 1: STANDINGS TABLE (PAGE 1 WITH CONTEXT TEAM LOGO IN HEADER)
            if (divisionData.standings.isNotEmpty) ...[
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (isTeamFiltered) ...[
                      pw.Container(
                        margin: const pw.EdgeInsets.only(right: 8),
                        child: (logoCache[filterTeam!.trim().toLowerCase()] ?? const PdfLogoItem()).buildWidget(
                          filterTeam!,
                          size: 18,
                          fallbackBg: surfacePdf,
                          accentColor: accentPdf,
                        ),
                      ),
                    ],
                    pw.Text(
                      '1. LEAGUE TABLE STANDINGS',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: surfacePdf,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                columnWidths: const {
                  0: pw.FixedColumnWidth(28),  // Pos
                  1: pw.FlexColumnWidth(5.0),  // Club Name + Logo
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
                  // Table Header in Active Theme Surface Color
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: surfacePdf),
                    children: [
                      _buildPdfHeaderCell('#', accentPdf: accentPdf, textPdf: textPrimaryPdf),
                      _buildPdfHeaderCell('CLUB', align: pw.TextAlign.left, accentPdf: accentPdf, textPdf: textPrimaryPdf),
                      _buildPdfHeaderCell('P', accentPdf: accentPdf, textPdf: textPrimaryPdf),
                      _buildPdfHeaderCell('W', accentPdf: accentPdf, textPdf: textPrimaryPdf),
                      _buildPdfHeaderCell('D', accentPdf: accentPdf, textPdf: textPrimaryPdf),
                      _buildPdfHeaderCell('L', accentPdf: accentPdf, textPdf: textPrimaryPdf),
                      _buildPdfHeaderCell('PF', accentPdf: accentPdf, textPdf: textPrimaryPdf),
                      _buildPdfHeaderCell('PA', accentPdf: accentPdf, textPdf: textPrimaryPdf),
                      _buildPdfHeaderCell('+/-', accentPdf: accentPdf, textPdf: textPrimaryPdf),
                      _buildPdfHeaderCell('TB', accentPdf: accentPdf, textPdf: textPrimaryPdf),
                      _buildPdfHeaderCell('LB', accentPdf: accentPdf, textPdf: textPrimaryPdf),
                      _buildPdfHeaderCell('PTS', isHighlight: true, accentPdf: accentPdf, textPdf: textPrimaryPdf),
                    ],
                  ),
                  // Table Rows: Context Team highlighted in BRIGHT YELLOW with RED BORDER
                  ...divisionData.standings.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    final isMatched = cleanHighlight != null &&
                        cleanHighlight.isNotEmpty &&
                        s.teamName.toLowerCase().contains(cleanHighlight);

                    final rowBg = isMatched
                        ? PdfColor.fromHex('#FEF08A') // Bright Yellow Highlight
                        : (idx % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F9FAFB'));

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: rowBg,
                        border: isMatched
                            ? pw.Border.all(color: PdfColor.fromHex('#DC2626'), width: 1.5) // Red Border
                            : null,
                      ),
                      children: [
                        _buildPdfCell(
                          '${s.pos}',
                          isBold: true,
                          fontSize: 11,
                          textColor: isMatched ? PdfColor.fromHex('#991B1B') : null,
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8.5),
                          child: pw.Row(
                            children: [
                              // Real Team Logo in PDF
                              (logoCache[s.teamName.trim().toLowerCase()] ?? const PdfLogoItem()).buildWidget(
                                s.teamName,
                                size: 16,
                                fallbackBg: isMatched ? PdfColor.fromHex('#DC2626') : surfacePdf,
                                accentColor: accentPdf,
                              ),
                              pw.SizedBox(width: 6),
                              pw.Expanded(
                                child: pw.Text(
                                  s.teamName,
                                  style: pw.TextStyle(
                                    fontSize: 12,
                                    fontWeight: isMatched ? pw.FontWeight.bold : pw.FontWeight.normal,
                                    color: isMatched ? PdfColor.fromHex('#991B1B') : PdfColor.fromHex('#111827'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildPdfCell('${s.played}', fontSize: 10.5, textColor: isMatched ? PdfColor.fromHex('#991B1B') : null),
                        _buildPdfCell('${s.won}', fontSize: 10.5, textColor: isMatched ? PdfColor.fromHex('#991B1B') : null),
                        _buildPdfCell('${s.drawn}', fontSize: 10.5, textColor: isMatched ? PdfColor.fromHex('#991B1B') : null),
                        _buildPdfCell('${s.lost}', fontSize: 10.5, textColor: isMatched ? PdfColor.fromHex('#991B1B') : null),
                        _buildPdfCell('${s.pointsFor}', fontSize: 10.5, textColor: isMatched ? PdfColor.fromHex('#991B1B') : null),
                        _buildPdfCell('${s.pointsAgainst}', fontSize: 10.5, textColor: isMatched ? PdfColor.fromHex('#991B1B') : null),
                        _buildPdfCell(
                          s.pointsDiff >= 0 ? '+${s.pointsDiff}' : '${s.pointsDiff}',
                          fontSize: 10.5,
                          textColor: s.pointsDiff >= 0 ? PdfColor.fromHex('#15803D') : PdfColor.fromHex('#DC2626'),
                        ),
                        _buildPdfCell('${s.tryBonus}', fontSize: 10.5, textColor: isMatched ? PdfColor.fromHex('#991B1B') : null),
                        _buildPdfCell('${s.lossBonus}', fontSize: 10.5, textColor: isMatched ? PdfColor.fromHex('#991B1B') : null),
                        _buildPdfCell(
                          '${s.points}',
                          isBold: true,
                          fontSize: 11.5,
                          textColor: isMatched ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#B45309'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              // PAGE BREAK AFTER LEAGUE STANDINGS TABLE
              pw.NewPage(),
            ],

            // SECTION 2: FIXTURES & RESULTS (PAGE 2 WITH FULL DATES, ROUND NAMES & TEAM LOGOS)
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (isTeamFiltered) ...[
                    pw.Container(
                      margin: const pw.EdgeInsets.only(right: 8),
                      child: (logoCache[filterTeam!.trim().toLowerCase()] ?? const PdfLogoItem()).buildWidget(
                        filterTeam!,
                        size: 20,
                        fallbackBg: surfacePdf,
                        accentColor: accentPdf,
                      ),
                    ),
                  ],
                  pw.Expanded(
                    child: pw.Text(
                      isTeamFiltered
                          ? '2. FIXTURES & RESULTS — ${filterTeam!.trim().toUpperCase()} (${sortedFixtures.length} MATCHES)'
                          : '2. FIXTURES & RESULTS — ALL ROUNDS (${sortedFixtures.length} MATCHES)',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: surfacePdf,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.6),
              columnWidths: const {
                0: pw.FixedColumnWidth(215), // Full Date & Round Name & KO Badge
                1: pw.FlexColumnWidth(3.0),  // Home Team + Logo
                2: pw.FixedColumnWidth(48),  // Score / VS Box
                3: pw.FlexColumnWidth(3.0),  // Away Team + Logo
                4: pw.FixedColumnWidth(54),  // Status
              },
              children: [
                // Header in Active Theme Surface Color
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: surfacePdf),
                  children: [
                    _buildPdfHeaderCell('DATE & ROUND', align: pw.TextAlign.left, fontSize: 9, accentPdf: accentPdf, textPdf: textPrimaryPdf),
                    _buildPdfHeaderCell('HOME TEAM', align: pw.TextAlign.right, fontSize: 9, accentPdf: accentPdf, textPdf: textPrimaryPdf),
                    _buildPdfHeaderCell('SCORE', align: pw.TextAlign.center, fontSize: 9, accentPdf: accentPdf, textPdf: textPrimaryPdf),
                    _buildPdfHeaderCell('AWAY TEAM', align: pw.TextAlign.left, fontSize: 9, accentPdf: accentPdf, textPdf: textPrimaryPdf),
                    _buildPdfHeaderCell('STATUS', align: pw.TextAlign.center, fontSize: 9, accentPdf: accentPdf, textPdf: textPrimaryPdf),
                  ],
                ),
                // Fixture Rows: Dynamic vertical padding to fill the A4 page; Next Match in Bright Yellow / Red Border
                ...(() {
                  final double pdfRowPad = ((630.0 / (sortedFixtures.isNotEmpty ? sortedFixtures.length : 1) - 13.0) / 2.0).clamp(2.5, 18.0);
                  final double pdfBoxMargin = (pdfRowPad * 0.35).clamp(1.0, 5.0);

                  return sortedFixtures.asMap().entries.map((entry) {
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
                        (nextUpcomingFixture?.id != null &&
                         nextUpcomingFixture!.id!.isNotEmpty &&
                         f.id != null &&
                         f.id == nextUpcomingFixture.id);

                    // Alternating White & Light Grey for standard rows; Bright Yellow ONLY for Next Upcoming Match
                    final rowBg = isNextUpcoming
                        ? PdfColor.fromHex('#FEF08A') // Bright Yellow Highlight
                        : (idx % 2 == 0 ? PdfColors.white : PdfColor.fromHex('#F9FAFB'));

                    final fullDate = _formatFullDate(f);
                    final fullRound = _formatFullRound(f.roundNum);

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: rowBg,
                        border: isNextUpcoming
                            ? pw.Border.all(color: PdfColor.fromHex('#DC2626'), width: 1.5) // Red Border
                            : null,
                      ),
                      children: [
                        // Full Date, Full Round Name, KO Time & Next Match Badge on ONE Clean Line
                        pw.Padding(
                          padding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: pdfRowPad),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Row(
                                  children: [
                                    pw.Text(
                                      fullDate,
                                      style: pw.TextStyle(
                                        fontSize: 8,
                                        fontWeight: pw.FontWeight.bold,
                                        color: isNextUpcoming ? PdfColor.fromHex('#991B1B') : PdfColor.fromHex('#1F2937'),
                                      ),
                                    ),
                                    if (fullRound.isNotEmpty) ...[
                                      pw.SizedBox(width: 3),
                                      pw.Container(
                                        padding: const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
                                        decoration: pw.BoxDecoration(
                                          color: isNextUpcoming
                                              ? PdfColor.fromHex('#FDE047')
                                              : (f.isCustom || fullRound.toLowerCase().contains('cup') || fullRound.toLowerCase().contains('friendly')
                                                  ? tertiaryPdf
                                                  : PdfColor.fromHex('#E2E8F0')),
                                          borderRadius: pw.BorderRadius.circular(2),
                                        ),
                                        child: pw.Text(
                                          fullRound,
                                          style: pw.TextStyle(
                                            fontSize: 6.8,
                                            fontWeight: pw.FontWeight.bold,
                                            color: isNextUpcoming
                                                ? PdfColor.fromHex('#991B1B')
                                                : (f.isCustom || fullRound.toLowerCase().contains('cup') || fullRound.toLowerCase().contains('friendly')
                                                    ? PdfColors.white
                                                    : PdfColor.fromHex('#475569')),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (isNextUpcoming) ...[
                                      pw.SizedBox(width: 3),
                                      pw.Container(
                                        padding: const pw.EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
                                        decoration: pw.BoxDecoration(
                                          color: PdfColor.fromHex('#DC2626'), // Bold Red Badge
                                          borderRadius: pw.BorderRadius.circular(2),
                                        ),
                                        child: pw.Text(
                                          'NEXT MATCH',
                                          style: pw.TextStyle(
                                            fontSize: 6.5,
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
                                padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                                decoration: pw.BoxDecoration(
                                  color: isNextUpcoming ? PdfColor.fromHex('#FDE047') : PdfColor.fromHex('#FEF3C7'),
                                  borderRadius: pw.BorderRadius.circular(2),
                                  border: pw.Border.all(
                                    color: isNextUpcoming ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#F59E0B'),
                                    width: 0.6,
                                  ),
                                ),
                                child: pw.Text(
                                  'KO ${f.time.isNotEmpty ? f.time : "15:00"}',
                                  style: pw.TextStyle(
                                    fontSize: 7.2,
                                    fontWeight: pw.FontWeight.bold,
                                    color: isNextUpcoming ? PdfColor.fromHex('#991B1B') : PdfColor.fromHex('#B45309'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Home Team + Logo in PDF
                        pw.Padding(
                          padding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: pdfRowPad),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Expanded(
                                child: pw.Text(
                                  f.homeTeam,
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: (isHomeMatched || isNextUpcoming) ? pw.FontWeight.bold : pw.FontWeight.normal,
                                    color: isNextUpcoming
                                        ? PdfColor.fromHex('#991B1B')
                                        : (isHomeMatched ? PdfColor.fromHex('#92400E') : PdfColor.fromHex('#1F2937')),
                                  ),
                                ),
                              ),
                              pw.SizedBox(width: 4),
                              (logoCache[f.homeTeam.trim().toLowerCase()] ?? const PdfLogoItem()).buildWidget(
                                f.homeTeam,
                                size: 12,
                                fallbackBg: surfacePdf,
                                accentColor: accentPdf,
                              ),
                            ],
                          ),
                        ),

                        // Score / VS Box (Always 'VS' for upcoming matches, Score for completed)
                        pw.Center(
                          child: pw.Container(
                            margin: pw.EdgeInsets.symmetric(vertical: pdfBoxMargin),
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: isCompleted
                                  ? surfacePdf
                                  : (isNextUpcoming ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#FEF3C7')),
                              borderRadius: pw.BorderRadius.circular(3),
                              border: pw.Border.all(
                                color: isCompleted
                                    ? borderPdf
                                    : (isNextUpcoming ? PdfColor.fromHex('#991B1B') : PdfColor.fromHex('#F59E0B')),
                                width: 0.6,
                              ),
                            ),
                            child: pw.Text(
                              isCompleted ? '${f.homeScore ?? 0} - ${f.awayScore ?? 0}' : 'VS',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: isCompleted
                                    ? textPrimaryPdf
                                    : (isNextUpcoming ? PdfColors.white : PdfColor.fromHex('#B45309')),
                              ),
                            ),
                          ),
                        ),

                        // Away Team + Logo in PDF
                        pw.Padding(
                          padding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: pdfRowPad),
                          child: pw.Row(
                            children: [
                              (logoCache[f.awayTeam.trim().toLowerCase()] ?? const PdfLogoItem()).buildWidget(
                                f.awayTeam,
                                size: 12,
                                fallbackBg: surfacePdf,
                                accentColor: accentPdf,
                              ),
                              pw.SizedBox(width: 4),
                              pw.Expanded(
                                child: pw.Text(
                                  f.awayTeam,
                                  textAlign: pw.TextAlign.left,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: (isAwayMatched || isNextUpcoming) ? pw.FontWeight.bold : pw.FontWeight.normal,
                                    color: isNextUpcoming
                                        ? PdfColor.fromHex('#991B1B')
                                        : (isAwayMatched ? PdfColor.fromHex('#92400E') : PdfColor.fromHex('#1F2937')),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Status Badge
                        pw.Center(
                          child: pw.Container(
                            margin: pw.EdgeInsets.symmetric(vertical: pdfBoxMargin),
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                            decoration: pw.BoxDecoration(
                              color: isCompleted
                                  ? PdfColor.fromHex('#DCFCE7')
                                  : (isNextUpcoming ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#FEF3C7')),
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                            child: pw.Text(
                              isNextUpcoming ? 'UPCOMING' : f.status.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 7.2,
                                fontWeight: pw.FontWeight.bold,
                                color: isCompleted
                                  ? PdfColor.fromHex('#15803D')
                                  : (isNextUpcoming ? PdfColors.white : PdfColor.fromHex('#B45309')),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  });
                })(),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _buildPdfHeaderCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
    double fontSize = 9.5,
    bool isHighlight = false,
    required PdfColor accentPdf,
    required PdfColor textPdf,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
          color: isHighlight ? accentPdf : textPdf,
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing PDF and embedding team logos...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final logoCache = await _preloadAllLogos(
        divisionData.standings,
        activeFixtures,
        filterTeam,
      );

      final safeName = (filterTeam ?? divisionData.divisionName)
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'RFU_Schedule_$safeName.pdf';

      final bytes = await _generatePdfDoc(
        PdfPageFormat.a4,
        activeFixtures,
        isTeamFiltered,
        logoCache,
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
            SnackBar(
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

    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: theme.darkBg,
          appBar: AppBar(
            backgroundColor: theme.surfaceBg,
            elevation: 1,
            title: Text(
              isTeamFiltered
                  ? 'A4 Print: ${filterTeam!.trim().toUpperCase()}'
                  : 'A4 Print: ${divisionData.divisionName}',
              style: TextStyle(color: theme.goldAccent, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.goldAccent,
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
                        color: Colors.black.withValues(alpha: 0.15),
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
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: theme.surfaceBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.goldAccent, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (isTeamFiltered) ...[
                              _buildTeamLogo(filterTeam!, null, size: 36),
                              const SizedBox(width: 14),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    divisionData.divisionName.toUpperCase(),
                                    style: TextStyle(
                                      color: theme.goldAccent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isTeamFiltered
                                        ? 'TEAM CONTEXT: ${filterTeam!.trim().toUpperCase()}  |  SEASON: ${divisionData.season}'
                                        : 'OFFICIAL LEAGUE & FIXTURE SCHEDULE  |  SEASON: ${divisionData.season}',
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: theme.darkBg,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: theme.goldAccent),
                              ),
                              child: Text(
                                'Copyrighted Sean Cook 2026',
                                style: TextStyle(
                                  color: theme.goldAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // SECTION 1: LEAGUE TABLE STANDINGS (WITH CONTEXT TEAM LOGO IN HEADER)
                      _buildSectionHeader(
                        '1. LEAGUE TABLE STANDINGS',
                        Icons.table_chart,
                        theme: theme,
                        leadingWidget: isTeamFiltered ? _buildTeamLogo(filterTeam!, null, size: 24) : null,
                      ),
                      const SizedBox(height: 10),
                      _buildPrintStandingsTable(divisionData.standings, filterTeam, theme),

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
                                      'PAGE BREAK  |  FIXTURES & RESULTS START ON PAGE 2',
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

                      // SECTION 2: FIXTURES & RESULTS (WITH CONTEXT TEAM LOGO)
                      _buildSectionHeader(
                        isTeamFiltered
                            ? '2. FIXTURES & RESULTS — ${filterTeam!.trim().toUpperCase()} (${activeFixtures.length} MATCHES)'
                            : '2. FIXTURES & RESULTS — ALL ROUNDS (${activeFixtures.length} MATCHES)',
                        Icons.event,
                        theme: theme,
                        leadingWidget: isTeamFiltered ? _buildTeamLogo(filterTeam!, null, size: 24) : null,
                      ),
                      const SizedBox(height: 10),
                      _buildPrintFixtures(activeFixtures, filterTeam, nextUpcoming, theme),

                      const SizedBox(height: 24),

                      // Footer
                      const Center(
                        child: Text(
                          'Generated by RFU Hub | Official England Rugby League Data',
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
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {required AppThemeMode theme, Widget? leadingWidget}) {
    return Row(
      children: [
        if (leadingWidget != null) ...[
          leadingWidget,
          const SizedBox(width: 10),
        ] else ...[
          Icon(icon, color: theme.surfaceBg, size: 18),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: theme.surfaceBg,
              fontWeight: FontWeight.w900,
              fontSize: 14.5,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrintStandingsTable(List<StandingEntry> standings, String? highlightTeam, AppThemeMode theme) {
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
          // Header Row in Theme Surface Color
          TableRow(
            decoration: BoxDecoration(
              color: theme.surfaceBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
            children: [
              _HeaderCell('#', accentColor: theme.goldAccent, textColor: theme.textPrimary),
              _HeaderCell('CLUB', align: TextAlign.left, accentColor: theme.goldAccent, textColor: theme.textPrimary),
              _HeaderCell('P', accentColor: theme.goldAccent, textColor: theme.textPrimary),
              _HeaderCell('W', accentColor: theme.goldAccent, textColor: theme.textPrimary),
              _HeaderCell('D', accentColor: theme.goldAccent, textColor: theme.textPrimary),
              _HeaderCell('L', accentColor: theme.goldAccent, textColor: theme.textPrimary),
              _HeaderCell('PF', accentColor: theme.goldAccent, textColor: theme.textPrimary),
              _HeaderCell('PA', accentColor: theme.goldAccent, textColor: theme.textPrimary),
              _HeaderCell('+/-', accentColor: theme.goldAccent, textColor: theme.textPrimary),
              _HeaderCell('TB', accentColor: theme.goldAccent, textColor: theme.textPrimary),
              _HeaderCell('LB', accentColor: theme.goldAccent, textColor: theme.textPrimary),
              _HeaderCell('PTS', isHighlight: true, accentColor: theme.goldAccent, textColor: theme.textPrimary),
            ],
          ),

          // Data Rows with clean alternating rows; context team in bright yellow with red border
          ...standings.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final isMatched = cleanHighlight != null &&
                cleanHighlight.isNotEmpty &&
                s.teamName.toLowerCase().contains(cleanHighlight);

            final isEven = idx % 2 == 0;
            final rowColor = isMatched
                ? const Color(0xFFFEF08A) // Bright Yellow Highlight
                : (isEven ? Colors.white : const Color(0xFFF9FAFB));

            return TableRow(
              decoration: BoxDecoration(
                color: rowColor,
                border: isMatched
                    ? Border.all(color: const Color(0xFFDC2626), width: 2) // Red Border
                    : const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
              ),
              children: [
                _buildCell(
                  '${s.pos}',
                  isBold: true,
                  fontSize: 13,
                  textColor: isMatched ? const Color(0xFF991B1B) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  child: Row(
                    children: [
                      _buildTeamLogo(s.teamName, s.logoUrl, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.teamName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isMatched ? FontWeight.w900 : FontWeight.w600,
                            color: isMatched ? const Color(0xFF991B1B) : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCell('${s.played}', textColor: isMatched ? const Color(0xFF991B1B) : null),
                _buildCell('${s.won}', isBold: true, textColor: isMatched ? const Color(0xFF991B1B) : const Color(0xFF16A34A)),
                _buildCell('${s.drawn}', textColor: isMatched ? const Color(0xFF991B1B) : null),
                _buildCell('${s.lost}', textColor: isMatched ? const Color(0xFF991B1B) : const Color(0xFFDC2626)),
                _buildCell('${s.pointsFor}', textColor: isMatched ? const Color(0xFF991B1B) : null),
                _buildCell('${s.pointsAgainst}', textColor: isMatched ? const Color(0xFF991B1B) : null),
                _buildCell(
                  s.pointsDiff >= 0 ? '+${s.pointsDiff}' : '${s.pointsDiff}',
                  isBold: true,
                  textColor: isMatched
                      ? const Color(0xFF991B1B)
                      : (s.pointsDiff >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                ),
                _buildCell('${s.tryBonus}', textColor: isMatched ? const Color(0xFF991B1B) : null),
                _buildCell('${s.lossBonus}', textColor: isMatched ? const Color(0xFF991B1B) : null),
                _buildCell(
                  '${s.points}',
                  isBold: true,
                  fontSize: 14,
                  textColor: isMatched ? const Color(0xFFDC2626) : const Color(0xFFB45309),
                ),
              ],
            );
          }),
        ],
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

  Widget _buildPrintFixtures(List<Fixture> fixtures, String? highlightTeam, Fixture? nextUpcoming, AppThemeMode theme) {
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
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          // Table Header in Theme Surface Color
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.surfaceBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 320,
                  child: Text(
                    'DATE & ROUND',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.textPrimary, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HOME TEAM',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.textPrimary, letterSpacing: 0.5),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Center(
                    child: Text(
                      'SCORE',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.goldAccent, letterSpacing: 0.5),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'AWAY TEAM',
                    textAlign: TextAlign.start,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.textPrimary, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: Center(
                    child: Text(
                      'STATUS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.textPrimary, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Fixture Rows
          ListView.separated(
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

              final isNextUpcoming = nextUpcoming != null &&
                  (identical(f, nextUpcoming) ||
                   (nextUpcoming.id != null &&
                    nextUpcoming.id!.isNotEmpty &&
                    f.id != null &&
                    f.id == nextUpcoming.id));

              final isEven = index % 2 == 0;
              final rowBg = isNextUpcoming
                  ? const Color(0xFFFEF08A) // Bright Yellow Highlight
                  : (isEven ? Colors.white : const Color(0xFFF9FAFB));

              final fullDate = _formatFullDate(f);
              final fullRound = _formatFullRound(f.roundNum);
              final double screenRowPad = ((680.0 / (fixtures.isNotEmpty ? fixtures.length : 1) - 16.0) / 2.0).clamp(5.0, 20.0);

              return Container(
                decoration: BoxDecoration(
                  color: rowBg,
                  border: isNextUpcoming
                      ? Border.all(color: const Color(0xFFDC2626), width: 2) // Red Border
                      : null,
                ),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: screenRowPad),
                child: Row(
                  children: [
                    // Full Date, Full Round Name, KO Time & Next Match Badge on ONE Single Line
                    SizedBox(
                      width: 355,
                      child: Row(
                        children: [
                          Text(
                            fullDate,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isNextUpcoming ? const Color(0xFF991B1B) : const Color(0xFF1F2937),
                            ),
                          ),
                          if (fullRound.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isNextUpcoming ? const Color(0xFFFDE047) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                fullRound,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isNextUpcoming ? const Color(0xFF991B1B) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                          if (isNextUpcoming) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626), // Bold Red Badge
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'NEXT MATCH',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // KO Time Box
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isNextUpcoming ? const Color(0xFFFDE047) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isNextUpcoming ? const Color(0xFFDC2626) : const Color(0xFFF59E0B),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'KO ${f.time.isNotEmpty ? f.time : "15:00"}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isNextUpcoming ? const Color(0xFF991B1B) : const Color(0xFFB45309),
                              ),
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
                                fontSize: 12.5,
                                fontWeight: (isHomeMatched || isNextUpcoming) ? FontWeight.w900 : FontWeight.w600,
                                color: isNextUpcoming
                                    ? const Color(0xFF991B1B)
                                    : (isHomeMatched ? const Color(0xFF92400E) : const Color(0xFF1F2937)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildTeamLogo(f.homeTeam, f.homeLogoUrl, size: 20),
                        ],
                      ),
                    ),

                    // Score / VS Box
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      constraints: const BoxConstraints(minWidth: 54),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? theme.surfaceBg
                            : (isNextUpcoming ? const Color(0xFFDC2626) : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isCompleted
                              ? theme.cardBorder
                              : (isNextUpcoming ? const Color(0xFF991B1B) : const Color(0xFFF59E0B)),
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
                            color: isCompleted
                                ? theme.textPrimary
                                : (isNextUpcoming ? Colors.white : const Color(0xFFB45309)),
                          ),
                        ),
                      ),
                    ),

                    // Away Team
                    Expanded(
                      child: Row(
                        children: [
                          _buildTeamLogo(f.awayTeam, f.awayLogoUrl, size: 20),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              f.awayTeam,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: (isAwayMatched || isNextUpcoming) ? FontWeight.w900 : FontWeight.w600,
                                color: isNextUpcoming
                                    ? const Color(0xFF991B1B)
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFFDCFCE7)
                            : (isNextUpcoming ? const Color(0xFFDC2626) : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        isNextUpcoming ? 'UPCOMING' : f.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? const Color(0xFF15803D)
                              : (isNextUpcoming ? Colors.white : const Color(0xFFB45309)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final TextAlign align;
  final bool isHighlight;
  final Color accentColor;
  final Color textColor;

  const _HeaderCell(
    this.text, {
    this.align = TextAlign.center,
    this.isHighlight = false,
    required this.accentColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: isHighlight ? accentColor : textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
