import '../pricing.dart';
import 'line_amounts.dart';
import 'product.dart';
import 'variant.dart';

/// One line in the POS cart.
class CartLine {
  final Product product;
  final Variant variant;
  final int quantity;

  const CartLine({required this.product, required this.variant, required this.quantity});

  CartLine withQuantity(int q) => CartLine(product: product, variant: variant, quantity: q);

  LineAmounts amounts(double discountPercent) => Pricing.line(
        unitBaseCents: product.baseCentsFor(variant),
        quantity: quantity,
        taxPercent: product.taxPercent,
        discountPercent: discountPercent,
        commissionPercent: product.commissionPercent,
      );
}
