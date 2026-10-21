// ============================================================================
//  BUSINESS RULES  —  CHANGE THE STORE'S MONEY RULES HERE
// ============================================================================
//
//  Every percentage and formula that decides how money is split lives in
//  this one file. Each rule is marked with ►►► so it is easy to find.
//
//  Percentages are written as plain numbers: 35 means 35%.
//
//  VAT (IVA) rates per category are NOT here: they are stored with each
//  category and can be edited in the app (Settings → Categories).
//  Seed values for a fresh install are in [seedCategories] at the bottom.
// ============================================================================

class BusinessRules {
  BusinessRules._();

  // ►►► DEFAULT STORE COMMISSION
  // Used for every artist that does not have their own commission set.
  // Priority: product commission → artist commission → this default.
  // A 100 € (before tax) piece pays the artist 100 − 35% = 65 €.
  static const double defaultCommissionPercent = 35.0;

  // ►►► TAX FOR ARTISTS WHO RESIDE IN SPAIN
  // Placeholder value: confirm the real rate with your accountant.
  static const double spainResidentArtistTaxPercent = 10.0;

  // ►►► HOW THE SPAIN-RESIDENT TAX IS APPLIED TO THE ARTIST PAYOUT
  // true  = ADDED ON TOP:   65 € + 10% = 71.50 €  (current choice)
  // false = WITHHELD FROM:  65 € − 10% = 58.50 €
  static const bool residentTaxAddedOnTop = true;

  // ►►► DOES A DISCOUNT ALSO REDUCE WHAT THE ARTIST IS PAID?
  // true  = artist is paid on the discounted price (100 € → 95 € → 61.75 €)
  // false = the store absorbs the discount; artist still gets 65 €  (current choice)
  static const bool discountReducesArtistPayout = false;

  // ►►► STORE PROFIT FORMULA
  // Profit = what the customer paid (VAT included) − what the artist is paid.
  // If true, the Spain-resident artist tax added on top (see above) is also
  // subtracted, because it is money that leaves the store.
  // NOTE: waiting for confirmation from the store owner.
  static const bool profitSubtractsArtistResidentTax = true;

  // ►►► GOOGLE CALENDAR: which events count as workshop/event sessions.
  // An event counts if its title contains this word (case does not matter).
  static const String workshopKeyword = 'workshop';

  // ARTIST PAYOUTS are calculated per calendar month, or for any custom
  // date range chosen in the Invoices screen.

  // ►►► GENDER OPTIONS for artists (used for sales analysis).
  static const List<String> genders = ['Male', 'Female', 'Queer'];

  // ►►► PAYMENT METHODS (recorded only; payment happens on the bank terminal).
  static const List<String> paymentMethods = ['Cash', 'Card'];
}

/// Categories created on a fresh install. After the first launch they live
/// in the database and are edited from Settings → Categories.
///
/// Each attribute has an options list:
///   - empty list  → the value is typed as free text when logging a product
///   - with values → the user picks from that fixed list
///
/// Based on the products in the store's inventory (Sept 2026). Keep in sync
/// with CATEGORIES in tool/demo_data/catalog_mapping.py (a test checks this).
const List<SeedCategory> seedCategories = [
  // ►►► VAT: 21% general rate, 4% for books, 0% for the café (as instructed).
  SeedCategory('Clothing', 21, {
    'Size': ['XS', 'XS/S', 'S', 'M', 'L', 'XL'],
    'Style': [],
  }),
  SeedCategory('Jewellery', 21, {'Finish': [], 'Style': []}),
  SeedCategory('Accessories', 21, {'Style': [], 'Size': []}),
  SeedCategory('Ceramics', 21, {'Design': [], 'Size': []}),
  SeedCategory('Prints & Posters', 21, {
    'Design': [],
    'Size': ['A4', 'A3', 'Big'],
  }),
  SeedCategory('Postcards & Stickers', 21, {'Design': []}),
  SeedCategory('Books & Zines', 4, {'Language': []}),
  SeedCategory('Stationery', 21, {'Design': []}),
  SeedCategory('Home & Textiles', 21, {
    'Pattern': [],
    'Size': ['Single', 'Double', 'King'],
  }),
  SeedCategory('Lamps', 21, {'Design': []}),
  SeedCategory('Candles', 21, {'Scent': []}),
  SeedCategory('Toys & Games', 21, {'Design': []}),
  SeedCategory('Art & Objects', 21, {'Design': []}),
  SeedCategory('Food & Drink', 0, {'Option': []}),
  SeedCategory('Miscellaneous', 21, {}),
];

/// Discounts created on a fresh install. More can be added in Settings.
const List<SeedDiscount> seedDiscounts = [
  SeedDiscount('Friends & Family', 5),
];

class SeedCategory {
  final String name;
  final double taxPercent;
  final Map<String, List<String>> attributes;
  const SeedCategory(this.name, this.taxPercent, this.attributes);
}

class SeedDiscount {
  final String name;
  final double percent;
  const SeedDiscount(this.name, this.percent);
}
