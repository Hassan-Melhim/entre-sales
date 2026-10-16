import 'package:sqflite/sqflite.dart';

import '../../config/business_rules.dart';
import '../../core/dates.dart';
import '../../core/pricing.dart';
import '../models.dart';

// =========================================================== Artist invoices

class StatementSaleLine {
  final DateTime date;
  final String orderNumber;
  final String productName;
  final String variantLabel;
  final int quantity;

  /// Before tax, the amount the commission was calculated on.
  final int baseCents;
  final double commissionPercent;
  final int payoutCents;

  const StatementSaleLine({
    required this.date,
    required this.orderNumber,
    required this.productName,
    required this.variantLabel,
    required this.quantity,
    required this.baseCents,
    required this.commissionPercent,
    required this.payoutCents,
  });
}

/// What the store owes one artist for one period.
class ArtistStatement {
  final Artist artist;
  final DateRange range;
  final List<StatementSaleLine> sales;

  /// Refunds made during this period (shown as negative lines).
  final List<StatementSaleLine> refunds;

  const ArtistStatement({required this.artist, required this.range, required this.sales, required this.refunds});

  int get soldUnits => sales.fold(0, (s, l) => s + l.quantity) - refunds.fold(0, (s, l) => s + l.quantity);
  int get salesBaseCents => sales.fold(0, (s, l) => s + l.baseCents) - refunds.fold(0, (s, l) => s + l.baseCents);
  int get payoutCents => sales.fold(0, (s, l) => s + l.payoutCents) - refunds.fold(0, (s, l) => s + l.payoutCents);
  int get commissionCents => salesBaseCents - payoutCents;

  double get residentTaxPercent => artist.isSpainResident ? BusinessRules.spainResidentArtistTaxPercent : 0;
  int get residentTaxCents =>
      artist.isSpainResident ? Pricing.residentTax(payoutCents, BusinessRules.spainResidentArtistTaxPercent) : 0;
  int get netPayoutCents => Pricing.artistNetPayout(payoutCents: payoutCents, spainResident: artist.isSpainResident);

  bool get isEmpty => sales.isEmpty && refunds.isEmpty;
}

// ============================================================ Monthly report

class Breakdown {
  final String label;
  int units = 0;
  int revenueCents = 0;
  int profitCents = 0;
  Breakdown(this.label);
}

class ShelfLifeRow {
  final String productName;
  final String artistName;
  final String categoryName;
  final double days;
  final int units;
  const ShelfLifeRow(this.productName, this.artistName, this.categoryName, this.days, this.units);
}

class CategoryTurnover {
  final String category;
  final int soldUnits;
  final int inStockUnits;
  final double? avgDaysToSell;
  const CategoryTurnover(this.category, this.soldUnits, this.inStockUnits, this.avgDaysToSell);

  /// Share of available units that sold this month.
  double get sellThrough => (soldUnits + inStockUnits) == 0 ? 0 : soldUnits / (soldUnits + inStockUnits);
}

class MonthlyReport {
  final DateRange range;
  final int orderCount;
  final int unitsSold;
  final int unitsRefunded;
  final int revenueCents; // customer paid, VAT included, net of refunds
  final int vatCents;
  final int discountCents;
  final int refundsCents;
  final int artistPayoutCents;
  final int artistResidentTaxCents;
  final int profitCents;
  final List<Breakdown> byCategory;
  final List<Breakdown> byArtist;
  final List<Breakdown> byGender;
  final List<Breakdown> topProducts;
  final List<int> revenueByHour; // 24 entries
  final List<int> ordersByHour; // 24 entries
  final List<int> revenueByWeekday; // 7 entries, Monday first
  final List<int> revenueByDay; // one per day of month
  final double? avgDaysToSell;
  final List<ShelfLifeRow> fastestSellers;
  final List<ShelfLifeRow> slowestSellers;
  final List<ShelfLifeRow> longestOnDisplay; // unsold stock, days since arrival
  final List<CategoryTurnover> turnover;

  const MonthlyReport({
    required this.range,
    required this.orderCount,
    required this.unitsSold,
    required this.unitsRefunded,
    required this.revenueCents,
    required this.vatCents,
    required this.discountCents,
    required this.refundsCents,
    required this.artistPayoutCents,
    required this.artistResidentTaxCents,
    required this.profitCents,
    required this.byCategory,
    required this.byArtist,
    required this.byGender,
    required this.topProducts,
    required this.revenueByHour,
    required this.ordersByHour,
    required this.revenueByWeekday,
    required this.revenueByDay,
    required this.avgDaysToSell,
    required this.fastestSellers,
    required this.slowestSellers,
    required this.longestOnDisplay,
    required this.turnover,
  });
}

class ReportRepository {
  final Database db;
  ReportRepository(this.db);

  // ------------------------------------------------------- Artist statement

  Future<ArtistStatement> artistStatement(Artist artist, DateRange range) async {
    final sold = await db.rawQuery('''
      SELECT o.id AS order_id, o.created_at, oi.product_name, oi.variant_label, oi.quantity,
             oi.unit_base_cents, oi.base_cents, oi.commission_percent, oi.artist_payout_cents
      FROM order_items oi JOIN orders o ON o.id = oi.order_id
      WHERE oi.artist_id = ? AND o.created_at >= ? AND o.created_at < ?
      ORDER BY o.created_at''', [artist.id, toDb(range.start), toDb(range.end)]);

    final refunded = await db.rawQuery('''
      SELECT o.id AS order_id, r.created_at, oi.product_name, oi.variant_label, r.quantity,
             oi.unit_base_cents, r.base_cents, oi.commission_percent, r.artist_payout_cents
      FROM refunds r
      JOIN order_items oi ON oi.id = r.order_item_id
      JOIN orders o ON o.id = oi.order_id
      WHERE oi.artist_id = ? AND r.created_at >= ? AND r.created_at < ?
      ORDER BY r.created_at''', [artist.id, toDb(range.start), toDb(range.end)]);

    StatementSaleLine line(Map<String, Object?> r) {
      final qty = r['quantity'] as int;
      // Commission base: before tax. If the store absorbs discounts, the
      // artist is credited on the undiscounted base price.
      final base = BusinessRules.discountReducesArtistPayout
          ? r['base_cents'] as int
          : (r['unit_base_cents'] as int) * qty;
      return StatementSaleLine(
        date: fromDb(r['created_at'] as String),
        orderNumber: '#${(r['order_id'] as int).toString().padLeft(5, '0')}',
        productName: r['product_name'] as String,
        variantLabel: r['variant_label'] as String,
        quantity: qty,
        baseCents: base,
        commissionPercent: (r['commission_percent'] as num).toDouble(),
        payoutCents: r['artist_payout_cents'] as int,
      );
    }

    return ArtistStatement(
      artist: artist,
      range: range,
      sales: sold.map(line).toList(),
      refunds: refunded.map(line).toList(),
    );
  }

  Future<List<ArtistStatement>> allStatements(List<Artist> artists, DateRange range) async {
    final result = <ArtistStatement>[];
    for (final a in artists) {
      final s = await artistStatement(a, range);
      if (!s.isEmpty) result.add(s);
    }
    return result;
  }

  // ---------------------------------------------------------- Monthly report

  Future<MonthlyReport> monthly(DateRange range) async {
    final start = toDb(range.start);
    final end = toDb(range.end);

    final orders = await db.query('orders', where: 'created_at >= ? AND created_at < ?', whereArgs: [start, end]);

    final items = await db.rawQuery('''
      SELECT oi.*, o.created_at, a.name AS artist_name, a.gender, a.is_spain_resident
      FROM order_items oi
      JOIN orders o ON o.id = oi.order_id
      JOIN artists a ON a.id = oi.artist_id
      WHERE o.created_at >= ? AND o.created_at < ?''', [start, end]);

    final refunds = await db.rawQuery('''
      SELECT r.*, oi.product_id, oi.product_name, oi.category_name, oi.artist_id,
             a.name AS artist_name, a.gender, a.is_spain_resident
      FROM refunds r
      JOIN order_items oi ON oi.id = r.order_item_id
      JOIN artists a ON a.id = oi.artist_id
      WHERE r.created_at >= ? AND r.created_at < ?''', [start, end]);

    // --- Totals
    int sumOf(List<Map<String, Object?>> rows, String col) => rows.fold(0, (s, r) => s + (r[col] as int));
    final refundsTotal = sumOf(refunds, 'total_cents');
    final revenue = sumOf(orders, 'total_cents') - refundsTotal;
    final vat = sumOf(orders, 'tax_cents') - sumOf(refunds, 'tax_cents');
    final discounts = sumOf(orders, 'discount_cents');
    final unitsRefunded = sumOf(refunds, 'quantity');
    final unitsSold = sumOf(items, 'quantity') - unitsRefunded;

    // --- Artist payouts (needed per artist for the Spain-resident tax)
    final payoutByArtist = <int, int>{};
    final residentByArtist = <int, bool>{};
    for (final r in items) {
      final id = r['artist_id'] as int;
      payoutByArtist[id] = (payoutByArtist[id] ?? 0) + (r['artist_payout_cents'] as int);
      residentByArtist[id] = r['is_spain_resident'] == 1;
    }
    for (final r in refunds) {
      final id = r['artist_id'] as int;
      payoutByArtist[id] = (payoutByArtist[id] ?? 0) - (r['artist_payout_cents'] as int);
      residentByArtist[id] = r['is_spain_resident'] == 1;
    }
    var payout = 0;
    var residentTax = 0;
    payoutByArtist.forEach((id, p) {
      payout += p;
      if (residentByArtist[id] == true) {
        residentTax += Pricing.residentTax(p, BusinessRules.spainResidentArtistTaxPercent);
      }
    });
    final profit = Pricing.storeProfit(
      customerPaidCents: revenue,
      artistPayoutCents: payout,
      artistResidentTaxAddedCents: residentTax,
    );

    // --- Breakdowns (sales minus refunds)
    final byCategory = <String, Breakdown>{};
    final byArtist = <String, Breakdown>{};
    final byGender = <String, Breakdown>{};
    final byProduct = <String, Breakdown>{};
    void add(Map<String, Breakdown> map, String key, int units, int revenue, int profit) {
      final b = map.putIfAbsent(key, () => Breakdown(key));
      b.units += units;
      b.revenueCents += revenue;
      b.profitCents += profit;
    }

    for (final r in items) {
      final units = r['quantity'] as int;
      final rev = r['total_cents'] as int;
      final prof = rev - (r['artist_payout_cents'] as int);
      add(byCategory, r['category_name'] as String, units, rev, prof);
      add(byArtist, r['artist_name'] as String, units, rev, prof);
      add(byGender, (r['gender'] as String?) ?? 'Not set', units, rev, prof);
      add(byProduct, '${r['product_name']} — ${r['artist_name']}', units, rev, prof);
    }
    for (final r in refunds) {
      final units = -(r['quantity'] as int);
      final rev = -(r['total_cents'] as int);
      final prof = rev + (r['artist_payout_cents'] as int);
      add(byCategory, r['category_name'] as String, units, rev, prof);
      add(byArtist, r['artist_name'] as String, units, rev, prof);
      add(byGender, (r['gender'] as String?) ?? 'Not set', units, rev, prof);
      add(byProduct, '${r['product_name']} — ${r['artist_name']}', units, rev, prof);
    }
    List<Breakdown> sorted(Map<String, Breakdown> m) =>
        m.values.toList()..sort((a, b) => b.revenueCents.compareTo(a.revenueCents));

    // --- Time of sale
    final revenueByHour = List<int>.filled(24, 0);
    final ordersByHour = List<int>.filled(24, 0);
    final revenueByWeekday = List<int>.filled(7, 0);
    final daysInMonth = range.end.difference(range.start).inDays;
    final revenueByDay = List<int>.filled(daysInMonth < 1 ? 1 : daysInMonth, 0);
    for (final o in orders) {
      final t = fromDb(o['created_at'] as String);
      final total = o['total_cents'] as int;
      revenueByHour[t.hour] += total;
      ordersByHour[t.hour] += 1;
      revenueByWeekday[t.weekday - 1] += total;
      final dayIndex = startOfDay(t).difference(range.start).inDays;
      if (dayIndex >= 0 && dayIndex < revenueByDay.length) revenueByDay[dayIndex] += total;
    }

    // --- Shelf life: days from arrival to sale, for items sold this month
    final shelf = <String, _ShelfAcc>{};
    final catDays = <String, _ShelfAcc>{};
    var allDays = 0.0;
    var allUnits = 0;
    for (final r in items) {
      final arrival = r['arrival_date'] as String?;
      if (arrival == null) continue;
      final days = fromDb(r['created_at'] as String).difference(fromDb(arrival)).inHours / 24;
      final units = r['quantity'] as int;
      final key = '${r['product_id']}';
      shelf
          .putIfAbsent(key, () => _ShelfAcc(r['product_name'] as String, r['artist_name'] as String, r['category_name'] as String))
          .add(days, units);
      catDays.putIfAbsent(r['category_name'] as String, () => _ShelfAcc('', '', '')).add(days, units);
      allDays += days * units;
      allUnits += units;
    }
    final shelfRows = shelf.values.map((a) => a.row()).toList()..sort((a, b) => a.days.compareTo(b.days));

    // --- Current stock: how long unsold items have been on display
    final stock = await db.rawQuery('''
      SELECT p.name AS product_name, a.name AS artist_name, c.name AS category_name,
             v.quantity, v.date_of_arrival
      FROM variants v
      JOIN products p ON p.id = v.product_id
      JOIN artists a ON a.id = p.artist_id
      JOIN categories c ON c.id = p.category_id
      WHERE v.quantity > 0''');
    final now = DateTime.now();
    final onDisplay = <String, ShelfLifeRow>{};
    final stockByCategory = <String, int>{};
    for (final r in stock) {
      final days = now.difference(fromDb(r['date_of_arrival'] as String)).inHours / 24;
      final key = '${r['product_name']}|${r['artist_name']}';
      final existing = onDisplay[key];
      final units = r['quantity'] as int;
      if (existing == null || days > existing.days) {
        onDisplay[key] = ShelfLifeRow(r['product_name'] as String, r['artist_name'] as String,
            r['category_name'] as String, days, units + (existing?.units ?? 0));
      } else {
        onDisplay[key] = ShelfLifeRow(existing.productName, existing.artistName, existing.categoryName,
            existing.days, existing.units + units);
      }
      final cat = r['category_name'] as String;
      stockByCategory[cat] = (stockByCategory[cat] ?? 0) + units;
    }
    final longest = onDisplay.values.toList()..sort((a, b) => b.days.compareTo(a.days));

    final categories = {...byCategory.keys, ...stockByCategory.keys}.toList()..sort();
    final turnover = categories
        .map((c) => CategoryTurnover(
              c,
              byCategory[c]?.units ?? 0,
              stockByCategory[c] ?? 0,
              catDays[c]?.row().days,
            ))
        .toList();

    return MonthlyReport(
      range: range,
      orderCount: orders.length,
      unitsSold: unitsSold,
      unitsRefunded: unitsRefunded,
      revenueCents: revenue,
      vatCents: vat,
      discountCents: discounts,
      refundsCents: refundsTotal,
      artistPayoutCents: payout,
      artistResidentTaxCents: residentTax,
      profitCents: profit,
      byCategory: sorted(byCategory),
      byArtist: sorted(byArtist),
      byGender: sorted(byGender),
      topProducts: sorted(byProduct).take(15).toList(),
      revenueByHour: revenueByHour,
      ordersByHour: ordersByHour,
      revenueByWeekday: revenueByWeekday,
      revenueByDay: revenueByDay,
      avgDaysToSell: allUnits == 0 ? null : allDays / allUnits,
      fastestSellers: shelfRows.take(10).toList(),
      slowestSellers: shelfRows.reversed.take(10).toList(),
      longestOnDisplay: longest.take(10).toList(),
      turnover: turnover,
    );
  }
}

class _ShelfAcc {
  final String product;
  final String artist;
  final String category;
  double weightedDays = 0;
  int units = 0;
  _ShelfAcc(this.product, this.artist, this.category);

  void add(double days, int u) {
    weightedDays += days * u;
    units += u;
  }

  ShelfLifeRow row() => ShelfLifeRow(product, artist, category, units == 0 ? 0 : weightedDays / units, units);
}
