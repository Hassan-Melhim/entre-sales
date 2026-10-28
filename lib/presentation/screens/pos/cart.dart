import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids.dart';
import '../../../domain/business_rules.dart';
import '../../../domain/models/cart_line.dart';
import '../../../domain/models/cart_state.dart';
import '../../../domain/models/discount.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/variant.dart';

/// Changes to the sale being rung up.
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState(paymentMethod: BusinessRules.paymentMethods.first, saleRef: newUuid()));

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
    state = state.copyWith(lines: lines, saleRef: newUuid());
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
    state = state.copyWith(lines: lines, saleRef: newUuid());
    return true;
  }

  void setDiscount(Discount? d) =>
      state = d == null
          ? state.copyWith(clearDiscount: true, saleRef: newUuid())
          : state.copyWith(discount: d, saleRef: newUuid());
  void setPayment(String method) => state = state.copyWith(paymentMethod: method, saleRef: newUuid());
  void clear() => state = CartState(paymentMethod: state.paymentMethod, saleRef: newUuid());
}

/// Kept outside the screen so the cart survives switching pages.
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());
