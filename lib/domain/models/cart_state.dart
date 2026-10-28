import 'cart_line.dart';
import 'discount.dart';
import 'line_amounts.dart';

/// The sale being rung up on the POS screen.
class CartState {
  final List<CartLine> lines;
  final Discount? discount;
  final String paymentMethod;

  /// Identifies this exact sale. It changes whenever the cart changes, and
  /// a repeated attempt with the same reference (e.g. after the connection
  /// dropped) is recorded only once.
  final String saleRef;

  const CartState({this.lines = const [], this.discount, required this.paymentMethod, required this.saleRef});

  double get discountPercent => discount?.percent ?? 0;

  List<LineAmounts> get amounts => lines.map((l) => l.amounts(discountPercent)).toList();
  int _sum(int Function(LineAmounts) f) => amounts.fold<int>(0, (s, a) => s + f(a));

  int get grossBaseCents => _sum((a) => a.grossBaseCents);
  int get discountCents => _sum((a) => a.discountCents);
  int get baseCents => _sum((a) => a.baseCents);
  int get taxCents => _sum((a) => a.taxCents);
  int get totalCents => _sum((a) => a.totalCents);
  int get units => lines.fold<int>(0, (s, l) => s + l.quantity);
  bool get isEmpty => lines.isEmpty;

  /// Tax totals per rate, e.g. {21.0: 2100, 4.0: 80}.
  Map<double, int> get taxByRate {
    final all = amounts;
    final m = <double, int>{};
    for (var i = 0; i < lines.length; i++) {
      final rate = lines[i].product.taxPercent;
      m[rate] = (m[rate] ?? 0) + all[i].taxCents;
    }
    return m;
  }

  int quantityInCart(int variantId) =>
      lines.where((l) => l.variant.id == variantId).fold<int>(0, (s, l) => s + l.quantity);

  CartState copyWith(
          {required String saleRef,
          List<CartLine>? lines,
          Discount? discount,
          bool clearDiscount = false,
          String? paymentMethod}) =>
      CartState(
        lines: lines ?? this.lines,
        discount: clearDiscount ? null : (discount ?? this.discount),
        paymentMethod: paymentMethod ?? this.paymentMethod,
        saleRef: saleRef,
      );
}
