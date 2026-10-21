import '../business_rules.dart';
import '../models/artist.dart';
import '../models/artist_statement.dart';
import '../models/date_range.dart';
import '../models/refunded_item.dart';
import '../models/sale_order.dart';
import '../models/sold_item.dart';
import '../models/statement_line.dart';

/// Builds artist settlements from sales facts. Pure calculation: no database.
class ArtistStatementBuilder {
  ArtistStatementBuilder._();

  /// Settlements for every artist with sales or refunds in [range].
  static List<ArtistStatement> buildAll({
    required List<Artist> artists,
    required DateRange range,
    required List<SoldItem> sold,
    required List<RefundedItem> refunds,
  }) {
    final soldBy = <int, List<SoldItem>>{};
    for (final s in sold) {
      soldBy.putIfAbsent(s.artistId, () => []).add(s);
    }
    final refundsBy = <int, List<RefundedItem>>{};
    for (final r in refunds) {
      refundsBy.putIfAbsent(r.artistId, () => []).add(r);
    }
    return [
      for (final a in artists)
        if (soldBy.containsKey(a.id) || refundsBy.containsKey(a.id))
          build(artist: a, range: range, sold: soldBy[a.id] ?? const [], refunds: refundsBy[a.id] ?? const []),
    ];
  }

  /// [sold] and [refunds] must already belong to [artist].
  static ArtistStatement build({
    required Artist artist,
    required DateRange range,
    required List<SoldItem> sold,
    required List<RefundedItem> refunds,
  }) {
    return ArtistStatement(
      artist: artist,
      range: range,
      sales: [
        for (final s in [...sold]..sort((a, b) => a.soldAt.compareTo(b.soldAt)))
          StatementLine(
            date: s.soldAt,
            orderNumber: SaleOrder.formatOrderNumber(s.orderId),
            productName: s.productName,
            variantLabel: s.variantLabel,
            quantity: s.quantity,
            baseCents: _commissionBase(s.baseCents, s.unitBaseCents, s.quantity),
            commissionPercent: s.commissionPercent,
            payoutCents: s.artistPayoutCents,
          ),
      ],
      refunds: [
        for (final r in [...refunds]..sort((a, b) => a.refundedAt.compareTo(b.refundedAt)))
          StatementLine(
            date: r.refundedAt,
            orderNumber: SaleOrder.formatOrderNumber(r.orderId),
            productName: r.productName,
            variantLabel: r.variantLabel,
            quantity: r.quantity,
            baseCents: _commissionBase(r.baseCents, r.unitBaseCents, r.quantity),
            commissionPercent: r.commissionPercent,
            payoutCents: r.artistPayoutCents,
          ),
      ],
    );
  }

  /// The amount the commission is calculated on (before tax). If the store
  /// absorbs discounts, the artist is credited on the undiscounted price.
  static int _commissionBase(int discountedBase, int unitBase, int quantity) =>
      BusinessRules.discountReducesArtistPayout ? discountedBase : unitBase * quantity;
}
