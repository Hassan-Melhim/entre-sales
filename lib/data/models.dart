import 'dart:convert';

import '../config/business_rules.dart';
import '../core/dates.dart';
import '../core/pricing.dart';

bool _b(Object? v) => v == 1 || v == true;
double? _d(Object? v) => v == null ? null : (v as num).toDouble();

class Artist {
  final int? id;
  final String name;
  final String? gender;
  final String? address;
  final String? legalName;
  final String? taxId;
  final String? iban;
  final String? bankName;
  final bool isSpainResident;

  /// NULL means the store default ([BusinessRules.defaultCommissionPercent]).
  final double? commissionPercent;

  const Artist({
    this.id,
    required this.name,
    this.gender,
    this.address,
    this.legalName,
    this.taxId,
    this.iban,
    this.bankName,
    this.isSpainResident = true,
    this.commissionPercent,
  });

  double get effectiveCommission => commissionPercent ?? BusinessRules.defaultCommissionPercent;

  factory Artist.fromMap(Map<String, Object?> m) => Artist(
        id: m['id'] as int,
        name: m['name'] as String,
        gender: m['gender'] as String?,
        address: m['address'] as String?,
        legalName: m['legal_name'] as String?,
        taxId: m['tax_id'] as String?,
        iban: m['iban'] as String?,
        bankName: m['bank_name'] as String?,
        isSpainResident: _b(m['is_spain_resident']),
        commissionPercent: _d(m['commission_percent']),
      );

  Map<String, Object?> toMap() => {
        'name': name,
        'gender': gender,
        'address': address,
        'legal_name': legalName,
        'tax_id': taxId,
        'iban': iban,
        'bank_name': bankName,
        'is_spain_resident': isSpainResident ? 1 : 0,
        'commission_percent': commissionPercent,
      };
}

class CategoryAttribute {
  final int? id;
  final String name;

  /// Empty = free text.
  final List<String> options;

  const CategoryAttribute({this.id, required this.name, this.options = const []});

  bool get isFreeText => options.isEmpty;

  factory CategoryAttribute.fromMap(Map<String, Object?> m) => CategoryAttribute(
        id: m['id'] as int,
        name: m['name'] as String,
        options: (jsonDecode(m['options'] as String? ?? '[]') as List).cast<String>(),
      );
}

class ProductCategory {
  final int? id;
  final String name;
  final double taxPercent;
  final List<CategoryAttribute> attributes;

  const ProductCategory({this.id, required this.name, required this.taxPercent, this.attributes = const []});

  factory ProductCategory.fromMap(Map<String, Object?> m, List<CategoryAttribute> attributes) => ProductCategory(
        id: m['id'] as int,
        name: m['name'] as String,
        taxPercent: _d(m['tax_percent'])!,
        attributes: attributes,
      );
}

class Variant {
  final int? id;
  final int? productId;

  /// e.g. {"Size": "M", "Colour": "Black"}. Empty for products without attributes.
  final Map<String, String> attributes;
  final int quantity;
  final int? priceOverrideCents;
  final DateTime dateOfArrival;

  const Variant({
    this.id,
    this.productId,
    this.attributes = const {},
    required this.quantity,
    this.priceOverrideCents,
    required this.dateOfArrival,
  });

  String get label => attributes.isEmpty ? 'Standard' : attributes.values.join(' · ');

  factory Variant.fromMap(Map<String, Object?> m) => Variant(
        id: m['id'] as int,
        productId: m['product_id'] as int,
        attributes: (jsonDecode(m['attributes'] as String? ?? '{}') as Map).map((k, v) => MapEntry('$k', '$v')),
        quantity: m['quantity'] as int,
        priceOverrideCents: m['price_override_cents'] as int?,
        dateOfArrival: fromDb(m['date_of_arrival'] as String),
      );

  Variant copyWith({int? quantity, int? priceOverrideCents, DateTime? dateOfArrival, bool clearPrice = false}) =>
      Variant(
        id: id,
        productId: productId,
        attributes: attributes,
        quantity: quantity ?? this.quantity,
        priceOverrideCents: clearPrice ? null : (priceOverrideCents ?? this.priceOverrideCents),
        dateOfArrival: dateOfArrival ?? this.dateOfArrival,
      );
}

/// A product with everything needed to show and sell it.
class Product {
  final int? id;
  final String name;
  final int artistId;
  final String artistName;
  final int categoryId;
  final String categoryName;
  final double categoryTaxPercent;
  final int basePriceCents;
  final bool perVariantPricing;
  final double? taxPercentOverride;
  final double artistCommissionPercent;
  final List<Variant> variants;

  const Product({
    this.id,
    required this.name,
    required this.artistId,
    required this.artistName,
    required this.categoryId,
    required this.categoryName,
    required this.categoryTaxPercent,
    required this.basePriceCents,
    required this.perVariantPricing,
    this.taxPercentOverride,
    required this.artistCommissionPercent,
    required this.variants,
  });

  double get taxPercent => taxPercentOverride ?? categoryTaxPercent;
  int get totalStock => variants.fold(0, (sum, v) => sum + v.quantity);
  bool get isOutOfStock => totalStock == 0;

  /// Price before tax for a variant (respects the per-variant pricing checkbox).
  int baseCentsFor(Variant v) =>
      perVariantPricing && v.priceOverrideCents != null ? v.priceOverrideCents! : basePriceCents;

  int priceWithTaxFor(Variant v) => Pricing.unitPriceWithTax(baseCentsFor(v), taxPercent);

  DateTime? get latestArrival => variants.isEmpty
      ? null
      : variants.map((v) => v.dateOfArrival).reduce((a, b) => a.isAfter(b) ? a : b);
}

class Discount {
  final int? id;
  final String name;
  final double percent;
  final bool active;

  const Discount({this.id, required this.name, required this.percent, this.active = true});

  factory Discount.fromMap(Map<String, Object?> m) => Discount(
        id: m['id'] as int,
        name: m['name'] as String,
        percent: _d(m['percent'])!,
        active: _b(m['active']),
      );
}

class CalendarSession {
  final int? id;
  final String? googleId;
  final String title;
  final DateTime start;
  final DateTime end;

  const CalendarSession({this.id, this.googleId, required this.title, required this.start, required this.end});

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  String get label => '$title · ${formatDateTime(start)}';

  factory CalendarSession.fromMap(Map<String, Object?> m) => CalendarSession(
        id: m['id'] as int,
        googleId: m['google_id'] as String?,
        title: m['title'] as String,
        start: fromDb(m['start_at'] as String),
        end: fromDb(m['end_at'] as String),
      );
}

enum OrderStatus {
  completed('completed', 'Completed'),
  partiallyRefunded('partially_refunded', 'Partially refunded'),
  refunded('refunded', 'Refunded');

  final String db;
  final String label;
  const OrderStatus(this.db, this.label);

  static OrderStatus fromDb(String s) => values.firstWhere((e) => e.db == s, orElse: () => completed);
}

class OrderItem {
  final int id;
  final int orderId;
  final int? variantId;
  final int artistId;
  final String productName;
  final String variantLabel;
  final String categoryName;
  final int quantity;
  final int unitBaseCents;
  final double taxPercent;
  final double commissionPercent;
  final double discountPercent;
  final int baseCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;
  final int artistPayoutCents;
  final DateTime? arrivalDate;
  final int refundedQuantity;

  const OrderItem({
    required this.id,
    required this.orderId,
    this.variantId,
    required this.artistId,
    required this.productName,
    required this.variantLabel,
    required this.categoryName,
    required this.quantity,
    required this.unitBaseCents,
    required this.taxPercent,
    required this.commissionPercent,
    required this.discountPercent,
    required this.baseCents,
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
    required this.artistPayoutCents,
    this.arrivalDate,
    required this.refundedQuantity,
  });

  int get refundableQuantity => quantity - refundedQuantity;

  factory OrderItem.fromMap(Map<String, Object?> m) => OrderItem(
        id: m['id'] as int,
        orderId: m['order_id'] as int,
        variantId: m['variant_id'] as int?,
        artistId: m['artist_id'] as int,
        productName: m['product_name'] as String,
        variantLabel: m['variant_label'] as String,
        categoryName: m['category_name'] as String,
        quantity: m['quantity'] as int,
        unitBaseCents: m['unit_base_cents'] as int,
        taxPercent: _d(m['tax_percent'])!,
        commissionPercent: _d(m['commission_percent'])!,
        discountPercent: _d(m['discount_percent'])!,
        baseCents: m['base_cents'] as int,
        discountCents: m['discount_cents'] as int,
        taxCents: m['tax_cents'] as int,
        totalCents: m['total_cents'] as int,
        artistPayoutCents: m['artist_payout_cents'] as int,
        arrivalDate: m['arrival_date'] == null ? null : fromDb(m['arrival_date'] as String),
        refundedQuantity: m['refunded_quantity'] as int,
      );
}

class SaleOrder {
  final int id;
  final DateTime createdAt;
  final String paymentMethod;
  final OrderStatus status;
  final int? calendarEventId;
  final String? calendarEventTitle;
  final String? eventTagSource;
  final String? discountName;
  final double discountPercent;
  final int subtotalCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;
  final List<OrderItem> items;

  const SaleOrder({
    required this.id,
    required this.createdAt,
    required this.paymentMethod,
    required this.status,
    this.calendarEventId,
    this.calendarEventTitle,
    this.eventTagSource,
    this.discountName,
    required this.discountPercent,
    required this.subtotalCents,
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
    this.items = const [],
  });

  String get number => '#${id.toString().padLeft(5, '0')}';

  factory SaleOrder.fromMap(Map<String, Object?> m, List<OrderItem> items) => SaleOrder(
        id: m['id'] as int,
        createdAt: fromDb(m['created_at'] as String),
        paymentMethod: m['payment_method'] as String,
        status: OrderStatus.fromDb(m['status'] as String),
        calendarEventId: m['calendar_event_id'] as int?,
        calendarEventTitle: m['event_title'] as String?,
        eventTagSource: m['event_tag_source'] as String?,
        discountName: m['discount_name'] as String?,
        discountPercent: _d(m['discount_percent']) ?? 0,
        subtotalCents: m['subtotal_cents'] as int,
        discountCents: m['discount_cents'] as int,
        taxCents: m['tax_cents'] as int,
        totalCents: m['total_cents'] as int,
        items: items,
      );
}
