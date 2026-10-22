/// Design tokens: every spacing, size and radius used by the interface.
/// Screens use these names instead of raw numbers, so the look can be tuned
/// in one place and stays consistent.
class AppSpacing {
  AppSpacing._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  AppRadius._();
  static const double s = 4;
  static const double pill = 20;
}

/// Preferred widths. They are maximums: on small screens things shrink.
class AppSizes {
  AppSizes._();

  // Form fields
  static const double fieldNarrow = 140; // quantity, percent
  static const double fieldMedium = 220; // price, date
  static const double fieldWide = 420; // free-text entry

  // Dialogs
  static const double dialogSmall = 400;
  static const double dialogMedium = 560;
  static const double dialogLarge = 640;
  static const double dialogMin = 240;

  /// Max width of forms and settings so lines stay readable on big screens.
  static const double contentMax = 1100;

  // Navigation
  static const double railExtendedWidth = 180;

  // Point of sale
  static const double cartPanel = 360;
  static const double cartPanelWide = 420;
  static const double productTileCompact = 200;
  static const double productTile = 240;
  static const double productTileHeight = 124;
  static const double checkoutButtonHeight = 52;

  // Reports
  static const double chartHeight = 200;
  static const double chartAxisWidth = 52;
  static const double kpiMinWidth = 190;
  static const double breakdownLabel = 130;
  static const double breakdownNumbers = 190;

  // Lists
  static const double infoLabel = 260;
  static const double iconSmall = 16;
  static const double iconTag = 14;
  static const double iconLarge = 48; // empty states, error screens
  static const double emptyStateIcon = 48;
}

/// Layout thresholds for individual components (not the whole screen).
class AppLayout {
  AppLayout._();

  /// POS: below this width the cart moves into a bottom sheet.
  static const double posSideCartMin = 840;

  /// POS: above this width the cart panel gets wider.
  static const double posWideCartMin = 1200;

  /// Two report panels side by side from this width.
  static const double reportPairMin = 820;

  /// Tables instead of compact lists from these widths.
  static const double variantTableMin = 560;
  static const double payoutTableMin = 760;
  static const double variantFormRowMin = 520;
  static const double breakdownRowMin = 520;

  /// Rows of form fields from these widths.
  static const double filterRowMin = 720;
  static const double productFieldsRowMin = 760;
  static const double storeFieldsRowMin = 700;
}
