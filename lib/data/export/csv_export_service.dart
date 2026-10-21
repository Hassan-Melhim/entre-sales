import 'dart:convert';
import 'dart:typed_data';

import '../../core/dates.dart';
import '../../domain/models/artist_statement.dart';
import '../../domain/models/date_range.dart';
import '../../domain/models/product.dart';
import '../../domain/models/sale_order.dart';
import '../../domain/models/sales_report.dart';
import 'export_file.dart';

/// CSV exports of inventory, sales, artist payouts and reports.
///
/// Amounts are plain numbers with a dot (12.50) so spreadsheets read them as
/// numbers. Files are UTF-8 with a BOM so Excel shows accents correctly.
class CsvExportService {
  CsvExportService._();

  static String _money(int cents) => (cents / 100).toStringAsFixed(2);

  static String _cell(Object? v) {
    final s = v?.toString() ?? '';
    if (s.contains(RegExp(r'[",\n\r]'))) return '"${s.replaceAll('"', '""')}"';
    return s;
  }

  static String toCsv(List<List<Object?>> rows) => rows.map((r) => r.map(_cell).join(',')).join('\r\n');

  static ExportFile _file(String name, List<List<Object?>> rows) =>
      ExportFile(name, Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(toCsv(rows))]), ExportFile.csv);

  static String _rangeLabel(DateRange r) =>
      r.isSingleDay ? fileStamp(r.start) : '${fileStamp(r.start)}-${fileStamp(r.lastDay)}';

  // ---------------------------------------------------------------- Exports

  static ExportFile inventory(List<Product> products) => _file('inventory_${fileStamp(DateTime.now())}.csv', [
        [
          'Product', 'Artist', 'Category', 'Variant', 'In stock', 'Price before tax', 'Tax %',
          'Price incl. tax', 'Commission %', 'Custom commission', 'Date of arrival', 'Status',
        ],
        for (final p in products)
          for (final v in p.variants)
            [
              p.name,
              p.artistName,
              p.categoryName,
              v.label,
              v.quantity,
              _money(p.baseCentsFor(v)),
              p.taxPercent,
              _money(p.priceWithTaxFor(v)),
              p.commissionPercent,
              p.hasCustomCommission ? 'yes' : '',
              formatDate(v.dateOfArrival),
              v.quantity == 0 ? 'Out of stock' : 'In stock',
            ],
      ]);

  static ExportFile sales(List<SaleOrder> orders, DateRange range) => _file('sales_${_rangeLabel(range)}.csv', [
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
              formatTime(o.createdAt),
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
      ]);

  /// One row per artist.
  static ExportFile statementsSummary(List<ArtistStatement> statements, DateRange range) =>
      _file('artist_payouts_summary_${_rangeLabel(range)}.csv', [
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
      ]);

  /// One row per sold (or refunded) line, grouped by artist — the same
  /// detail shown when opening an artist in the Invoices screen.
  static ExportFile statementsDetailed(List<ArtistStatement> statements, DateRange range) =>
      _file('artist_payouts_detailed_${_rangeLabel(range)}.csv', [
        [
          'Artist', 'Type', 'Date', 'Order', 'Product', 'Variant', 'Quantity', 'Price before tax', 'Commission %',
          'Store commission', 'Artist share',
        ],
        for (final s in statements) ...[
          for (final l in s.sales)
            [
              s.artist.name, 'Sale', formatDate(l.date), l.orderNumber, l.productName, l.variantLabel, l.quantity,
              _money(l.baseCents), l.commissionPercent, _money(l.commissionCents), _money(l.payoutCents),
            ],
          for (final l in s.refunds)
            [
              s.artist.name, 'Refund', formatDate(l.date), l.orderNumber, l.productName, l.variantLabel, -l.quantity,
              _money(-l.baseCents), l.commissionPercent, _money(-l.commissionCents), _money(-l.payoutCents),
            ],
          [
            s.artist.name, 'Total', '', '', '', '', s.soldUnits, _money(s.salesBaseCents), '',
            _money(s.commissionCents), _money(s.payoutCents),
          ],
          if (s.artist.isSpainResident)
            [s.artist.name, 'Spain resident tax ${s.residentTaxPercent}%', '', '', '', '', '', '', '', '',
              _money(s.residentTaxCents)],
          [s.artist.name, 'Amount to pay', '', '', '', '', '', '', '', '', _money(s.netPayoutCents)],
        ],
      ]);

  static ExportFile salesReport(SalesReport r) => _file('report_${r.period.fileLabel}.csv', [
        ['Sales report', r.period.label],
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
        ['Revenue ${r.period.timelineUnit.label}', 'Orders', 'Revenue'],
        for (final p in r.timeline) [p.longLabel, p.orders, _money(p.revenueCents)],
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
          if (r.ordersByHour[h] > 0)
            ['${h.toString().padLeft(2, '0')}:00', r.ordersByHour[h], _money(r.revenueByHour[h])],
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
      ]);
}
