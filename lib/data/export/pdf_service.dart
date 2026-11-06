import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/assets.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/models/artist_statement.dart';
import '../../domain/models/breakdown.dart';
import '../../domain/models/calendar_session.dart';
import '../../domain/models/date_range.dart';
import '../../domain/models/order_status.dart';
import '../../domain/models/sale_order.dart';
import '../../domain/models/sales_report.dart';
import '../../domain/models/statement_line.dart';
import '../../domain/models/store_info.dart';
import '../../domain/models/store_logos.dart';
import '../../domain/pricing.dart';
import '../../domain/models/timeline_unit.dart';
import 'export_file.dart';

/// Builds PDF receipts, artist settlements, session invoices and reports.
/// Returns files; delivering them (download / share) is up to the caller.
class PdfService {
  PdfService._();

  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> _loadTheme() async {
    if (_theme != null) return _theme!;
    final regular = pw.Font.ttf(await rootBundle.load(AppAssets.fontRegular));
    final bold = pw.Font.ttf(await rootBundle.load(AppAssets.fontBold));
    return _theme = pw.ThemeData.withFont(base: regular, bold: bold);
  }

  static Future<ExportFile> _save(pw.Document doc, String name) async =>
      ExportFile(name, await doc.save(), ExportFile.pdf);

  static String safeName(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');

  // ------------------------------------------------------------ Building blocks
  //
  // The look of the store's invoice template: a bold title on the left, the
  // store's address in the middle, who it's for on the right; tables as
  // rounded grey bars; the horizontal logo at the foot of each page.

  static const _muted = PdfColors.grey700;
  static final _barHeader = PdfColor.fromHex('#E8E8E8');
  static final _barRow = PdfColor.fromHex('#F3F3F3');
  static final _barRowAlt = PdfColor.fromHex('#F8F8F8');
  static const _pageMargin = pw.EdgeInsets.fromLTRB(36, 32, 36, 24);
  static const _barRadius = 12.0;
  static const _rowRadius = 9.0;

  /// A logo, or nothing if it's missing or can't be drawn.
  static pw.Widget? _logo(LogoImage? logo, double height) {
    if (logo == null) return null;
    try {
      return logo.isSvg
          ? pw.SvgImage(svg: utf8.decode(logo.bytes, allowMalformed: true), height: height)
          : pw.Image(pw.MemoryImage(logo.bytes), height: height, fit: pw.BoxFit.contain);
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _storeBlock(StoreInfo store, {double fontSize = 11}) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(store.name, style: pw.TextStyle(fontSize: fontSize + 1, fontWeight: pw.FontWeight.bold)),
          if (store.address != null) pw.Text(store.address!, style: pw.TextStyle(fontSize: fontSize)),
          if (store.taxId != null) pw.Text('NIF ${store.taxId}', style: pw.TextStyle(fontSize: fontSize)),
        ],
      );

  /// Title (with the three kisses under it) · store address · [right] block,
  /// and the corner logo.
  static pw.Widget _header(StoreInfo store, String title, String subtitle, {pw.Widget? right}) {
    final kisses = _logo(store.logos.kisses, 22);
    final corner = _logo(store.logos.corner, 44);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 18),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, lineSpacing: -2)),
                pw.Text(subtitle, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                if (kisses != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 8, left: 90),
                    child: kisses,
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(flex: 4, child: _storeBlock(store)),
          pw.SizedBox(width: 12),
          pw.Expanded(flex: 4, child: right ?? pw.SizedBox()),
          if (corner != null) ...[pw.SizedBox(width: 12), corner],
        ],
      ),
    );
  }

  /// "Name" in bold over plain lines, for the right of the header.
  static pw.Widget _headerBlock(String bold, List<String> lines, {List<String> small = const []}) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(bold, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          for (final l in lines) pw.Text(l, style: const pw.TextStyle(fontSize: 11)),
          if (small.isNotEmpty) pw.SizedBox(height: 4),
          for (final l in small) pw.Text(l, style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ],
      );

  static pw.Widget _section(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
        child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      );

  /// A cell: the first line as is, any further lines small and grey.
  static pw.Widget _cell(String text, {bool right = false, double fontSize = 9.5}) {
    final lines = text.split('\n');
    final align = right ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start;
    return pw.Column(
      crossAxisAlignment: align,
      children: [
        pw.Text(lines.first, style: pw.TextStyle(fontSize: fontSize), textAlign: right ? pw.TextAlign.right : null),
        for (final l in lines.skip(1))
          pw.Text(l, style: const pw.TextStyle(fontSize: 7.5, color: _muted), textAlign: right ? pw.TextAlign.right : null),
      ],
    );
  }

  /// A table as rounded bars: a darker header bar, then one bar per row.
  /// Returned as separate widgets so long tables continue on the next page.
  /// [minRows] adds empty bars, like the printed template.
  static List<pw.Widget> _table(
    List<String> headers,
    List<List<String>> rows, {
    Set<int> rightAligned = const {},
    List<int>? flex,
    int minRows = 0,
    double headerFontSize = 10.5,
  }) {
    final f = flex ?? [for (var i = 0; i < headers.length; i++) i == 0 ? 3 : 2];
    pw.Widget line(List<pw.Widget> cells) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) pw.SizedBox(width: 8),
              pw.Expanded(flex: f[i], child: cells[i]),
            ],
          ],
        );
    return [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: pw.BoxDecoration(color: _barHeader, borderRadius: pw.BorderRadius.circular(_barRadius)),
        child: line([
          for (var i = 0; i < headers.length; i++)
            pw.Text(headers[i],
                style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold),
                textAlign: rightAligned.contains(i) ? pw.TextAlign.right : null),
        ]),
      ),
      for (var r = 0; r < rows.length || r < minRows; r++)
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 3),
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          constraints: const pw.BoxConstraints(minHeight: 22),
          decoration: pw.BoxDecoration(
              color: r.isEven ? _barRow : _barRowAlt, borderRadius: pw.BorderRadius.circular(_rowRadius)),
          child: r < rows.length
              ? line([for (var i = 0; i < rows[r].length; i++) _cell(rows[r][i], right: rightAligned.contains(i))])
              : pw.SizedBox(width: double.infinity),
        ),
    ];
  }

  /// Total lines under a table: plain ones in a light bar, the last in bold.
  static List<pw.Widget> _totals(List<(String, String)> rows, {int boldLast = 1}) => [
        pw.SizedBox(height: 14),
        for (var i = 0; i < rows.length; i++)
          if (i >= rows.length - boldLast)
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(14, 6, 14, 2),
              child: pw.Row(children: [
                pw.Expanded(
                    child: pw.Text(rows[i].$1, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
                pw.Text(rows[i].$2, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ]),
            )
          else
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 3),
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: pw.BoxDecoration(color: _barRow, borderRadius: pw.BorderRadius.circular(_rowRadius)),
              child: pw.Row(children: [
                pw.Expanded(child: pw.Text(rows[i].$1, style: const pw.TextStyle(fontSize: 11))),
                pw.Text(rows[i].$2, style: const pw.TextStyle(fontSize: 11)),
              ]),
            ),
      ];

  /// The horizontal logo centred at the foot of each page, page numbers under it.
  static pw.Widget Function(pw.Context) _footer(StoreInfo store) => (ctx) => pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (_logo(store.logos.footer, 30) case final logo?) pw.Center(child: logo),
          pw.SizedBox(height: 6),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: _muted)),
          ),
        ],
      );

  /// "July" for a whole calendar month, else the range as written.
  static String _periodShort(DateRange r) {
    final wholeMonth = r.start.day == 1 && r.end == DateTime(r.start.year, r.start.month + 1);
    return wholeMonth ? DateFormat('MMMM').format(r.start) : r.label;
  }

  static String _periodLong(DateRange r) {
    final wholeMonth = r.start.day == 1 && r.end == DateTime(r.start.year, r.start.month + 1);
    return wholeMonth ? 'Sales in ${DateFormat('MMMM y').format(r.start)}' : 'Sales ${r.label}';
  }

  static String _neg(String s) => '−$s';

  // ------------------------------------------------------------------ Receipt

  static Future<ExportFile> receipt(SaleOrder o, StoreInfo store) async {
    final doc = pw.Document(theme: await _loadTheme());
    final corner = _logo(store.logos.corner, 38);
    final kisses = _logo(store.logos.kisses, 18);
    final footerLogo = _logo(store.logos.footer, 26);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.fromLTRB(26, 26, 26, 20),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Receipt', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${o.number} · ${formatDateTime(o.createdAt)}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              if (corner != null) corner,
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(child: _storeBlock(store, fontSize: 9)),
              if (kisses != null) kisses,
            ],
          ),
          pw.SizedBox(height: 14),
          ..._table(
            ['Item', 'Qty', 'Price\n(+IVA)', 'Total'],
            [
              for (final i in o.items)
                [
                  i.variantLabel == 'Standard' ? i.productName : '${i.productName}\n${i.variantLabel}',
                  '${i.quantity}',
                  formatCents(Pricing.unitPriceWithTax(i.unitBaseCents, i.taxPercent)),
                  formatCents(i.totalCents),
                ],
            ],
            rightAligned: {1, 2, 3},
            flex: const [5, 1, 2, 2],
            headerFontSize: 9,
          ),
          ..._totals([
            ('Subtotal sin IVA', formatCents(o.subtotalCents + o.discountCents)),
            if (o.discountCents > 0)
              ('${o.discountName} (${formatPercent(o.discountPercent)})', _neg(formatCents(o.discountCents))),
            ('IVA', formatCents(o.taxCents)),
            ('Total · ${o.paymentMethod}', formatCents(o.totalCents)),
          ]),
          if (o.status != OrderStatus.completed) ...[
            pw.SizedBox(height: 8),
            pw.Text('Status: ${o.status.label}', style: const pw.TextStyle(color: PdfColors.red800)),
          ],
          pw.Spacer(),
          pw.Center(
            child: pw.Text('Thank you for supporting independent artists',
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ),
          if (footerLogo != null) ...[pw.SizedBox(height: 8), pw.Center(child: footerLogo)],
        ],
      ),
    ));
    return _save(doc, 'receipt_${o.id}.pdf');
  }

  // --------------------------------------------------------- Artist invoices

  /// One artist's statement, laid out like the store's "Items Sold" template.
  /// The amounts are the app's usual calculation; only the look follows it.
  static List<pw.Widget> _statementPage(ArtistStatement s, StoreInfo store) {
    final a = s.artist;
    String describe(StatementLine l, {bool refund = false}) {
      final name = l.variantLabel == 'Standard' ? l.productName : '${l.productName} · ${l.variantLabel}';
      return '${refund ? 'Refund: ' : ''}$name\n${formatDate(l.date)} · ${l.orderNumber}';
    }

    return [
      _header(
        store,
        'Items Sold',
        _periodShort(s.range),
        right: _headerBlock(a.name, [_periodLong(s.range)], small: [
          if (a.legalName != null && a.legalName != a.name) a.legalName!,
          if (a.taxId != null) 'NIF ${a.taxId}',
          if (a.iban != null) 'IBAN ${a.iban}${a.bankName != null ? ' · ${a.bankName}' : ''}',
        ]),
      ),
      ..._table(
        ['Title/Description', 'Quantity', 'Full Price\n(+IVA)', '${store.name}\nShare', 'Artist\nShare'],
        [
          for (final l in s.sales)
            [
              describe(l),
              '${l.quantity}',
              formatCents(l.fullPriceCents),
              formatCents(l.commissionCents),
              formatCents(l.payoutCents),
            ],
          for (final l in s.refunds)
            [
              describe(l, refund: true),
              _neg('${l.quantity}'),
              _neg(formatCents(l.fullPriceCents)),
              _neg(formatCents(l.commissionCents)),
              _neg(formatCents(l.payoutCents)),
            ],
          if (s.isEmpty) ['No sales in this period', '', '', '', ''],
        ],
        flex: const [5, 2, 2, 2, 2],
        minRows: 8,
      ),
      ..._totals([
        ('Total for Invoice sin IVA:', formatCents(s.payoutCents)),
        if (a.isSpainResident)
          (
            'Spain resident tax (${formatPercent(s.residentTaxPercent)}):',
            '${s.netPayoutCents >= s.payoutCents ? '+' : '−'}${formatCents(s.residentTaxCents)}',
          ),
        ('Total for Invoice / Para Factura:', formatCents(s.netPayoutCents)),
      ]),
    ];
  }

  static Future<ExportFile> artistStatement(ArtistStatement s, StoreInfo store) async {
    final doc = pw.Document(theme: await _loadTheme());
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: _pageMargin,
      footer: _footer(store),
      build: (ctx) => _statementPage(s, store),
    ));
    return _save(doc, 'settlement_${safeName(s.artist.name)}_${fileStamp(s.range.start)}.pdf');
  }

  /// All artists for a period: a summary table, and with [detailed] each
  /// artist's statement on its own page.
  static Future<ExportFile> allStatements(
    List<ArtistStatement> statements,
    DateRange range,
    String fileLabel,
    StoreInfo store, {
    required bool detailed,
  }) async {
    final doc = pw.Document(theme: await _loadTheme());
    final total = statements.fold<int>(0, (s, x) => s + x.netPayoutCents);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: _pageMargin,
      footer: _footer(store),
      build: (ctx) => [
        _header(store, 'Artist Payouts', _periodShort(range),
            right: _headerBlock('${statements.length} artists', [_periodLong(range)])),
        ..._table(
          ['Artist', 'Items', 'Full Price\n(+IVA)', '${store.name}\nShare', 'Artist\nShare', 'Resident\ntax', 'To pay'],
          [
            for (final s in statements)
              [
                s.artist.name,
                '${s.soldUnits}',
                formatCents(s.fullPriceCents),
                formatCents(s.commissionCents),
                formatCents(s.payoutCents),
                s.artist.isSpainResident ? formatCents(s.residentTaxCents) : '—',
                formatCents(s.netPayoutCents),
              ],
          ],
          rightAligned: {1, 2, 3, 4, 5, 6},
          flex: const [4, 1, 2, 2, 2, 2, 2],
          headerFontSize: 9.5,
        ),
        ..._totals([('Total to pay (${statements.length} artists):', formatCents(total))]),
      ],
    ));
    if (detailed) {
      for (final s in statements) {
        doc.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: _pageMargin,
          footer: _footer(store),
          build: (ctx) => _statementPage(s, store),
        ));
      }
    }
    return _save(doc, 'artist_payouts_${detailed ? 'detailed' : 'summary'}_$fileLabel.pdf');
  }

  // ------------------------------------------------------- Workshop session

  static Future<ExportFile> sessionReport(CalendarSession session, List<SaleOrder> orders, StoreInfo store) async {
    final doc = pw.Document(theme: await _loadTheme());
    final items = [for (final o in orders) for (final i in o.items) (o, i)];
    final total = orders.fold<int>(0, (s, o) => s + o.totalCents);
    final tax = orders.fold<int>(0, (s, o) => s + o.taxCents);
    final byMethod = <String, int>{};
    for (final o in orders) {
      byMethod[o.paymentMethod] = (byMethod[o.paymentMethod] ?? 0) + o.totalCents;
    }
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: _pageMargin,
      footer: _footer(store),
      build: (ctx) => [
        _header(store, 'Session Sales', session.title),
        pw.Text('${formatDateTime(session.start)} – ${formatDateTime(session.end)}'),
        pw.Text('${orders.length} orders · ${items.fold<int>(0, (s, x) => s + x.$2.quantity)} items'),
        pw.SizedBox(height: 12),
        ..._table(
          ['Time', 'Order', 'Product', 'Category', 'Qty', 'Tax', 'Total', 'Status'],
          [
            for (final (o, i) in items)
              [
                formatTime(o.createdAt),
                o.number,
                '${i.productName} · ${i.variantLabel}',
                i.categoryName,
                '${i.quantity}',
                formatCents(i.taxCents),
                formatCents(i.totalCents),
                i.refundedQuantity > 0 ? '${i.refundedQuantity} refunded' : '',
              ],
          ],
          rightAligned: {4, 5, 6},
          flex: const [2, 2, 5, 3, 1, 2, 2, 3],
          headerFontSize: 9,
        ),
        ..._totals([
          for (final e in byMethod.entries) (e.key, formatCents(e.value)),
          ('Tax included', formatCents(tax)),
          ('Session total', formatCents(total)),
        ]),
      ],
    ));
    return _save(doc, 'session_${fileStamp(session.start)}.pdf');
  }

  // ------------------------------------------------------------ Sales report

  static Future<ExportFile> salesReport(SalesReport r, StoreInfo store) async {
    final doc = pw.Document(theme: await _loadTheme());

    List<List<String>> breakdownRows(List<Breakdown> list) => [
          for (final b in list) [b.label, '${b.units}', formatCents(b.revenueCents), formatCents(b.profitCents)],
        ];

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: _pageMargin,
      footer: _footer(store),
      build: (ctx) => [
        _header(store, 'Sales Report', r.period.label),
        ..._totals([
          ('Orders', '${r.orderCount}'),
          ('Units sold (net of refunds)', '${r.unitsSold}'),
          ('Revenue incl. tax', formatCents(r.revenueCents)),
          ('VAT collected', formatCents(r.vatCents)),
          ('Discounts given', formatCents(r.discountCents)),
          ('Refunds', formatCents(r.refundsCents)),
          ('Artist payouts', formatCents(r.artistPayoutCents)),
          ('Spain resident artist tax', formatCents(r.artistResidentTaxCents)),
          ('Store profit', formatCents(r.profitCents)),
        ]),
        _section('Revenue ${r.period.timelineUnit.label}'),
        ..._table(
          ['Period', 'Orders', 'Revenue'],
          [
            for (final p in r.timeline)
              if (p.orders > 0 || r.period.timelineUnit != TimelineUnit.day)
                [p.longLabel, '${p.orders}', formatCents(p.revenueCents)],
          ],
          rightAligned: {1, 2},
        ),
        _section('Sales by category'),
        ..._table(['Category', 'Units', 'Revenue', 'Profit'], breakdownRows(r.byCategory), rightAligned: {1, 2, 3}),
        _section('Sales by artist'),
        ..._table(['Artist', 'Units', 'Revenue', 'Profit'], breakdownRows(r.byArtist), rightAligned: {1, 2, 3}),
        _section('Sales by artist gender'),
        ..._table(['Gender', 'Units', 'Revenue', 'Profit'], breakdownRows(r.byGender), rightAligned: {1, 2, 3}),
        _section('Best-selling products'),
        ..._table(['Product', 'Units', 'Revenue', 'Profit'], breakdownRows(r.topProducts), rightAligned: {1, 2, 3}),
        if (r.period.timelineUnit != TimelineUnit.hour) ...[
          _section('Sales by hour of day'),
          ..._table(
            ['Hour', 'Orders', 'Revenue'],
            [
              for (var h = 0; h < 24; h++)
                if (r.ordersByHour[h] > 0)
                  ['${h.toString().padLeft(2, '0')}:00', '${r.ordersByHour[h]}', formatCents(r.revenueByHour[h])],
            ],
            rightAligned: {1, 2},
          ),
        ],
        _section('Turnover and shelf life'),
        pw.Text('Average days from arrival to sale: ${r.avgDaysToSell?.toStringAsFixed(1) ?? '—'}'),
        pw.SizedBox(height: 6),
        ..._table(
          ['Category', 'Sold', 'In stock now', 'Sell-through', 'Avg days to sell'],
          [
            for (final t in r.turnover)
              [
                t.category,
                '${t.soldUnits}',
                '${t.inStockUnits}',
                '${(t.sellThrough * 100).toStringAsFixed(0)}%',
                t.avgDaysToSell?.toStringAsFixed(1) ?? '—',
              ],
          ],
          rightAligned: {1, 2, 3, 4},
        ),
        _section('Fastest sellers (days on display before sale)'),
        ..._table(['Product', 'Artist', 'Days', 'Units'],
            [for (final s in r.fastestSellers) [s.productName, s.artistName, s.days.toStringAsFixed(1), '${s.units}']],
            rightAligned: {2, 3}),
        _section('Longest on display (still unsold)'),
        ..._table(['Product', 'Artist', 'Days', 'Units'],
            [for (final s in r.longestOnDisplay) [s.productName, s.artistName, s.days.toStringAsFixed(0), '${s.units}']],
            rightAligned: {2, 3}),
      ],
    ));
    return _save(doc, 'report_${r.period.fileLabel}.pdf');
  }
}
