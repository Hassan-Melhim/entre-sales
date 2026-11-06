/// Files bundled with the app (listed under `flutter: assets:` in pubspec.yaml).
abstract final class AppAssets {
  static const fontRegular = 'assets/fonts/Lato-Regular.ttf';
  static const fontBold = 'assets/fonts/Lato-Bold.ttf';

  /// The workbook to fill in for importing data (built by tool/migration).
  static const importTemplate = 'assets/templates/data_import_template.xlsx';
}
