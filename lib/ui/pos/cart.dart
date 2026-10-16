import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/business_rules.dart';
import '../../core/pricing.dart';
import '../../data/models.dart';
import '../../data/repositories/sales_repository.dart';

class CartState {
  final List<CartLine> lines;
  final Discount? discount;
  final String paymentMethod;

  const CartState({this.lines = const [], this.discount, required this.paymentMethod});

  double get discountPercent => discount?.percent ?? 0;

  List<LineAmounts> get amounts => lines.map((l) => l.amounts(discountPercent)).toList();
  int _sum(int Function(LineAmounts) f) => amounts.fold(0, (s, a) => s + f(a));

  int get grossBaseCents => _sum((a) => a.grossBaseCents);
  int get discountCents => _sum((a) => a.discountCents);
  int get baseCents => _sum((a) => a.baseCents);
  int get taxCents => _sum((a) => a.taxCents);
  int get totalCents => _sum((a) => a.totalCents);
  int get units => lines.fold(0, (s, l) => s + l.quantity);

  /// Tax totals per rate, e.g. {21.0: 2100, 4.0: 80}.
  Map<double, int> get taxByRate {
    final m = <double, int>{};
    for (var i = 0; i < lines.length; i++) {
      final rate = lines[i].product.taxPercent;
      m[rate] = (m[rate] ?? 0) + amounts[i].taxCents;
    }
    return m;
  }

  int quantityInCart(int variantId) =>
      lines.where((l) => l.variant.id == variantId).fold(0, (s, l) => s + l.quantity);

  CartState copyWith({List<CartLine>? lines, Discount? discount, bool clearDiscount = false, String? paymentMethod}) =>
      CartState(
        lines: lines ?? this.lines,
        discount: clearDiscount ? null : (discount ?? this.discount),
        paymentMethod: paymentMethod ?? this.paymentMethod,
      );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState(paymentMethod: BusinessRules.paymentMethods.first));

  /// Adds one unit (or [quantity]). Returns false if that would exceed stock.
  bool add(Product product, Variant variant, {int quantity = 1}) {
    final inCart = state.quantityInCart(variant.id!);
    if (inCart + quantity > variant.quantity) return false;
    final lines = [...state.lines];
    final i = lines.indexWhere((l) => l.variant.id == variant.id);
    if (i >= 0) {
      lines[i] = lines[i].withQuantity(lines[i].quantity + quantity);
    } else {
      lines.add(CartLine(product: product, variant: variant, quantity: quantity));
    }
    state = state.copyWith(lines: lines);
    return true;
  }

  /// Sets a line's quantity. Returns false if it exceeds stock.
  bool setQuantity(int index, int quantity) {
    final lines = [...state.lines];
    if (quantity <= 0) {
      lines.removeAt(index);
    } else {
      if (quantity > lines[index].variant.quantity) return false;
      lines[index] = lines[index].withQuantity(quantity);
    }
    state = state.copyWith(lines: lines);
    return true;
  }

  void setDiscount(Discount? d) => state = d == null ? state.copyWith(clearDiscount: true) : state.copyWith(discount: d);
  void setPayment(String method) => state = state.copyWith(paymentMethod: method);
  void clear() => state = CartState(paymentMethod: state.paymentMethod);
}

/// Kept outside the screen so the cart survives switching tabs.
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());
