/// What will be added, after the files were checked. Names are matched in
/// the database without regard to upper / lower case.
class ImportPlan {
  final List<ArtistDraft> artists;
  final List<ProductDraft> products;
  final List<ReceiptDraft> receipts;

  const ImportPlan({this.artists = const [], this.products = const [], this.receipts = const []});

  bool get isEmpty => artists.isEmpty && products.isEmpty && receipts.isEmpty;
  int get variantCount => products.fold(0, (s, p) => s + p.variants.length);
  int get saleLineCount => receipts.fold(0, (s, r) => s + r.lines.length);
}

class ArtistDraft {
  final String name;
  final bool isSpainResident;
  final double? commissionPercent;
  final String? gender, legalName, taxId, address, iban, bankName;

  const ArtistDraft({
    required this.name,
    required this.isSpainResident,
    this.commissionPercent,
    this.gender,
    this.legalName,
    this.taxId,
    this.address,
    this.iban,
    this.bankName,
  });
}

class ProductDraft {
  final String artistName;
  final String name;
  final String categoryName;
  final int basePriceCents;
  final bool perVariantPricing;
  final double? taxPercentOverride;
  final double? commissionPercentOverride;
  final List<VariantDraft> variants;

  const ProductDraft({
    required this.artistName,
    required this.name,
    required this.categoryName,
    required this.basePriceCents,
    required this.perVariantPricing,
    this.taxPercentOverride,
    this.commissionPercentOverride,
    required this.variants,
  });
}

class VariantDraft {
  /// In the category's field order.
  final Map<String, String> attributes;
  final int quantity;
  final int? priceOverrideCents;
  final DateTime dateOfArrival;

  const VariantDraft({
    required this.attributes,
    required this.quantity,
    this.priceOverrideCents,
    required this.dateOfArrival,
  });
}

/// One receipt from the old till.
class ReceiptDraft {
  final String receipt;

  /// Store (Madrid) time of the sale.
  final DateTime at;
  final String paymentMethod;
  final String? discountName;
  final List<SaleLineDraft> lines;

  const ReceiptDraft({
    required this.receipt,
    required this.at,
    required this.paymentMethod,
    this.discountName,
    required this.lines,
  });
}

class SaleLineDraft {
  final String artistName;
  final String productName;
  final String categoryName;
  final String variant;
  final int quantity;
  final int baseCents;
  final int totalCents;
  final double? commissionPercent;

  const SaleLineDraft({
    required this.artistName,
    required this.productName,
    required this.categoryName,
    required this.variant,
    required this.quantity,
    required this.baseCents,
    required this.totalCents,
    this.commissionPercent,
  });
}
