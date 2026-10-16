import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../../services/export_service.dart';
import '../common.dart';
import 'product_form_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _query = '';
  int? _artistId;
  int? _categoryId;

  @override
  Widget build(BuildContext context) {
    final filter = ProductFilter(query: _query, artistId: _artistId, categoryId: _categoryId);
    final products = ref.watch(productsProvider(filter));
    final artists = ref.watch(artistsProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Inventory',
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                final all = await ref.read(inventoryRepoProvider).products();
                await ExportService.shareInventoryCsv(all);
              },
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export CSV'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Log product'),
            ),
          ],
          bottom: Row(
            children: [
              Expanded(
                flex: 3,
                child: SearchField(
                  hint: 'Search by product or artist',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int?>(
                  value: _artistId,
                  decoration: const InputDecoration(labelText: 'Artist'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All artists')),
                    for (final a in artists) DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _artistId = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int?>(
                  value: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All categories')),
                    for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView(
            value: products,
            builder: (list) {
              if (list.isEmpty) {
                return const EmptyState(icon: Icons.inventory_2_outlined, message: 'No products found');
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _ProductCard(product: list[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final p = product;
    final priceText = p.perVariantPricing && p.variants.length > 1
        ? 'Price varies'
        : '${formatCents(p.basePriceCents)} + ${formatPercent(p.taxPercent)} = '
            '${formatCents(p.variants.isEmpty ? p.basePriceCents : p.priceWithTaxFor(p.variants.first))}';

    return Card(
      color: p.isOutOfStock ? scheme.errorContainer.withValues(alpha: 0.35) : null,
      child: ExpansionTile(
        shape: const Border(),
        title: Row(
          children: [
            Flexible(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            if (p.isOutOfStock)
              Tag('Out of stock', color: scheme.error, icon: Icons.warning_amber_rounded)
            else
              Tag('${p.totalStock} in stock', color: scheme.primary),
            if (!p.isOutOfStock && p.variants.any((v) => v.quantity == 0)) ...[
              const SizedBox(width: 6),
              Tag('Some variants sold out', color: Colors.orange.shade800),
            ],
          ],
        ),
        subtitle: Text('${p.artistName} · ${p.categoryName} · $priceText'
            '${p.taxPercentOverride != null ? ' (custom tax)' : ''}'),
        trailing: IconButton(
          tooltip: 'Edit product',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductFormScreen(productId: p.id)),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.6),
              3: FlexColumnWidth(1.6),
              4: IntrinsicColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: ['Variant', 'Stock', 'Price (incl. tax)', 'Arrived', '']
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(h, style: Theme.of(context).textTheme.labelMedium),
                        ))
                    .toList(),
              ),
              for (final v in p.variants)
                TableRow(children: [
                  Text(v.label),
                  Text(
                    '${v.quantity}',
                    style: TextStyle(
                      color: v.quantity == 0 ? scheme.error : null,
                      fontWeight: v.quantity == 0 ? FontWeight.w700 : null,
                    ),
                  ),
                  Text(formatCents(p.priceWithTaxFor(v))),
                  Text(formatDate(v.dateOfArrival)),
                  TextButton.icon(
                    onPressed: () => _restock(context, ref, v),
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: const Text('Restock'),
                  ),
                ]),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _restock(BuildContext context, WidgetRef ref, Variant v) async {
    final qty = TextEditingController(text: '1');
    var date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Restock ${product.name} · ${v.label}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Units to add'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date of arrival'),
                subtitle: Text('${formatDate(date)} (replaces the previous date)'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final d = await pickDate(ctx, date);
                  if (d != null) setLocal(() => date = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add stock')),
          ],
        ),
      ),
    );
    final n = int.tryParse(qty.text.trim());
    qty.dispose();
    if (ok != true) return;
    if (n == null || n <= 0) {
      if (context.mounted) showMessage(context, 'Enter a whole number above 0', error: true);
      return;
    }
    await ref.read(inventoryRepoProvider).restock(v.id!, n, date);
    refreshData(ref);
  }
}
