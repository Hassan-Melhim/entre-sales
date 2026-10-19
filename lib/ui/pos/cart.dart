import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/business_rules.dart';
import '../../models/cart_line.dart';
import '../../models/cart_state.dart';
import '../../models/discount.dart';
import '../../models/product.dart';
import '../../models/variant.dart';

/// Changes to the sale being rung up.
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

  /// Sets a line's quantity (0 removes it). Returns false if it exceeds stock.
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

  void setDiscount(Discount? d) =>
      state = d == null ? state.copyWith(clearDiscount: true) : state.copyWith(discount: d);
  void setPayment(String method) => state = state.copyWith(paymentMethod: method);
  void clear() => state = CartState(paymentMethod: state.paymentMethod);
}

/// Kept outside the screen so the cart survives switching pages.
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());
