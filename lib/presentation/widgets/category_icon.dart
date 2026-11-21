import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// The placeholder shown for products without a photo: one icon per category.
class CategoryIcon extends StatelessWidget {
  final String categoryName;
  final double size;
  const CategoryIcon({super.key, required this.categoryName, this.size = AppSizes.photoList});

  /// Matched by the start of the category name, ignoring capitals, so
  /// "Food & Drink (0% VAT)" still finds the cup.
  static const _icons = <String, IconData>{
    'clothes': Icons.checkroom,
    'jewel': Icons.diamond_outlined,
    'accessor': Icons.shopping_bag_outlined,
    'ceramic': Icons.coffee_outlined,
    'home': Icons.chair_outlined,
    'libros': Icons.menu_book_outlined,
    'book': Icons.menu_book_outlined,
    'print': Icons.image_outlined,
    'goodies': Icons.card_giftcard,
    'conceptual': Icons.lightbulb_outline,
    'painting': Icons.palette_outlined,
    'food': Icons.local_cafe_outlined,
    'drink': Icons.local_cafe_outlined,
    'tbd': Icons.help_outline,
  };

  static IconData iconFor(String categoryName) {
    final name = categoryName.trim().toLowerCase();
    for (final e in _icons.entries) {
      if (name.startsWith(e.key)) return e.value;
    }
    return Icons.sell_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.s * 2),
      ),
      child: Icon(iconFor(categoryName), size: size * 0.5, color: scheme.onSurfaceVariant, semanticLabel: categoryName),
    );
  }
}
