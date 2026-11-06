import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/product_filter.dart';
import '../providers.dart';
import '../theme/app_tokens.dart';
import 'responsive_fields.dart';
import 'search_field.dart';

/// Search box plus artist and category dropdowns (Sell and Inventory).
/// Side by side when there is room, stacked on narrow screens.
class ProductFilterBar extends ConsumerWidget {
  final ProductFilter filter;
  final ValueChanged<ProductFilter> onChanged;
  final String searchHint;

  const ProductFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    this.searchHint = 'Search by product or artist',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    // A filter whose artist/category was deleted falls back to "All".
    final artistId = artists.any((a) => a.id == filter.artistId) ? filter.artistId : null;
    final categoryId = categories.any((c) => c.id == filter.categoryId) ? filter.categoryId : null;

    return ResponsiveFields(
      minRowWidth: AppLayout.filterRowMin,
      flex: const [3, 2, 2],
      children: [
        SearchField(
          hint: searchHint,
          onChanged: (v) => onChanged(ProductFilter(query: v, artistId: artistId, categoryId: categoryId)),
        ),
        DropdownButtonFormField<int?>(
          // The key refreshes the field when the list loads or the choice is reset.
          key: ValueKey(('artist', artistId, artists.length)),
          initialValue: artistId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Artist'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All artists')),
            for (final a in artists) DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => onChanged(ProductFilter(query: filter.query, artistId: v, categoryId: categoryId)),
        ),
        DropdownButtonFormField<int?>(
          key: ValueKey(('category', categoryId, categories.length)),
          initialValue: categoryId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All categories')),
            for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => onChanged(ProductFilter(query: filter.query, artistId: artistId, categoryId: v)),
        ),
      ],
    );
  }
}
