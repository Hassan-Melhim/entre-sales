import 'order_item.dart';
import 'order_status.dart';

/// A completed sale (an "order").
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
}
