// The data import: reading Excel's CSV flavours, and checking the template
// tabs before anything is written.

import 'dart:convert';

import 'package:entre_sales/core/csv.dart';
import 'package:entre_sales/domain/import/data_importer.dart';
import 'package:entre_sales/domain/import/import_existing.dart';
import 'package:entre_sales/domain/import/import_plan.dart';
import 'package:entre_sales/domain/import/import_validator.dart';
import 'package:entre_sales/domain/models/category_attribute.dart';
import 'package:entre_sales/domain/models/product_category.dart';
import 'package:entre_sales/domain/repositories/import_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const categories = [
  ProductCategory(id: 1, name: 'Clothing', taxPercent: 21, attributes: [
    CategoryAttribute(name: 'Size', options: ['XS', 'XS/S', 'S', 'M', 'L', 'XL']),
    CategoryAttribute(name: 'Style'),
  ]),
  ProductCategory(id: 2, name: 'Books & Zines', taxPercent: 4, attributes: [CategoryAttribute(name: 'Language')]),
  ProductCategory(id: 3, name: 'Miscellaneous', taxPercent: 21),
];

ImportExisting existing({Set<String> artists = const {'ana'}, Set<String> products = const {}, Set<String> receipts = const {}}) =>
    ImportExisting(
      artistNames: artists,
      productKeys: products,
      categories: categories,
      discountNames: const ['Friends & Family'],
      importedReceipts: receipts,
    );

List<List<String>> csv(String text) => parseCsv(text);

// Headers exactly as the template's first row (Excel adds the " *").
const artistHeader = 'Artist name *;Spain resident *;Commission (%);Gender;Legal name;NIF / NIE / Tax ID;Address;IBAN;Bank';
const productHeader = 'Artist *;Product *;Category *;Size;Style;Design;Finish;Pattern;Scent;Language;Option;'
    'Price incl. VAT (€) *;Stock now *;Date arrived;Product commission (%);VAT (%) override';
const salesHeader = 'Receipt no. *;Date *;Time;Payment *;Artist *;Product *;Category *;Variant;Quantity *;'
    'Total before VAT (€) *;Total incl. VAT (€) *;VAT % (check);Discount;Commission (%)';

void main() {
  group('Reading CSV', () {
    test('semicolons, quotes, decimal commas and line breaks', () {
      final rows = csv('a;b;c\r\n"x; y";"say ""hi""";25,50\r\n');
      expect(rows, [
        ['a', 'b', 'c'],
        ['x; y', 'say "hi"', '25,50'],
      ]);
      expect(csv('a,b\n1,2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('Windows encoding and UTF-8 with BOM both give accents and €', () {
      final cp1252 = [0x80, 0x20, 0x43, 0x61, 0x66, 0xE9]; // "€ Café"
      expect(decodeCsvBytes(cp1252), '€ Café');
      expect(decodeCsvBytes([0xEF, 0xBB, 0xBF, ...utf8.encode('€ Café')]), '€ Café');
    });

    test('numbers, dates and times as Excel writes them', () {
      expect(parseFlexibleCents('25'), 2500);
      expect(parseFlexibleCents('25,5'), 2550);
      expect(parseFlexibleCents('1.234,50 €'), 123450);
      expect(parseFlexibleCents('1,234.50'), 123450);
      expect(parseFlexibleNumber('35%'), 35);
      expect(parseFlexibleDate('12/09/2026'), DateTime(2026, 9, 12));
      expect(parseFlexibleDate('2026-09-12'), DateTime(2026, 9, 12));
      expect(parseFlexibleDate('3/1/26'), DateTime(2026, 1, 3));
      expect(parseFlexibleDate('31/02/2026'), isNull);
      expect(parseFlexibleTime('17:42'), (17, 42));
      expect(parseFlexibleTime('9:05:30'), (9, 5));
      expect(parseYesNo('Sí'), isTrue);
      expect(normalizeHeader('Price incl. VAT (€) *'), 'priceinclvat');
    });
  });

  group('Checking the files', () {
    test('a clean set of files becomes a plan; the example row is skipped', () {
      final check = ImportValidator.check(
        artists: csv('$artistHeader\n'
            'Jumbo Press;Yes;;Female;Jumbo Press S.L.;B12345678;Calle Ejemplo 1;ES12 3456 7890 1234 5678 9012;Banco Ejemplo\n'
            'Favorite Child Collective;Yes;;Queer;;;;;\n'
            'Lola;no;40;;;;;;\n'),
        products: csv('$productHeader\n'
            'Favorite Child Collective;T Shirt;Clothing;M;Black;;;;;;;35;3;01/07/2026;;\n'
            'favorite child collective;T Shirt;clothing;l;Black;;;;;;;35;2;01/07/2026;;\n'
            'Lola;Zine;Books & Zines;;;;;;;Catalan;;10,40;5;;;\n'
            'Ana;Big lamp;Miscellaneous;;;;;;;;;121;1;;30;\n'),
        pastSales: csv('$salesHeader\n'
            'T-1;12/07/2026;17:42;Card;Favorite Child Collective;T Shirt;Clothing;Black · M;1;28,93;35;21%;;\n'
            'T-2;13/07/2026;;cash;Ana;Old tote;Miscellaneous;;2;38;45,98;21%;friends & family;40\n'
            'T-2;13/07/2026;;cash;Lola;Zine;Books & Zines;;1;10;10,40;4%;friends & family;\n'),
        existing: existing(),
      );
      expect(check.issues, isEmpty, reason: check.issues.join('\n'));
      expect(check.canImport(), isTrue);

      final plan = check.plan;
      expect(plan.artists.map((a) => a.name), ['Favorite Child Collective', 'Lola']);
      expect(plan.artists.last.isSpainResident, isFalse);
      expect(plan.artists.last.commissionPercent, 40);

      final shirt = plan.products.firstWhere((p) => p.name == 'T Shirt');
      expect(shirt.variants.map((v) => v.attributes), [
        {'Size': 'M', 'Style': 'Black'},
        {'Size': 'L', 'Style': 'Black'}, // option spelled as in the category
      ]);
      expect(shirt.basePriceCents, 2893); // 35 / 1.21
      expect(shirt.perVariantPricing, isFalse);
      expect(shirt.variants.first.dateOfArrival, DateTime(2026, 7, 1));
      expect(plan.products.firstWhere((p) => p.name == 'Zine').basePriceCents, 1000); // 10.40 / 1.04
      expect(plan.products.firstWhere((p) => p.name == 'Big lamp').commissionPercentOverride, 30);

      expect(plan.receipts.length, 2);
      final t2 = plan.receipts.last;
      expect(t2.paymentMethod, 'Cash');
      expect(t2.discountName, 'Friends & Family');
      expect(t2.at, DateTime(2026, 7, 13, 12, 0)); // no time → noon
      expect(t2.lines.map((l) => (l.baseCents, l.totalCents, l.commissionPercent)), [(3800, 4598, 40), (1000, 1040, null)]);
    });

    test('every problem is listed with its row, and nothing can be imported', () {
      final check = ImportValidator.check(
        artists: csv('$artistHeader\nAna;Yes;;;;;;;\nBea;maybe;120;Other;;;;;\nBea;Yes;;;;;;;\n'),
        products: csv('$productHeader\n'
            'Ana;Shirt;Clothing;XXL;;;;;;;;30;1;;;\n'
            'Ana;Shirt;Clothing;M;;Flowers;;;;;;30;x;;;\n'
            'Nobody;Cup;Kitchen;;;;;;;;;;2;;;\n'),
        pastSales: csv('$salesHeader\n'
            'T-9;45/13/2026;25:00;Bitcoin;Ana;Cup;Miscellaneous;;0;10;9;;Summer sale;\n'),
        existing: existing(products: {'ana|shirt'}),
      );
      final text = check.issues.map((i) => i.toString()).toList();
      expect(check.canImport(), isFalse);
      expect(text, containsAll([
        'Artists, row 2: Artist "Ana" already exists in the app.',
        'Artists, row 3: Spain resident must be Yes or No.',
        'Artists, row 3: Commission "120" must be a percentage from 0 to 100.',
        'Artists, row 3: Gender must be one of Male, Female, Queer (or empty).',
        'Artists, row 4: "Bea" is already on row 3 of this file.',
        'Products, row 2: Product "Shirt" by Ana already exists in the app.',
        'Products, row 2: Size "XXL" isn\'t one of XS, XS/S, S, M, L, XL.',
        'Products, row 3: Clothing has no Design field (it uses Size, Style).',
        'Products, row 3: Stock now must be a whole number (0 or more).',
        'Products, row 4: Artist "Nobody" is not in the app or the Artists file.',
        'Products, row 4: Unknown category "Kitchen".',
        'Past sales, row 2: Date "45/13/2026" isn\'t a date (day/month/year).',
        'Past sales, row 2: Time "25:00" isn\'t a time (e.g. 17:42).',
        'Past sales, row 2: Payment must be Cash or Card.',
        'Past sales, row 2: Unknown discount "Summer sale".',
        'Past sales, row 2: Quantity must be a whole number, 1 or more.',
        'Past sales, row 2: Total incl. VAT is smaller than the total before VAT.',
      ]));
    });

    test('lines of one receipt must agree on date, payment and discount', () {
      final check = ImportValidator.check(
        pastSales: csv('$salesHeader\n'
            'T-5;12/07/2026;10:00;Card;Ana;A;Miscellaneous;;1;10;12,10;;;\n'
            'T-5;12/07/2026;10:00;Cash;Ana;B;Miscellaneous;;1;10;12,10;;;\n'),
        existing: existing(),
      );
      expect(check.issues.single.toString(), 'Past sales, row 3: Payment differs from row 2 for receipt T-5.');
      expect(check.plan.receipts, isEmpty);
    });

    test('receipts already imported block the import unless skipped', () {
      final check = ImportValidator.check(
        pastSales: csv('$salesHeader\n'
            'T-1;12/07/2026;10:00;Card;Ana;A;Miscellaneous;;1;10;12,10;;;\n'
            'T-2;12/07/2026;11:00;Card;Ana;B;Miscellaneous;;1;10;12,10;;;\n'),
        existing: existing(receipts: {'T-1'}),
      );
      expect(check.errors, isEmpty);
      expect(check.alreadyImported.single.message, 'Receipt T-1 was already imported.');
      expect(check.canImport(), isFalse);
      expect(check.canImport(skipAlreadyImported: true), isTrue);
    });

    test('a file from the wrong tab is spotted', () {
      final check = ImportValidator.check(products: csv('$artistHeader\nAna;Yes;;;;;;;\n'), existing: existing());
      expect(check.issues.single.message, startsWith('Missing column(s): Artist, Product, Category'));
    });

    test('receipt numbers are read for the "already imported" lookup', () {
      expect(
        ImportValidator.receiptNumbers(csv('$salesHeader\nT-1;;;;;;;;;;;;;\nT-1;;;;;;;;;;;;;\nT-2;;;;;;;;;;;;;\n')),
        ['T-1', 'T-2'],
      );
    });
  });

  test('past sales go in batches; artists and products first', () async {
    final repo = _FakeImportRepository();
    final receipts = [
      for (var i = 0; i < 600; i++)
        ReceiptDraft(receipt: 'R$i', at: DateTime(2026, 7, 1), paymentMethod: 'Cash', lines: const []),
    ];
    final progress = <double>[];
    final summary = await DataImporter(repo).run(
      ImportPlan(artists: const [ArtistDraft(name: 'A', isSpainResident: true)], receipts: receipts),
      onProgress: progress.add,
    );
    expect(repo.calls, ['catalog', 'sales 250', 'sales 250', 'sales 100']);
    expect(summary.receipts, 600);
    expect(progress.last, 1);
  });
}

class _FakeImportRepository implements ImportRepository {
  final calls = <String>[];
  @override
  Future<Set<String>> importedReceipts(List<String> receipts) async => {};
  @override
  Future<void> importCatalog(List<ArtistDraft> artists, List<ProductDraft> products) async => calls.add('catalog');
  @override
  Future<int> importPastSales(List<ReceiptDraft> receipts, {bool skipExisting = false}) async {
    calls.add('sales ${receipts.length}');
    return receipts.length;
  }
}
