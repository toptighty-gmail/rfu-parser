import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/player_appearance.dart';
import '../views/booklet_print_view.dart' show loadPdfSoraTheme;
import 'platform_pdf_export.dart';

/// Builds and prints PDFs of the Player Appearances dialog's three views.
class PlayerStatsPdf {
  PlayerStatsPdf._();

  static const _headerFill = PdfColor.fromInt(0xFFE8E8E8);
  static const _muted = PdfColors.grey700;
  static const _footnote =
      'From RFU electronic match cards. Bench = named as a replacement; lineups '
      'don\'t show whether they came on. T C D P Y R = tries, conversions, drop '
      'goals, penalties, yellow and red cards, as listed in each match\'s key events.';

  // --- Public entry points ------------------------------------------------

  /// Opens the print dialog (or downloads) for [bytes]; returns when done.
  static Future<void> output(Uint8List bytes, String fileName) async {
    var printed = false;
    try {
      printed = await Printing.layoutPdf(
        name: fileName,
        format: PdfPageFormat.a4,
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      debugPrint('Printing.layoutPdf failed, falling back: $e');
    }
    if (printed) return;
    if (kIsWeb) {
      await openPdfInBrowser(bytes, fileName);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }

  static String fileNameFor(String label) =>
      'RFU_${label.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')}.pdf';

  /// "By player" results: one block per player, most appearances first.
  static Future<Uint8List> playerResults({
    required List<PlayerSeasonAppearance> results,
    required String seasonsLabel,
    required bool multiSeason,
  }) async {
    final byPlayer = <int, List<PlayerSeasonAppearance>>{};
    for (final r in results) {
      byPlayer.putIfAbsent(r.playerId, () => []).add(r);
    }
    int total(List<PlayerSeasonAppearance> rows) =>
        rows.fold(0, (s, r) => s + r.appearances);
    final players = byPlayer.values.toList()
      ..sort((a, b) {
        final t = total(b).compareTo(total(a));
        return t != 0 ? t : a.first.displayName.compareTo(b.first.displayName);
      });

    final rows = <List<String>>[];
    final boldRows = <int>{};
    for (final p in players) {
      p.sort((a, b) {
        final s = b.season.compareTo(a.season);
        return s != 0 ? s : b.appearances.compareTo(a.appearances);
      });
      for (var i = 0; i < p.length; i++) {
        final r = p[i];
        if (i == 0) boldRows.add(rows.length);
        rows.add([
          i == 0 ? r.displayName : '',
          if (multiSeason) _shortSeason(r.season),
          r.teamName,
          '${r.appearances}',
          '${r.starts}',
          '${r.bench}',
          ...r.stats.values.map(_zeroDash),
        ]);
      }
    }

    return _document(
      title: 'Player appearances',
      subtitle: '$seasonsLabel - ${players.length} players',
      body: [
        _table(
          headers: [
            'PLAYER',
            if (multiSeason) 'SEASON',
            'TEAM',
            'APPS',
            'START',
            'BENCH',
            ...ScoringStats.labels,
          ],
          rows: rows,
          leftColumns: multiSeason ? 3 : 2,
          boldRows: boldRows,
        ),
      ],
    );
  }

  /// "By team" results: a squad table per team, most appearances first.
  static Future<Uint8List> teamSquads({
    required List<PlayerSeasonAppearance> results,
    required String seasonsLabel,
    required bool multiSeason,
  }) async {
    final byTeam = <String, Map<int, _SquadLine>>{};
    final latest = <String, ({String season, String name})>{};
    for (final r in results) {
      final key = r.teamId?.toString() ?? r.teamName;
      final cur = latest[key];
      if (cur == null || r.season.compareTo(cur.season) > 0) {
        latest[key] = (season: r.season, name: r.teamName);
      }
      byTeam.putIfAbsent(key, () => {}).putIfAbsent(r.playerId, () => _SquadLine(r)).add(r);
    }
    final teams = byTeam.entries.toList()
      ..sort((a, b) => latest[a.key]!.name.compareTo(latest[b.key]!.name));

    final body = <pw.Widget>[];
    for (final team in teams) {
      final squad = team.value.values.toList()
        ..sort((a, b) {
          final apps = b.appearances.compareTo(a.appearances);
          return apps != 0 ? apps : a.player.displayName.compareTo(b.player.displayName);
        });
      body.add(_sectionHeading(
        '${latest[team.key]!.name}  (${squad.length} players)',
      ));
      body.add(_table(
        headers: [
          'PLAYER',
          if (multiSeason) 'SEASONS',
          'APPS',
          'START',
          'BENCH',
          ...ScoringStats.labels,
        ],
        rows: [
          for (final l in squad)
            [
              l.player.displayName,
              if (multiSeason) '${l.seasons.length}',
              '${l.appearances}',
              '${l.starts}',
              '${l.bench}',
              ...l.stats.values.map(_zeroDash),
            ],
        ],
        leftColumns: 1,
      ));
      body.add(pw.SizedBox(height: 12));
    }

    final label = teams.length == 1 ? latest[teams.first.key]!.name : 'Squads';
    return _document(
      title: '$label - player stats',
      subtitle: seasonsLabel,
      body: body,
    );
  }

  /// One player's totals and match-by-match appearances.
  static Future<Uint8List> playerDetail({
    required PlayerSeasonAppearance player,
    required List<PlayerMatchAppearance> matches,
    required String seasonsLabel,
    required bool multiSeason,
  }) async {
    final starts = matches.where((m) => !m.isSubstitute).length;
    final results = matches.map((m) => m.result).where((r) => r.isNotEmpty).toList();
    String count(String r) => '${results.where((x) => x == r).length}$r';
    final totalStats = ScoringStats.sum(matches.map((m) => m.stats));
    final severalTeams = matches.map((m) => m.teamId ?? m.teamName).toSet().length > 1;

    final summary = [
      '${matches.length} apps',
      '$starts starts',
      '${matches.length - starts} bench',
      if (results.isNotEmpty) '${count('W')} ${count('D')} ${count('L')}',
      if (!totalStats.isEmpty) totalStats.summary,
    ].join('   |   ');

    final body = <pw.Widget>[
      pw.Text(summary, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
    ];

    if (severalTeams || multiSeason || !totalStats.isEmpty) {
      final byTeam = <Object, List<PlayerMatchAppearance>>{};
      for (final m in matches) {
        byTeam.putIfAbsent(m.teamId ?? m.teamName, () => []).add(m);
      }
      final teams = byTeam.values.toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      List<String> totalsRow(String name, List<PlayerMatchAppearance> rows) {
        final s = rows.where((m) => !m.isSubstitute).length;
        return [
          name,
          '${rows.length}',
          '$s',
          '${rows.length - s}',
          ...ScoringStats.sum(rows.map((m) => m.stats)).values.map(_zeroDash),
        ];
      }

      body.add(_sectionHeading('Totals by team'));
      body.add(_table(
        headers: ['TEAM', 'APPS', 'START', 'BENCH', ...ScoringStats.labels],
        rows: [
          for (final rows in teams)
            totalsRow(_latestTeamName(rows), rows),
          if (teams.length > 1) totalsRow('Total', matches),
        ],
        leftColumns: 1,
        boldRows: teams.length > 1 ? {teams.length} : const {},
      ));
      body.add(pw.SizedBox(height: 12));
    }

    final bySeason = <String, List<PlayerMatchAppearance>>{};
    for (final m in matches) {
      bySeason.putIfAbsent(m.season, () => []).add(m);
    }
    final seasons = bySeason.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final season in seasons) {
      final rows = bySeason[season]!
        ..sort((a, b) => (b.matchDate ?? DateTime(0)).compareTo(a.matchDate ?? DateTime(0)));
      body.add(_sectionHeading('Season $season  (${rows.length} apps)'));
      body.add(_table(
        headers: [
          'DATE',
          'OPPONENT',
          if (severalTeams) 'FOR',
          'SCORE',
          'RES',
          'SHIRT',
          'EVENTS',
        ],
        rows: [
          for (final m in rows)
            [
              m.matchDate == null ? '' : DateFormat('EEE d MMM yyyy').format(m.matchDate!),
              '${m.isHome ? 'v' : '@'} ${m.opponent}',
              if (severalTeams) m.teamName,
              m.teamScore != null && m.opponentScore != null
                  ? '${m.teamScore}-${m.opponentScore}'
                  : '',
              m.result,
              m.shirt,
              m.stats.summary,
            ],
        ],
        leftColumns: severalTeams ? 3 : 2,
      ));
      body.add(pw.SizedBox(height: 12));
    }

    return _document(
      title: player.displayName,
      subtitle: seasonsLabel,
      body: body,
    );
  }

  // --- Building blocks ----------------------------------------------------

  static Future<Uint8List> _document({
    required String title,
    required String subtitle,
    required List<pw.Widget> body,
  }) async {
    final doc = pw.Document(theme: await loadPdfSoraTheme());
    final printed = DateFormat('d MMM yyyy').format(DateTime.now());
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: _muted)),
            ],
          ),
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Printed $printed', style: const pw.TextStyle(fontSize: 8, color: _muted)),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
        build: (_) => [
          ...body,
          pw.Text(_footnote, style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _sectionHeading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );

  /// Table whose first [leftColumns] columns are left-aligned text and the
  /// rest centred numbers. Rows in [boldRows] are bold.
  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    required int leftColumns,
    Set<int> boldRows = const {},
  }) {
    pw.Widget cell(String text, int col, {bool header = false, bool bold = false}) {
      final left = col < leftColumns;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: pw.Align(
          alignment: left ? pw.Alignment.centerLeft : pw.Alignment.center,
          child: pw.Text(
            text,
            textAlign: left ? pw.TextAlign.left : pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: header ? 8 : 9,
              fontWeight: header || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: header ? _muted : PdfColors.black,
            ),
          ),
        ),
      );
    }

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
      ),
      columnWidths: {
        for (var i = 0; i < headers.length; i++)
          i: i < leftColumns ? const pw.FlexColumnWidth(3) : const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _headerFill),
          children: [for (var i = 0; i < headers.length; i++) cell(headers[i], i, header: true)],
        ),
        for (var r = 0; r < rows.length; r++)
          pw.TableRow(
            children: [
              for (var i = 0; i < rows[r].length; i++)
                cell(rows[r][i], i, bold: boldRows.contains(r)),
            ],
          ),
      ],
    );
  }

  static String _zeroDash(int v) => v == 0 ? '-' : '$v';

  /// "2025-2026" -> "2025-26"
  static String _shortSeason(String season) {
    final m = RegExp(r'^(\d{4})-\d{2}(\d{2})$').firstMatch(season);
    return m == null ? season : '${m.group(1)}-${m.group(2)}';
  }

  /// A team's name as of its most recent match in [rows].
  static String _latestTeamName(List<PlayerMatchAppearance> rows) {
    var best = rows.first;
    for (final m in rows) {
      if ((m.matchDate ?? DateTime(0)).isAfter(best.matchDate ?? DateTime(0))) best = m;
    }
    return best.teamName;
  }
}

/// One player's totals for one team, summed over the selected seasons.
class _SquadLine {
  final PlayerSeasonAppearance player;
  final Set<String> seasons = {};
  int appearances = 0;
  int starts = 0;
  int bench = 0;
  ScoringStats stats = ScoringStats.zero;

  _SquadLine(this.player);

  void add(PlayerSeasonAppearance row) {
    seasons.add(row.season);
    appearances += row.appearances;
    starts += row.starts;
    bench += row.bench;
    stats += row.stats;
  }
}
