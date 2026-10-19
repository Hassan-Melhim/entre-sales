import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/dates.dart';
import '../core/money.dart';
import '../models/artist_statement.dart';
import '../models/breakdown.dart';
import '../models/calendar_session.dart';
import '../models/monthly_report.dart';
import '../models/order_status.dart';
import '../models/sale_order.dart';
import '../models/store_info.dart';
import 'file_output_service.dart';

/// Builds PDF receipts, invoices and reports.
/// Use [deliver] to hand the result to the user (share sheet / folder).
class PdfService {
  PdfService._();

  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> _loadTheme() async {
    if (_theme != null) return _theme!;
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Lato-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Lato-Bold.ttf'));
    return _theme = pw.ThemeData.withFont(base: regular, bold: bold);
  }

  static Future<void> deliver(Uint8List bytes, String filename) => FileOutputService.deliverBytes(filename, bytes);

  // ------------------------------------------------------------ Building blocks

  static const _muted = PdfColors.grey700;
  static const _line = PdfColors.grey400;

  static pw.Widget _header(StoreInfo store, String title, String subtitle) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(store.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    if (store.address != null) pw.Text(store.address!, style: const pw.TextStyle(color: _muted)),
                    if (store.taxId != null) pw.Text('NIF: ${store.taxId}', style: const pw.TextStyle(color: _muted)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(subtitle, style: const pw.TextStyle(color: _muted)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: _line),
          pw.SizedBox(height: 8),
        ],
      );

  static pw.Widget _table(List<String> headers, List<List<String>> rows, {Set<int> rightAligned = const {}}) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      cellAlignments: {for (final i in rightAligned) i: pw.Alignment.centerRight},
      headerAlignments: {for (final i in rightAligned) i: pw.Alignment.centerRight},
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    );
  }

  static pw.Widget _totals(List<(String, String)> rows, {int boldLast = 1}) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Container(
          width: 260,
          child: pw.Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(rows[i].$1,
                            style: i >= rows.length - boldLast ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
                      ),
                      pw.Text(rows[i].$2,
                          style: i >= rows.length - boldLast ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  static pw.Widget _footer(pw.Context ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount} · Generated ${formatDateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
      );

  // ------------------------------------------------------------------ Receipt

  static Future<Uint8List> receipt(SaleOrder o, StoreInfo store) async {
    final doc = pw.Document(theme: await _loadTheme());
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(store, 'Receipt ${o.number}', formatDateTime(o.createdAt)),
          _table(
            ['Item', 'Qty', 'Unit', 'Tax', 'Total'],
            [
              for (final i in o.items)
                [
                  '${i.productName}\n${i.variantLabel}',
                  '${i.quantity}',
                  formatCents(i.unitBaseCents),
                  formatPercent(i.taxPercent),
                  formatCents(i.totalCents),
                ],
            ],
            rightAligned: {1, 2, 3, 4},
          ),
          pw.SizedBox(height: 12),
          _totals([
            ('Subtotal before tax', formatCents(o.subtotalCents + o.discountCents)),
            if (o.discountCents > 0) ('${o.discountName} (${formatPercent(o.discountPercent)})', '−${formatCents(o.discountCents)}'),
            ('Tax', formatCents(o.taxCents)),
            ('Total (${o.paymentMethod})', formatCents(o.totalCents)),
          ]),
          if (o.status != OrderStatus.completed) ...[
            pw.SizedBox(height: 8),
            pw.Text('Status: ${o.status.label}', style: const pw.TextStyle(color: PdfColors.red800)),
          ],
          pw.Spacer(),
          pw.Center(child: pw.Text('Thank you for supporting independent artists', style: const pw.TextStyle(color: _muted))),
        ],
      ),
    ));
    return doc.save();
  }

  // --------------------------------------------------------- Artist invoice

  static Future<Uint8List> artistStatement(ArtistStatement s, StoreInfo store) async {
    final doc = pw.Document(theme: await _loadTheme());
    final a = s.artist;
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: _footer,
      build: (ctx) => [
        _header(store, 'Artist settlement', s.range.label),
        pw.Text(a.name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        if (a.legalName != null) pw.Text('Legal name: ${a.legalName}'),
        if (a.taxId != null) pw.Text('Tax ID: ${a.taxId}'),
        if (a.address != null) pw.Text(a.address!),
        if (a.iban != null) pw.Text('IBAN: ${a.iban}${a.bankName != null ? ' (${a.bankName})' : ''}'),
        pw.SizedBox(height: 16),
        pw.Text('Products sold', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (s.sales.isEmpty)
          pw.Text('No sales in this period.', style: const pw.TextStyle(color: _muted))
        else
          _table(
            ['Date', 'Order', 'Product', 'Qty', 'Price before tax', 'Commission', 'Artist share'],
            [
              for (final l in s.sales)
                [
                  formatDate(l.date),
                  l.orderNumber,
                  '${l.productName} · ${l.variantLabel}',
                  '${l.quantity}',
                  formatCents(l.baseCents),
                  formatPercent(l.commissionPercent),
                  formatCents(l.payoutCents),
                ],
            ],
            rightAligned: {3, 4, 5, 6},
          ),
        if (s.refunds.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Refunds in this period', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _table(
            ['Date', 'Order', 'Product', 'Qty', 'Price before tax', 'Artist share'],
            [
              for (final l in s.refunds)
                [
                  formatDate(l.date),
                  l.orderNumber,
                  '${l.productName} · ${l.variantLabel}',
                  '−${l.quantity}',
                  '−${formatCents(l.baseCents)}',
                  '−${formatCents(l.payoutCents)}',
                ],
            ],
            rightAligned: {3, 4, 5},
          ),
        ],
        pw.SizedBox(height: 16),
        _totals([
          ('Sales before tax', formatCents(s.salesBaseCents)),
          ('Store commission', '−${formatCents(s.commissionCents)}'),
          ('Artist share', formatCents(s.payoutCents)),
          if (a.isSpainResident)
            ('Spain resident tax (${formatPercent(s.residentTaxPercent)})',
                '${s.netPayoutCents >= s.payoutCents ? '+' : '−'}${formatCents(s.residentTaxCents)}'),
          ('Amount to pay', formatCents(s.netPayoutCents)),
        ]),
      ],
    ));
    return doc.save();
  }

  // ------------------------------------------------------- Workshop session

  static Future<Uint8List> sessionReport(CalendarSession session, List<SaleOrder> orders, StoreInfo store) async {
    final doc = pw.Document(theme: await _loadTheme());
    final items = [for (final o in orders) for (final i in o.items) (o, i)];
    final total = orders.fold(0, (s, o) => s + o.totalCents);
    final tax = orders.fold(0, (s, o) => s + o.taxCents);
    final byMethod = <String, int>{};
    for (final o in orders) {
      byMethod[o.paymentMethod] = (byMethod[o.paymentMethod] ?? 0) + o.totalCents;
    }
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: _footer,
      build: (ctx) => [
        _header(store, 'Session sales', session.title),
        pw.Text('${formatDateTime(session.start)} – ${formatDateTime(session.end)}'),
        pw.Text('${orders.length} orders · ${items.fold(0, (s, x) => s + x.$2.quantity)} items'),
        pw.SizedBox(height: 12),
        _table(
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
        ),
        pw.SizedBox(height: 12),
        _totals([
          for (final e in byMethod.entries) (e.key, formatCents(e.value)),
          ('Tax included', formatCents(tax)),
          ('Session total', formatCents(total)),
        ]),
      ],
    ));
    return doc.save();
  }

  // ---------------------------------------------------------- Monthly report

  static Future<Uint8List> monthlyReport(MonthlyReport r, StoreInfo store) async {
    final doc = pw.Document(theme: await _loadTheme());

    pw.Widget section(String title) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
          child: pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        );

    List<List<String>> breakdownRows(List<Breakdown> list) => [
          for (final b in list) [b.label, '${b.units}', formatCents(b.revenueCents), formatCents(b.profitCents)],
        ];

    final maxHour = r.revenueByHour.fold(0, (m, v) => v > m ? v : m);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: _footer,
      build: (ctx) => [
        _header(store, 'Monthly report', formatMonth(r.range.start)),
        _totals([
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
        section('Sales by category'),
        _table(['Category', 'Units', 'Revenue', 'Profit'], breakdownRows(r.byCategory), rightAligned: {1, 2, 3}),
        section('Sales by artist'),
        _table(['Artist', 'Units', 'Revenue', 'Profit'], breakdownRows(r.byArtist), rightAligned: {1, 2, 3}),
        section('Sales by artist gender'),
        _table(['Gender', 'Units', 'Revenue', 'Profit'], breakdownRows(r.byGender), rightAligned: {1, 2, 3}),
        section('Best-selling products'),
        _table(['Product', 'Units', 'Revenue', 'Profit'], breakdownRows(r.topProducts), rightAligned: {1, 2, 3}),
        section('Sales by hour of day'),
        for (var h = 0; h < 24; h++)
          if (r.ordersByHour[h] > 0)
            pw.Row(children: [
              pw.SizedBox(width: 40, child: pw.Text('${h.toString().padLeft(2, '0')}:00')),
              pw.Container(
                width: maxHour == 0 ? 0.0 : 300 * r.revenueByHour[h] / maxHour,
                height: 8,
                color: PdfColors.brown300,
              ),
              pw.SizedBox(width: 6),
              pw.Text('${formatCents(r.revenueByHour[h])} · ${r.ordersByHour[h]} orders',
                  style: const pw.TextStyle(fontSize: 9)),
            ]),
        section('Turnover and shelf life'),
        pw.Text('Average days from arrival to sale: ${r.avgDaysToSell?.toStringAsFixed(1) ?? '—'}'),
        pw.SizedBox(height: 6),
        _table(
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
        section('Fastest sellers (days on display before sale)'),
        _table(['Product', 'Artist', 'Days', 'Units'],
            [for (final s in r.fastestSellers) [s.productName, s.artistName, s.days.toStringAsFixed(1), '${s.units}']],
            rightAligned: {2, 3}),
        section('Longest on display (still unsold)'),
        _table(['Product', 'Artist', 'Days', 'Units'],
            [for (final s in r.longestOnDisplay) [s.productName, s.artistName, s.days.toStringAsFixed(0), '${s.units}']],
            rightAligned: {2, 3}),
      ],
    ));
    return doc.save();
  }
}
