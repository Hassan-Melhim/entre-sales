import '../../core/csv.dart';

/// The three tabs of "Entre Sales - data import template.xlsx", saved as CSV.
/// Headers must match tool/migration/make_import_template.py.
enum ImportFileKind {
  artists('Artists'),
  products('Products'),
  pastSales('Past sales');

  final String label;
  const ImportFileKind(this.label);
}

/// A column of a template tab.
class TemplateColumn {
  final String header;
  final bool required;
  const TemplateColumn(this.header, {this.required = false});

  String get key => normalizeHeader(header);
}

/// Variant fields, one column each on the Products tab.
const List<String> templateFields = ['Size', 'Style', 'Design', 'Finish', 'Pattern', 'Scent', 'Language', 'Option'];

abstract final class ArtistCols {
  static const name = TemplateColumn('Artist name', required: true);
  static const resident = TemplateColumn('Spain resident', required: true);
  static const commission = TemplateColumn('Commission (%)');
  static const gender = TemplateColumn('Gender');
  static const legalName = TemplateColumn('Legal name');
  static const taxId = TemplateColumn('NIF / NIE / Tax ID');
  static const address = TemplateColumn('Address');
  static const iban = TemplateColumn('IBAN');
  static const bank = TemplateColumn('Bank');
  static const all = [name, resident, commission, gender, legalName, taxId, address, iban, bank];
}

abstract final class ProductCols {
  static const artist = TemplateColumn('Artist', required: true);
  static const product = TemplateColumn('Product', required: true);
  static const category = TemplateColumn('Category', required: true);
  static const price = TemplateColumn('Price incl. VAT (€)', required: true);
  static const stock = TemplateColumn('Stock now', required: true);
  static const arrived = TemplateColumn('Date arrived');
  static const commission = TemplateColumn('Product commission (%)');
  static const vat = TemplateColumn('VAT (%) override');
  static final List<TemplateColumn> fields = [for (final f in templateFields) TemplateColumn(f)];
  static final all = [artist, product, category, ...fields, price, stock, arrived, commission, vat];
}

abstract final class SaleCols {
  static const receipt = TemplateColumn('Receipt no.', required: true);
  static const date = TemplateColumn('Date', required: true);
  static const time = TemplateColumn('Time');
  static const payment = TemplateColumn('Payment', required: true);
  static const artist = TemplateColumn('Artist', required: true);
  static const product = TemplateColumn('Product', required: true);
  static const category = TemplateColumn('Category', required: true);
  static const variant = TemplateColumn('Variant');
  static const quantity = TemplateColumn('Quantity', required: true);
  static const before = TemplateColumn('Total before VAT (€)', required: true);
  static const incl = TemplateColumn('Total incl. VAT (€)', required: true);
  static const discount = TemplateColumn('Discount');
  static const commission = TemplateColumn('Commission (%)');
  static const all = [receipt, date, time, payment, artist, product, category, variant, quantity, before, incl, discount, commission];
}

/// The grey example row (row 2) of each tab, recognised by a few of its
/// values and skipped.
bool isTemplateExample(ImportFileKind kind, String Function(TemplateColumn) cell) => switch (kind) {
      ImportFileKind.artists => cell(ArtistCols.iban) == 'ES12 3456 7890 1234 5678 9012' && cell(ArtistCols.name) == 'Jumbo Press',
      ImportFileKind.products => cell(ProductCols.artist) == 'Jumbo Press' &&
          cell(ProductCols.product) == 'Risograph Poster' &&
          cell(ProductCols.stock) == '4' &&
          cell(TemplateColumn('Design')) == 'Bathroom',
      ImportFileKind.pastSales => cell(SaleCols.receipt) == 'T-1024' && cell(SaleCols.artist) == 'Jumbo Press',
    };
