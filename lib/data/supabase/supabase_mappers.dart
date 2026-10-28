import '../../domain/business_rules.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/calendar_session.dart';
import '../../domain/models/category_attribute.dart';
import '../../domain/models/discount.dart';
import '../../domain/models/order_item.dart';
import '../../domain/models/order_status.dart';
import '../../domain/models/order_summary.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_category.dart';
import '../../domain/models/refunded_item.dart';
import '../../domain/models/sale_order.dart';
import '../../domain/models/sold_item.dart';
import '../../domain/models/stock_item.dart';
import '../../domain/models/variant.dart';
import 'supabase_values.dart';

/// Conversions between Supabase rows (JSON) and domain models. Kept here so
/// the models know nothing about how they are stored. Column names match
/// supabase/migrations.
class SupabaseMappers {
  SupabaseMappers._();

  // ------------------------------------------------------------------ artist
  static Artist artist(DbRow m) => Artist(
        id: asInt(m['id']),
        name: m['name'] as String,
        gender: m['gender'] as String?,
        address: m['address'] as String?,
        legalName: m['legal_name'] as String?,
        taxId: m['tax_id'] as String?,
        iban: m['iban'] as String?,
        bankName: m['bank_name'] as String?,
        isSpainResident: asBool(m['is_spain_resident']),
        commissionPercent: asDoubleOrNull(m['commission_percent']),
      );

  static DbRow artistRow(Artist a) => {
        'name': a.name,
        'gender': a.gender,
        'address': a.address,
        'legal_name': a.legalName,
        'tax_id': a.taxId,
        'iban': a.iban,
        'bank_name': a.bankName,
        'is_spain_resident': a.isSpainResident,
        'commission_percent': a.commissionPercent,
      };

  // ---------------------------------------------------------------- category
  static CategoryAttribute attribute(DbRow m) => CategoryAttribute(
        id: asInt(m['id']),
        name: m['name'] as String,
        options: asStringList(m['options']),
      );

  /// [m] is a categories row with its attributes embedded as "category_attributes".
  static ProductCategory category(DbRow m) {
    final attrs = asRows(m['category_attributes'])
      ..sort((a, b) {
        final byOrder = asInt(a['sort_order']).compareTo(asInt(b['sort_order']));
        return byOrder != 0 ? byOrder : asInt(a['id']).compareTo(asInt(b['id']));
      });
    return ProductCategory(
      id: asInt(m['id']),
      name: m['name'] as String,
      taxPercent: asDouble(m['tax_percent']),
      attributes: attrs.map(attribute).toList(),
    );
  }

  // ---------------------------------------------------------------- products
  static Variant variant(DbRow m) => Variant(
        id: asInt(m['id']),
        productId: asInt(m['product_id']),
        attributes: asStringMap(m['attributes']),
        quantity: asInt(m['quantity']),
        priceOverrideCents: asIntOrNull(m['price_override_cents']),
        dateOfArrival: parseDay(m['date_of_arrival']),
      );

  /// [m] is a product_rows row (product + artist / category details + variants).
  static Product product(DbRow m) => Product(
        id: asInt(m['id']),
        name: m['name'] as String,
        artistId: asInt(m['artist_id']),
        artistName: m['artist_name'] as String,
        categoryId: asInt(m['category_id']),
        categoryName: m['category_name'] as String,
        categoryTaxPercent: asDouble(m['category_tax']),
        basePriceCents: asInt(m['base_price_cents']),
        perVariantPricing: asBool(m['per_variant_pricing']),
        taxPercentOverride: asDoubleOrNull(m['tax_percent_override']),
        artistCommissionPercent: asDoubleOrNull(m['artist_commission']) ?? BusinessRules.defaultCommissionPercent,
        commissionPercentOverride: asDoubleOrNull(m['commission_percent_override']),
        variants: asRows(m['variants']).map(variant).toList(),
      );

  // --------------------------------------------------------------- discounts
  static Discount discount(DbRow m) => Discount(
        id: asInt(m['id']),
        name: m['name'] as String,
        percent: asDouble(m['percent']),
        active: asBool(m['active']),
      );

  static DbRow discountRow(Discount d) => {'name': d.name, 'percent': d.percent, 'active': d.active};

  // ---------------------------------------------------------------- sessions
  static CalendarSession session(DbRow m) => CalendarSession(
        id: asInt(m['id']),
        googleId: m['google_id'] as String?,
        title: m['title'] as String,
        start: parseMoment(m['start_at']),
        end: parseMoment(m['end_at']),
      );

  // ------------------------------------------------------------------ orders
  static OrderItem orderItem(DbRow m) => OrderItem(
        id: asInt(m['id']),
        orderId: asInt(m['order_id']),
        variantId: asIntOrNull(m['variant_id']),
        artistId: asInt(m['artist_id']),
        productName: m['product_name'] as String,
        variantLabel: m['variant_label'] as String,
        categoryName: m['category_name'] as String,
        quantity: asInt(m['quantity']),
        unitBaseCents: asInt(m['unit_base_cents']),
        taxPercent: asDouble(m['tax_percent']),
        commissionPercent: asDouble(m['commission_percent']),
        discountPercent: asDouble(m['discount_percent']),
        baseCents: asInt(m['base_cents']),
        discountCents: asInt(m['discount_cents']),
        taxCents: asInt(m['tax_cents']),
        totalCents: asInt(m['total_cents']),
        artistPayoutCents: asInt(m['artist_payout_cents']),
        arrivalDate: parseDayOrNull(m['arrival_date']),
        refundedQuantity: asInt(m['refunded_quantity']),
      );

  /// [m] is an order_rows row (order + event_title + items).
  static SaleOrder order(DbRow m) => SaleOrder(
        id: asInt(m['id']),
        createdAt: parseMoment(m['created_at']),
        paymentMethod: m['payment_method'] as String,
        status: OrderStatus.fromCode(m['status'] as String),
        calendarEventId: asIntOrNull(m['calendar_event_id']),
        calendarEventTitle: m['event_title'] as String?,
        eventTagSource: m['event_tag_source'] as String?,
        discountName: m['discount_name'] as String?,
        discountPercent: asDoubleOrNull(m['discount_percent']) ?? 0,
        subtotalCents: asInt(m['subtotal_cents']),
        discountCents: asInt(m['discount_cents']),
        taxCents: asInt(m['tax_cents']),
        totalCents: asInt(m['total_cents']),
        items: asRows(m['items']).map(orderItem).toList(),
      );

  // ----------------------------------------------------------------- reports
  static OrderSummary orderSummary(DbRow r) => OrderSummary(
        id: asInt(r['id']),
        createdAt: parseMoment(r['created_at']),
        paymentMethod: r['payment_method'] as String,
        discountCents: asInt(r['discount_cents']),
        taxCents: asInt(r['tax_cents']),
        totalCents: asInt(r['total_cents']),
      );

  static SoldItem soldItem(DbRow r) => SoldItem(
        orderId: asInt(r['order_id']),
        soldAt: parseMoment(r['sold_at']),
        artistId: asInt(r['artist_id']),
        artistName: r['artist_name'] as String,
        artistGender: r['artist_gender'] as String?,
        artistResident: asBool(r['artist_resident']),
        productId: asIntOrNull(r['product_id']),
        productName: r['product_name'] as String,
        variantLabel: r['variant_label'] as String,
        categoryName: r['category_name'] as String,
        quantity: asInt(r['quantity']),
        unitBaseCents: asInt(r['unit_base_cents']),
        baseCents: asInt(r['base_cents']),
        discountCents: asInt(r['discount_cents']),
        taxCents: asInt(r['tax_cents']),
        totalCents: asInt(r['total_cents']),
        commissionPercent: asDouble(r['commission_percent']),
        artistPayoutCents: asInt(r['artist_payout_cents']),
        arrivalDate: parseDayOrNull(r['arrival_date']),
      );

  static RefundedItem refundedItem(DbRow r) => RefundedItem(
        orderId: asInt(r['order_id']),
        refundedAt: parseMoment(r['refunded_at']),
        artistId: asInt(r['artist_id']),
        artistName: r['artist_name'] as String,
        artistGender: r['artist_gender'] as String?,
        artistResident: asBool(r['artist_resident']),
        productId: asIntOrNull(r['product_id']),
        productName: r['product_name'] as String,
        variantLabel: r['variant_label'] as String,
        categoryName: r['category_name'] as String,
        quantity: asInt(r['quantity']),
        unitBaseCents: asInt(r['unit_base_cents']),
        baseCents: asInt(r['base_cents']),
        taxCents: asInt(r['tax_cents']),
        totalCents: asInt(r['total_cents']),
        commissionPercent: asDouble(r['commission_percent']),
        artistPayoutCents: asInt(r['artist_payout_cents']),
      );

  static StockItem stockItem(DbRow r) => StockItem(
        productId: asInt(r['product_id']),
        productName: r['product_name'] as String,
        artistName: r['artist_name'] as String,
        categoryName: r['category_name'] as String,
        quantity: asInt(r['quantity']),
        arrival: parseDay(r['arrival']),
      );
}
