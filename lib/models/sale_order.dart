import '../core/dates.dart';
import '../core/db_values.dart';
import 'order_item.dart';
import 'order_status.dart';

/// A completed sale (an "order" in the database).
class SaleOrder {
  final int id;
  final DateTime createdAt;
  final String paymentMethod;
  final OrderStatus status;
  final int? calendarEventId;
  final String? calendarEventTitle;

  /// NULL, 'auto' or 'manual'.
  final String? eventTagSource;
  final String? discountName;
  final double discountPercent;

  /// After discount, before tax.
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

  String get number => formatOrderNumber(id);

  static String formatOrderNumber(int id) => '#${id.toString().padLeft(5, '0')}';

  int get units => items.fold(0, (s, i) => s + i.quantity);

  factory SaleOrder.fromMap(Map<String, Object?> m, List<OrderItem> items) => SaleOrder(
        id: m['id'] as int,
        createdAt: fromDb(m['created_at'] as String),
        paymentMethod: m['payment_method'] as String,
        status: OrderStatus.fromDb(m['status'] as String),
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
