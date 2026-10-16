import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/dates.dart';
import '../data/models.dart';
import '../data/repositories/report_repository.dart';

/// CSV exports. Files are written to a temporary folder and handed to the
/// Android share sheet (save to Drive, email, Files, etc.).
///
/// Amounts are written as plain numbers with a dot (12.50) so spreadsheets
/// read them as numbers.
class ExportService {
  ExportService._();

  static String _money(int cents) => (cents / 100).toStringAsFixed(2);

  static String _cell(Object? v) {
    final s = v?.toString() ?? '';
    if (s.contains(RegExp(r'[",\n\r]'))) return '"${s.replaceAll('"', '""')}"';
    return s;
  }

  static String toCsv(List<List<Object?>> rows) => rows.map((r) => r.map(_cell).join(',')).join('\r\n');

  static Future<File> _write(String fileName, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> shareFile(String fileName, Uint8List bytes, {String? text}) async {
    final file = await _write(fileName, bytes);
    await Share.shareXFiles([XFile(file.path)], text: text);
  }

  /// UTF-8 with BOM so Excel shows accents correctly.
  static Future<void> shareCsv(String fileName, List<List<Object?>> rows) {
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(toCsv(rows))]);
    return shareFile(fileName, bytes);
  }

  static String _stamp(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------- Exports

  static Future<void> shareInventoryCsv(List<Product> products) {
    final rows = <List<Object?>>[
      [
        'Product', 'Artist', 'Category', 'Variant', 'In stock', 'Price before tax', 'Tax %',
        'Price incl. tax', 'Date of arrival', 'Status',
      ],
      for (final prod in products)
        for (final v in prod.variants)
          [
            prod.name,
            prod.artistName,
            prod.categoryName,
            v.label,
            v.quantity,
            _money(prod.baseCentsFor(v)),
            prod.taxPercent,
            _money(prod.priceWithTaxFor(v)),
            formatDate(v.dateOfArrival),
            v.quantity == 0 ? 'Out of stock' : 'In stock',
          ],
    ];
    return shareCsv('inventory_${_stamp(DateTime.now())}.csv', rows);
  }

  static Future<void> shareSalesCsv(List<SaleOrder> orders, DateRange range) {
    final rows = <List<Object?>>[
      [
        'Order', 'Date', 'Time', 'Payment', 'Status', 'Workshop session', 'Discount', 'Product', 'Variant',
        'Category', 'Quantity', 'Refunded qty', 'Unit price before tax', 'Discount amount', 'Base after discount',
        'Tax %', 'Tax', 'Total paid', 'Commission %', 'Artist payout',
      ],
      for (final o in orders.reversed)
        for (final i in o.items)
          [
            o.number,
            formatDate(o.createdAt),
            '${o.createdAt.hour.toString().padLeft(2, '0')}:${o.createdAt.minute.toString().padLeft(2, '0')}',
            o.paymentMethod,
            o.status.label,
            o.calendarEventTitle ?? '',
            o.discountName ?? '',
            i.productName,
            i.variantLabel,
            i.categoryName,
            i.quantity,
            i.refundedQuantity,
            _money(i.unitBaseCents),
            _money(i.discountCents),
            _money(i.baseCents),
            i.taxPercent,
            _money(i.taxCents),
            _money(i.totalCents),
            i.commissionPercent,
            _money(i.artistPayoutCents),
          ],
    ];
    return shareCsv('sales_${_stamp(range.start)}-${_stamp(range.lastDay)}.csv', rows);
  }

  static Future<void> shareStatementsCsv(List<ArtistStatement> statements, DateRange range) {
    final rows = <List<Object?>>[
      [
        'Artist', 'Legal name', 'Tax ID', 'IBAN', 'Bank', 'Units', 'Sales before tax', 'Store commission',
        'Payout', 'Spain resident tax %', 'Spain resident tax', 'Amount to pay',
      ],
      for (final s in statements)
        [
          s.artist.name,
          s.artist.legalName ?? '',
          s.artist.taxId ?? '',
          s.artist.iban ?? '',
          s.artist.bankName ?? '',
          s.soldUnits,
          _money(s.salesBaseCents),
          _money(s.commissionCents),
          _money(s.payoutCents),
          s.residentTaxPercent,
          _money(s.residentTaxCents),
          _money(s.netPayoutCents),
        ],
    ];
    return shareCsv('artist_payouts_${_stamp(range.start)}-${_stamp(range.lastDay)}.csv', rows);
  }

  static Future<void> shareMonthlyReportCsv(MonthlyReport r) {
    final rows = <List<Object?>>[
      ['Monthly report', formatMonth(r.range.start)],
      [],
      ['Summary'],
      ['Orders', r.orderCount],
      ['Units sold (net of refunds)', r.unitsSold],
      ['Units refunded', r.unitsRefunded],
      ['Revenue incl. tax (net of refunds)', _money(r.revenueCents)],
      ['VAT collected', _money(r.vatCents)],
      ['Discounts given', _money(r.discountCents)],
      ['Refunds', _money(r.refundsCents)],
      ['Artist payouts', _money(r.artistPayoutCents)],
      ['Spain resident artist tax', _money(r.artistResidentTaxCents)],
      ['Store profit', _money(r.profitCents)],
      ['Average days to sell', r.avgDaysToSell?.toStringAsFixed(1) ?? ''],
      [],
      ['By category', 'Units', 'Revenue', 'Profit'],
      for (final b in r.byCategory) [b.label, b.units, _money(b.revenueCents), _money(b.profitCents)],
      [],
      ['By artist', 'Units', 'Revenue', 'Profit'],
      for (final b in r.byArtist) [b.label, b.units, _money(b.revenueCents), _money(b.profitCents)],
      [],
      ['By artist gender', 'Units', 'Revenue', 'Profit'],
      for (final b in r.byGender) [b.label, b.units, _money(b.revenueCents), _money(b.profitCents)],
      [],
      ['Products sold', 'Units', 'Revenue', 'Profit'],
      for (final b in r.topProducts) [b.label, b.units, _money(b.revenueCents), _money(b.profitCents)],
      [],
      ['Hour', 'Orders', 'Revenue'],
      for (var h = 0; h < 24; h++)
        if (r.ordersByHour[h] > 0) ['${h.toString().padLeft(2, '0')}:00', r.ordersByHour[h], _money(r.revenueByHour[h])],
      [],
      ['Category turnover', 'Sold', 'In stock now', 'Sell-through %', 'Avg days to sell'],
      for (final t in r.turnover)
        [
          t.category,
          t.soldUnits,
          t.inStockUnits,
          (t.sellThrough * 100).toStringAsFixed(1),
          t.avgDaysToSell?.toStringAsFixed(1) ?? '',
        ],
      [],
      ['Longest on display (unsold)', 'Artist', 'Days', 'Units'],
      for (final s in r.longestOnDisplay) [s.productName, s.artistName, s.days.toStringAsFixed(0), s.units],
    ];
    return shareCsv('report_${r.range.start.year}-${r.range.start.month.toString().padLeft(2, '0')}.csv', rows);
  }
}
