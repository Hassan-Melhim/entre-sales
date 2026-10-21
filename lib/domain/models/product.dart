import '../pricing.dart';
import 'variant.dart';

/// A product with everything needed to show and sell it
/// (artist and category details are joined in).
class Product {
  final int? id;
  final String name;
  final int artistId;
  final String artistName;
  final int categoryId;
  final String categoryName;
  final double categoryTaxPercent;

  /// Price before tax.
  final int basePriceCents;
  final bool perVariantPricing;

  /// Manual tax rate saved on this product. NULL = category rate.
  final double? taxPercentOverride;

  /// The artist's commission (their own rate, or the store default).
  final double artistCommissionPercent;

  /// Commission for this product only. NULL = the artist's commission.
  final double? commissionPercentOverride;
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
    this.commissionPercentOverride,
    required this.variants,
  });

  double get taxPercent => taxPercentOverride ?? categoryTaxPercent;

  /// The commission actually charged when this product sells.
  double get commissionPercent => commissionPercentOverride ?? artistCommissionPercent;
  bool get hasCustomCommission => commissionPercentOverride != null;

  int get totalStock => variants.fold(0, (sum, v) => sum + v.quantity);
  bool get isOutOfStock => totalStock == 0;

  /// Price before tax for a variant (respects the per-variant pricing checkbox).
  int baseCentsFor(Variant v) =>
      perVariantPricing && v.priceOverrideCents != null ? v.priceOverrideCents! : basePriceCents;

  int priceWithTaxFor(Variant v) => Pricing.unitPriceWithTax(baseCentsFor(v), taxPercent);

  /// Lowest shelf price across variants (for "from …" labels).
  int get lowestPriceWithTax => variants.isEmpty
      ? Pricing.unitPriceWithTax(basePriceCents, taxPercent)
      : variants.map(priceWithTaxFor).reduce((a, b) => a < b ? a : b);

  bool get hasVaryingPrices => perVariantPricing && variants.map(priceWithTaxFor).toSet().length > 1;
}
