import '../../core/csv.dart';
import '../business_rules.dart';
import '../models/product_category.dart';
import 'import_existing.dart';
import 'import_issue.dart';
import 'import_plan.dart';
import 'import_template.dart';

/// The outcome of checking the files: what would be imported, and every
/// problem found. Nothing is imported while there are problems.
class ImportCheck {
  final ImportPlan plan;
  final List<ImportIssue> issues;

  const ImportCheck(this.plan, this.issues);

  List<ImportIssue> get errors => issues.where((i) => !i.alreadyImported).toList();
  List<ImportIssue> get alreadyImported => issues.where((i) => i.alreadyImported).toList();

  /// [skipAlreadyImported]: the user chose to leave out receipts that are
  /// already in (to finish an interrupted import).
  bool canImport({bool skipAlreadyImported = false}) =>
      !plan.isEmpty && errors.isEmpty && (alreadyImported.isEmpty || skipAlreadyImported);
}

/// Reads the template CSVs (as rows of fields) and checks them against each
/// other and against what's already in the store.
class ImportValidator {
  ImportValidator._();

  /// The old receipt numbers in a Past sales file, to look up which are
  /// already imported before calling [check].
  static List<String> receiptNumbers(List<List<String>> rows) {
    final t = _Table.read(ImportFileKind.pastSales, rows, SaleCols.all, []);
    if (t == null) return const [];
    return {for (final r in t.rows) r.get(SaleCols.receipt)}.where((s) => s.isNotEmpty).toList();
  }

  static ImportCheck check({
    List<List<String>>? artists,
    List<List<String>>? products,
    List<List<String>>? pastSales,
    required ImportExisting existing,
  }) {
    final issues = <ImportIssue>[];
    final categories = {for (final c in existing.categories) c.name.toLowerCase(): c};

    final artistDrafts = artists == null ? <ArtistDraft>[] : _artists(artists, existing, issues);
    final knownArtists = {...existing.artistNames, for (final a in artistDrafts) a.name.toLowerCase()};
    // Names written as in the Artists tab / app, to keep the original spelling.
    final productDrafts =
        products == null ? <ProductDraft>[] : _products(products, existing, knownArtists, categories, issues);
    final receipts =
        pastSales == null ? <ReceiptDraft>[] : _sales(pastSales, existing, knownArtists, categories, issues);

    if (artists == null && products == null && pastSales == null) {
      issues.add(const ImportIssue(ImportFileKind.artists, null, 'Choose at least one file to import.'));
    }
    return ImportCheck(ImportPlan(artists: artistDrafts, products: productDrafts, receipts: receipts), issues);
  }

  // ------------------------------------------------------------- Artists

  static List<ArtistDraft> _artists(List<List<String>> rows, ImportExisting existing, List<ImportIssue> issues) {
    const kind = ImportFileKind.artists;
    final t = _Table.read(kind, rows, ArtistCols.all, issues);
    if (t == null) return [];
    final drafts = <ArtistDraft>[];
    final seen = <String, int>{};
    for (final r in t.rows) {
      void issue(String m) => issues.add(ImportIssue(kind, r.number, m));
      final name = r.get(ArtistCols.name);
      if (name.isEmpty) {
        issue('Artist name is missing.');
        continue;
      }
      final key = name.toLowerCase();
      if (seen.containsKey(key)) {
        issue('"$name" is already on row ${seen[key]} of this file.');
        continue;
      }
      seen[key] = r.number;
      if (existing.artistNames.contains(key)) issue('Artist "$name" already exists in the app.');

      final resident = parseYesNo(r.get(ArtistCols.resident));
      if (resident == null) issue('Spain resident must be Yes or No.');
      final commission = _percent(r.get(ArtistCols.commission), 'Commission', issue);
      final genderText = r.get(ArtistCols.gender);
      String? gender;
      if (genderText.isNotEmpty) {
        gender = BusinessRules.genders.where((g) => g.toLowerCase() == genderText.toLowerCase()).firstOrNull;
        if (gender == null) issue('Gender must be one of ${BusinessRules.genders.join(', ')} (or empty).');
      }
      drafts.add(ArtistDraft(
        name: name,
        isSpainResident: resident ?? true,
        commissionPercent: commission,
        gender: gender,
        legalName: r.optional(ArtistCols.legalName),
        taxId: r.optional(ArtistCols.taxId),
        address: r.optional(ArtistCols.address),
        iban: r.optional(ArtistCols.iban),
        bankName: r.optional(ArtistCols.bank),
      ));
    }
    return drafts;
  }

  // ------------------------------------------------------------ Products

  static List<ProductDraft> _products(
    List<List<String>> rows,
    ImportExisting existing,
    Set<String> knownArtists,
    Map<String, ProductCategory> categories,
    List<ImportIssue> issues,
  ) {
    const kind = ImportFileKind.products;
    final t = _Table.read(kind, rows, ProductCols.all, issues);
    if (t == null) return [];
    final today = DateTime.now();

    // Rows of the same artist + product are one product.
    final groups = <String, List<_Row>>{};
    for (final r in t.rows) {
      final artist = r.get(ProductCols.artist), product = r.get(ProductCols.product);
      if (artist.isEmpty || product.isEmpty) {
        issues.add(ImportIssue(kind, r.number, artist.isEmpty ? 'Artist is missing.' : 'Product name is missing.'));
        continue;
      }
      groups.putIfAbsent(ImportExisting.productKey(artist, product), () => []).add(r);
    }

    final drafts = <ProductDraft>[];
    for (final entry in groups.entries) {
      final first = entry.value.first;
      final artist = first.get(ProductCols.artist), name = first.get(ProductCols.product);
      void issueAt(_Row r, String m) => issues.add(ImportIssue(kind, r.number, m));
      final before = issues.length;

      if (!knownArtists.contains(artist.toLowerCase())) {
        issueAt(first, 'Artist "$artist" is not in the app or the Artists file.');
      }
      if (existing.productKeys.contains(entry.key)) issueAt(first, 'Product "$name" by $artist already exists in the app.');

      final category = categories[first.get(ProductCols.category).toLowerCase()];
      if (category == null) {
        issueAt(first, first.get(ProductCols.category).isEmpty
            ? 'Category is missing.'
            : 'Unknown category "${first.get(ProductCols.category)}".');
      }
      final commission = _percent(first.get(ProductCols.commission), 'Product commission', (m) => issueAt(first, m));
      final vatOverride = _percent(first.get(ProductCols.vat), 'VAT override', (m) => issueAt(first, m));
      for (final r in entry.value.skip(1)) {
        // The product-wide columns must agree on every row of the product.
        for (final col in [ProductCols.category, ProductCols.commission, ProductCols.vat]) {
          if (r.get(col).toLowerCase() != first.get(col).toLowerCase()) {
            issueAt(r, '${col.header} differs from row ${first.number} for the same product ("$name").');
          }
        }
      }
      if (category == null) continue;
      final vat = vatOverride ?? category.taxPercent;

      final variants = <(VariantDraft, int)>[]; // with its base price
      final seenCombos = <String, int>{};
      for (final r in entry.value) {
        void issue(String m) => issueAt(r, m);
        final attributes = <String, String>{};
        for (final a in category.attributes) {
          final col = ProductCols.fields.where((f) => f.key == normalizeHeader(a.name)).firstOrNull;
          final value = col == null ? '' : r.get(col);
          if (value.isEmpty) continue;
          if (a.options.isNotEmpty) {
            final match = a.options.where((o) => o.toLowerCase() == value.toLowerCase()).firstOrNull;
            if (match == null) {
              issue('${a.name} "$value" isn\'t one of ${a.options.join(', ')}.');
              continue;
            }
            attributes[a.name] = match;
          } else {
            attributes[a.name] = value;
          }
        }
        final used = {for (final a in category.attributes) normalizeHeader(a.name)};
        for (final col in ProductCols.fields) {
          if (r.get(col).isNotEmpty && !used.contains(col.key)) {
            issue('${category.name} has no ${col.header} field (it uses '
                '${category.attributes.isEmpty ? 'none' : category.attributes.map((a) => a.name).join(', ')}).');
          }
        }
        final combo = attributes.values.map((v) => v.toLowerCase()).join('|');
        if (seenCombos.containsKey(combo)) {
          issue(attributes.isEmpty
              ? 'Same product listed again (row ${seenCombos[combo]}) with no fields to tell them apart.'
              : 'Same variant (${attributes.values.join(' · ')}) as row ${seenCombos[combo]}.');
          continue;
        }
        seenCombos[combo] = r.number;

        final price = parseFlexibleCents(r.get(ProductCols.price));
        if (price == null || price <= 0) issue('Price incl. VAT is missing or not a number.');
        final stockValue = parseFlexibleNumber(r.get(ProductCols.stock));
        final stock = stockValue?.toInt();
        if (stockValue == null || stockValue < 0 || stockValue != stockValue.roundToDouble()) {
          issue('Stock now must be a whole number (0 or more).');
        }
        DateTime arrival = DateTime(today.year, today.month, today.day);
        final arrivedText = r.get(ProductCols.arrived);
        if (arrivedText.isNotEmpty) {
          final d = parseFlexibleDate(arrivedText);
          if (d == null) {
            issue('Date arrived "$arrivedText" isn\'t a date (day/month/year).');
          } else {
            arrival = d;
          }
        }
        if (price == null || price <= 0 || stock == null || stock < 0) continue;
        final base = (price / (1 + vat / 100)).round();
        variants.add((VariantDraft(attributes: attributes, quantity: stock, dateOfArrival: arrival), base));
      }
      if (issues.length > before || variants.isEmpty) continue;

      final basePrice = variants.first.$2;
      final perVariant = variants.any((v) => v.$2 != basePrice);
      drafts.add(ProductDraft(
        artistName: artist,
        name: name,
        categoryName: category.name,
        basePriceCents: basePrice,
        perVariantPricing: perVariant,
        taxPercentOverride: vatOverride,
        commissionPercentOverride: commission,
        variants: [
          for (final (v, base) in variants)
            VariantDraft(
              attributes: v.attributes,
              quantity: v.quantity,
              priceOverrideCents: perVariant ? base : null,
              dateOfArrival: v.dateOfArrival,
            ),
        ],
      ));
    }
    return drafts;
  }

  // ---------------------------------------------------------- Past sales

  static List<ReceiptDraft> _sales(
    List<List<String>> rows,
    ImportExisting existing,
    Set<String> knownArtists,
    Map<String, ProductCategory> categories,
    List<ImportIssue> issues,
  ) {
    const kind = ImportFileKind.pastSales;
    final t = _Table.read(kind, rows, SaleCols.all, issues);
    if (t == null) return [];

    final groups = <String, List<_Row>>{};
    for (final r in t.rows) {
      final receipt = r.get(SaleCols.receipt);
      if (receipt.isEmpty) {
        issues.add(ImportIssue(kind, r.number, 'Receipt no. is missing.'));
        continue;
      }
      groups.putIfAbsent(receipt, () => []).add(r);
    }

    final drafts = <ReceiptDraft>[];
    for (final MapEntry(key: receipt, value: lines) in groups.entries) {
      final first = lines.first;
      void issueAt(_Row r, String m) => issues.add(ImportIssue(kind, r.number, m));
      int errorCount() => issues.where((i) => !i.alreadyImported).length;
      final errorsBefore = errorCount();

      if (existing.importedReceipts.contains(receipt)) {
        issues.add(ImportIssue(kind, first.number, 'Receipt $receipt was already imported.', alreadyImported: true));
      }
      final date = parseFlexibleDate(first.get(SaleCols.date));
      if (date == null) issueAt(first, 'Date "${first.get(SaleCols.date)}" isn\'t a date (day/month/year).');
      var time = (12, 0);
      final timeText = first.get(SaleCols.time);
      if (timeText.isNotEmpty) {
        final parsed = parseFlexibleTime(timeText);
        if (parsed == null) {
          issueAt(first, 'Time "$timeText" isn\'t a time (e.g. 17:42).');
        } else {
          time = parsed;
        }
      }
      final payment = BusinessRules.paymentMethods
          .where((p) => p.toLowerCase() == first.get(SaleCols.payment).toLowerCase())
          .firstOrNull;
      if (payment == null) issueAt(first, 'Payment must be ${BusinessRules.paymentMethods.join(' or ')}.');
      String? discount;
      final discountText = first.get(SaleCols.discount);
      if (discountText.isNotEmpty) {
        discount = existing.discountNames.where((d) => d.toLowerCase() == discountText.toLowerCase()).firstOrNull;
        if (discount == null) issueAt(first, 'Unknown discount "$discountText".');
      }
      for (final r in lines.skip(1)) {
        for (final col in [SaleCols.date, SaleCols.time, SaleCols.payment, SaleCols.discount]) {
          if (r.get(col).toLowerCase() != first.get(col).toLowerCase()) {
            issueAt(r, '${col.header} differs from row ${first.number} for receipt $receipt.');
          }
        }
      }

      final drafts0 = <SaleLineDraft>[];
      for (final r in lines) {
        void issue(String m) => issueAt(r, m);
        final artist = r.get(SaleCols.artist), product = r.get(SaleCols.product);
        if (artist.isEmpty) {
          issue('Artist is missing.');
        } else if (!knownArtists.contains(artist.toLowerCase())) {
          issue('Artist "$artist" is not in the app or the Artists file.');
        }
        if (product.isEmpty) issue('Product is missing.');
        final category = categories[r.get(SaleCols.category).toLowerCase()];
        if (category == null) {
          issue(r.get(SaleCols.category).isEmpty
              ? 'Category is missing.'
              : 'Unknown category "${r.get(SaleCols.category)}".');
        }
        final qtyValue = parseFlexibleNumber(r.get(SaleCols.quantity));
        if (qtyValue == null || qtyValue < 1 || qtyValue != qtyValue.roundToDouble()) {
          issue('Quantity must be a whole number, 1 or more.');
        }
        final baseCents = parseFlexibleCents(r.get(SaleCols.before));
        final totalCents = parseFlexibleCents(r.get(SaleCols.incl));
        if (baseCents == null || baseCents < 0) issue('Total before VAT is missing or not a number.');
        if (totalCents == null || totalCents < 0) issue('Total incl. VAT is missing or not a number.');
        if (baseCents != null && totalCents != null && totalCents < baseCents) {
          issue('Total incl. VAT is smaller than the total before VAT.');
        }
        final commission = _percent(r.get(SaleCols.commission), 'Commission', issue);
        if (category == null || qtyValue == null || baseCents == null || totalCents == null) continue;
        drafts0.add(SaleLineDraft(
          artistName: artist,
          productName: product,
          categoryName: category.name,
          variant: r.get(SaleCols.variant),
          quantity: qtyValue.toInt(),
          baseCents: baseCents,
          totalCents: totalCents,
          commissionPercent: commission,
        ));
      }
      if (errorCount() > errorsBefore || date == null || payment == null) continue;
      drafts.add(ReceiptDraft(
        receipt: receipt,
        at: DateTime(date.year, date.month, date.day, time.$1, time.$2),
        paymentMethod: payment,
        discountName: discount,
        lines: drafts0,
      ));
    }
    return drafts;
  }

  /// Empty → null; else 0–100, or an issue.
  static double? _percent(String text, String what, void Function(String) issue) {
    if (text.isEmpty) return null;
    final v = parseFlexibleNumber(text);
    if (v == null || v < 0 || v > 100) {
      issue('$what "$text" must be a percentage from 0 to 100.');
      return null;
    }
    return v;
  }
}

// ------------------------------------------------------------------ Reading

/// One data row, read by column.
class _Row {
  final int number; // spreadsheet row (header = 1)
  final Map<String, int> _index;
  final List<String> _cells;
  _Row(this.number, this._index, this._cells);

  String get(TemplateColumn c) {
    final i = _index[c.key];
    return (i == null || i >= _cells.length) ? '' : _cells[i].trim();
  }

  String? optional(TemplateColumn c) {
    final v = get(c);
    return v.isEmpty ? null : v;
  }
}

class _Table {
  final List<_Row> rows;
  _Table(this.rows);

  /// Finds the columns by their headers; reports missing required ones.
  /// Skips empty rows and the template's example row.
  static _Table? read(ImportFileKind kind, List<List<String>> csv, List<TemplateColumn> columns, List<ImportIssue> issues) {
    final headerAt = csv.indexWhere((r) => r.any((c) => c.trim().isNotEmpty));
    if (headerAt < 0) {
      issues.add(ImportIssue(kind, null, 'The file is empty.'));
      return null;
    }
    final index = <String, int>{};
    final header = csv[headerAt];
    for (var i = 0; i < header.length; i++) {
      index.putIfAbsent(normalizeHeader(header[i]), () => i);
    }
    final missing = columns.where((c) => c.required && !index.containsKey(c.key)).map((c) => c.header).toList();
    if (missing.isNotEmpty) {
      issues.add(ImportIssue(kind, 1,
          'Missing column(s): ${missing.join(', ')}. Is this the ${kind.label} tab of the import template?'));
      return null;
    }
    final rows = <_Row>[];
    for (var i = headerAt + 1; i < csv.length; i++) {
      if (csv[i].every((c) => c.trim().isEmpty)) continue;
      final row = _Row(i + 1, index, csv[i]);
      if (rows.isEmpty && isTemplateExample(kind, row.get)) continue;
      rows.add(row);
    }
    return _Table(rows);
  }
}
