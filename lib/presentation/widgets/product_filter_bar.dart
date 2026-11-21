import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/artist.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_filter.dart';
import '../providers.dart';
import '../theme/app_tokens.dart';
import 'category_tabs.dart';
import 'responsive_fields.dart';
import 'search_field.dart';

/// Search box and artist list, with the category tabs underneath (Sell and
/// Inventory). With a category chosen, the artist list only offers artists
/// who have products in it.
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
    final allArtists = ref.watch(artistsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    // A filter whose category was deleted falls back to "All".
    final categoryId = categories.any((c) => c.id == filter.categoryId) ? filter.categoryId : null;
    // Every product (shared with an unfiltered list), to see who has what.
    final products = ref.watch(productsProvider(const ProductFilter())).valueOrNull;
    final artists = artistsWithProductsIn(products, categoryId, allArtists);
    final artistId = artists.any((a) => a.id == filter.artistId) ? filter.artistId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveFields(
          minRowWidth: AppLayout.filterRowMin,
          flex: const [3, 2],
          children: [
            SearchField(
              hint: searchHint,
              onChanged: (v) => onChanged(ProductFilter(query: v, artistId: artistId, categoryId: categoryId)),
            ),
            DropdownButtonFormField<int?>(
              // The key refreshes the field when the list changes or the choice is reset.
              key: ValueKey(('artist', artistId, categoryId, artists.length)),
              initialValue: artistId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Artist'),
              items: [
                DropdownMenuItem(
                    value: null, child: Text(categoryId == null ? 'All artists' : 'All artists in this category')),
                for (final a in artists)
                  DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => onChanged(ProductFilter(query: filter.query, artistId: v, categoryId: categoryId)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        CategoryTabs(
          selectedId: categoryId,
          onChanged: (id) {
            // Keep the artist only if they have products in the new category.
            final stillThere = artistsWithProductsIn(products, id, allArtists).any((a) => a.id == artistId);
            onChanged(ProductFilter(query: filter.query, artistId: stillThere ? artistId : null, categoryId: id));
          },
        ),
      ],
    );
  }
}

/// [artists] who have at least one product in the category; all of them when
/// [categoryId] is null (or while the products are still loading).
List<Artist> artistsWithProductsIn(List<Product>? products, int? categoryId, List<Artist> artists) {
  if (categoryId == null || products == null) return artists;
  final ids = {for (final p in products) if (p.categoryId == categoryId) p.artistId};
  return artists.where((a) => ids.contains(a.id)).toList();
}
