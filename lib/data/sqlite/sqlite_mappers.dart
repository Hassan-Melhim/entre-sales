import 'dart:convert';

import '../../core/dates.dart';
import '../../domain/business_rules.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/calendar_session.dart';
import '../../domain/models/category_attribute.dart';
import '../../domain/models/discount.dart';
import '../../domain/models/order_item.dart';
import '../../domain/models/order_status.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_category.dart';
import '../../domain/models/sale_order.dart';
import '../../domain/models/variant.dart';
import 'db_values.dart';

/// Conversions between SQLite rows and domain models. Kept here so the
/// models know nothing about how they are stored.
class SqliteMappers {
  SqliteMappers._();

  // ------------------------------------------------------------------ artist
  static Artist artist(Map<String, Object?> m) => Artist(
        id: m['id'] as int,
        name: m['name'] as String,
        gender: m['gender'] as String?,
        address: m['address'] as String?,
        legalName: m['legal_name'] as String?,
        taxId: m['tax_id'] as String?,
        iban: m['iban'] as String?,
        bankName: m['bank_name'] as String?,
        isSpainResident: boolFromDb(m['is_spain_resident']),
        commissionPercent: doubleFromDb(m['commission_percent']),
      );

  static Map<String, Object?> artistRow(Artist a) => {
        'name': a.name,
        'gender': a.gender,
        'address': a.address,
        'legal_name': a.legalName,
        'tax_id': a.taxId,
        'iban': a.iban,
        'bank_name': a.bankName,
        'is_spain_resident': a.isSpainResident ? 1 : 0,
        'commission_percent': a.commissionPercent,
      };

  // ---------------------------------------------------------------- category
  static CategoryAttribute attribute(Map<String, Object?> m) => CategoryAttribute(
        id: m['id'] as int,
        name: m['name'] as String,
        options: (jsonDecode(m['options'] as String? ?? '[]') as List).cast<String>(),
      );

  static ProductCategory category(Map<String, Object?> m, List<CategoryAttribute> attributes) => ProductCategory(
        id: m['id'] as int,
        name: m['name'] as String,
        taxPercent: doubleFromDb(m['tax_percent'])!,
        attributes: attributes,
      );

  // ---------------------------------------------------------------- products
  static Variant variant(Map<String, Object?> m) => Variant(
        id: m['id'] as int,
        productId: m['product_id'] as int,
        attributes: (jsonDecode(m['attributes'] as String? ?? '{}') as Map).map((k, v) => MapEntry('$k', '$v')),
        quantity: m['quantity'] as int,
        priceOverrideCents: m['price_override_cents'] as int?,
        dateOfArrival: fromDb(m['date_of_arrival'] as String),
      );

  /// [m] is a products row joined with artist_name, artist_commission,
  /// category_name and category_tax.
  static Product product(Map<String, Object?> m, List<Variant> variants) => Product(
        id: m['id'] as int,
        name: m['name'] as String,
        artistId: m['artist_id'] as int,
        artistName: m['artist_name'] as String,
        categoryId: m['category_id'] as int,
        categoryName: m['category_name'] as String,
        categoryTaxPercent: doubleFromDb(m['category_tax'])!,
        basePriceCents: m['base_price_cents'] as int,
        perVariantPricing: boolFromDb(m['per_variant_pricing']),
        taxPercentOverride: doubleFromDb(m['tax_percent_override']),
        artistCommissionPercent: doubleFromDb(m['artist_commission']) ?? BusinessRules.defaultCommissionPercent,
        commissionPercentOverride: doubleFromDb(m['commission_percent_override']),
        variants: variants,
      );

  // --------------------------------------------------------------- discounts
  static Discount discount(Map<String, Object?> m) => Discount(
        id: m['id'] as int,
        name: m['name'] as String,
        percent: doubleFromDb(m['percent'])!,
        active: boolFromDb(m['active']),
      );

  static Map<String, Object?> discountRow(Discount d) => {
        'name': d.name,
        'percent': d.percent,
        'active': d.active ? 1 : 0,
      };

  // ---------------------------------------------------------------- sessions
  static CalendarSession session(Map<String, Object?> m) => CalendarSession(
        id: m['id'] as int,
        googleId: m['google_id'] as String?,
        title: m['title'] as String,
        start: fromDb(m['start_at'] as String),
        end: fromDb(m['end_at'] as String),
      );

  // ------------------------------------------------------------------ orders
  static OrderItem orderItem(Map<String, Object?> m) => OrderItem(
        id: m['id'] as int,
        orderId: m['order_id'] as int,
        variantId: m['variant_id'] as int?,
        artistId: m['artist_id'] as int,
        productName: m['product_name'] as String,
        variantLabel: m['variant_label'] as String,
        categoryName: m['category_name'] as String,
        quantity: m['quantity'] as int,
        unitBaseCents: m['unit_base_cents'] as int,
        taxPercent: doubleFromDb(m['tax_percent'])!,
        commissionPercent: doubleFromDb(m['commission_percent'])!,
        discountPercent: doubleFromDb(m['discount_percent'])!,
        baseCents: m['base_cents'] as int,
        discountCents: m['discount_cents'] as int,
        taxCents: m['tax_cents'] as int,
        totalCents: m['total_cents'] as int,
        artistPayoutCents: m['artist_payout_cents'] as int,
        arrivalDate: m['arrival_date'] == null ? null : fromDb(m['arrival_date'] as String),
        refundedQuantity: m['refunded_quantity'] as int,
      );

  /// [m] is an orders row joined with event_title.
  static SaleOrder order(Map<String, Object?> m, List<OrderItem> items) => SaleOrder(
        id: m['id'] as int,
        createdAt: fromDb(m['created_at'] as String),
        paymentMethod: m['payment_method'] as String,
        status: OrderStatus.fromCode(m['status'] as String),
        calendarEventId: m['calendar_event_id'] as int?,
        calendarEventTitle: m['event_title'] as String?,
        eventTagSource: m['event_tag_source'] as String?,
        discountName: m['discount_name'] as String?,
        discountPercent: doubleFromDb(m['discount_percent']) ?? 0,
        subtotalCents: m['subtotal_cents'] as int,
        discountCents: m['discount_cents'] as int,
        taxCents: m['tax_cents'] as int,
        totalCents: m['total_cents'] as int,
        items: items,
      );
}
