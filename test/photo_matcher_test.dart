// Matching the Google Drive photo folders to products.

import 'package:entre_sales/domain/models/product.dart';
import 'package:entre_sales/domain/photos/photo_matcher.dart';
import 'package:entre_sales/presentation/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Product product(int id, String name, String artist, {String category = 'Clothes', bool photo = false}) => Product(
      id: id,
      name: name,
      artistId: id,
      artistName: artist,
      categoryId: 1,
      categoryName: category,
      categoryTaxPercent: 21,
      basePriceCents: 1000,
      perVariantPricing: false,
      artistCommissionPercent: 35,
      variants: const [],
      photoPath: photo ? 'products/$id/1.jpg' : null,
      thumbPath: photo ? 'products/$id/1_thumb.jpg' : null,
    );

void main() {
  final products = [
    product(1, 'Linen shirt', 'Ana Ruiz'),
    product(2, 'Tote - large', 'Bea'),
    product(3, 'Mug', 'Ramón Gil', category: 'Ceramics'),
    product(4, 'T-shirt', 'Cris'),
    product(5, 'Scarf', 'Dani', photo: true),
    product(6, 'Poster', 'Eva', category: 'Libros & Prints'),
  ];

  test('natural order: IMG_2 before IMG_10', () {
    final names = ['IMG_10.jpg', 'img_2.JPG', 'IMG_1.jpeg', 'a.png'];
    names.sort(PhotoMatcher.naturalCompare);
    expect(names, ['a.png', 'IMG_1.jpeg', 'img_2.JPG', 'IMG_10.jpg']);
  });

  test('folders are matched by "Product name - Artist name"', () {
    final plan = PhotoMatcher.plan([
      'Drive/Clothes/Linen shirt - Ana Ruiz/IMG_10.jpg',
      'Drive/Clothes/Linen shirt - Ana Ruiz/IMG_2.jpg',
      'Drive/Clothes/Linen shirt - Ana Ruiz/notes.txt',
      'Drive/Clothes/Linen shirt - Ana Ruiz/.DS_Store',
      // A dash inside the product name.
      'Drive/Accessories/Tote - large - Bea/front.png',
      // Capitals, accents, extra spaces and a long dash.
      'Drive/Ceramics/MUG  –  Ramon gil/photo.HEIC',
      // A hyphen without spaces.
      'Drive/Clothes/T-shirt - Cris/1.webp',
      // Already has a photo.
      'Drive/Clothes/Scarf - Dani/1.jpg',
      // Folder named the other way round.
      'Drive/Libros & Prints/Eva - Poster/b.jpg',
      // Matches nothing.
      'Drive/Clothes/Hat - Nobody/1.jpg',
      '__MACOSX/Drive/Clothes/Linen shirt - Ana Ruiz/._IMG_1.jpg',
    ], products);

    final chosen = {for (final m in plan.matches) m.product.id: m.file};
    expect(chosen[1], 'Drive/Clothes/Linen shirt - Ana Ruiz/IMG_2.jpg');
    expect(chosen[2], 'Drive/Accessories/Tote - large - Bea/front.png');
    expect(chosen[3], 'Drive/Ceramics/MUG  –  Ramon gil/photo.HEIC');
    expect(chosen[4], 'Drive/Clothes/T-shirt - Cris/1.webp');
    expect(chosen[6], 'Drive/Libros & Prints/Eva - Poster/b.jpg');
    expect(chosen.containsKey(5), isFalse);
    expect(plan.alreadyHavePhoto.map((p) => p.id), [5]);
    expect(plan.unmatchedFolders, ['Drive/Clothes/Hat - Nobody']);
    expect(plan.productsWithoutPhoto, isEmpty);
    expect(plan.ignoredFiles, 3);
  });

  test('products without a folder are listed; existing photos can be replaced', () {
    final plan = PhotoMatcher.plan(['Clothes/Scarf - Dani/1.jpg'], products, replaceExisting: true);
    expect(plan.matches.single.product.id, 5);
    expect(plan.productsWithoutPhoto.map((p) => p.id), containsAll([1, 2, 3, 4, 6]));
  });

  test('images straight inside a category folder match nothing', () {
    final plan = PhotoMatcher.plan(['Clothes/IMG_1.jpg', 'loose.jpg'], products);
    expect(plan.matches, isEmpty);
    expect(plan.unmatchedFolders, ['Clothes']);
    expect(plan.ignoredFiles, 1);
  });

  test('only image files count', () {
    expect(PhotoMatcher.isImage('a.JPG'), isTrue);
    expect(PhotoMatcher.isImage('a.heic'), isTrue);
    expect(PhotoMatcher.isImage('a.pdf'), isFalse);
    expect(PhotoMatcher.isImage('.jpg'), isFalse);
  });

  test('placeholder icons follow the category name', () {
    expect(CategoryIcon.iconFor('Food & Drink (0% VAT)'), Icons.local_cafe_outlined);
    expect(CategoryIcon.iconFor('jewellery'), Icons.diamond_outlined);
    expect(CategoryIcon.iconFor('Libros & Prints'), Icons.menu_book_outlined);
    expect(CategoryIcon.iconFor('Something new'), Icons.sell_outlined);
  });
}
