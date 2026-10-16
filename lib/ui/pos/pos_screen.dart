import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/business_rules.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/repositories/sales_repository.dart';
import '../../providers.dart';
import '../../services/pdf_service.dart';
import '../common.dart';
import 'cart.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _productPicker()),
        const VerticalDivider(width: 1),
        const SizedBox(width: 400, child: _CartPanel()),
      ],
    );
  }

  Widget _productPicker() {
    final products = ref.watch(productsProvider(ProductFilter(query: _query)));
    final session = ref.watch(currentSessionProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Sell',
          actions: [
            if (session != null)
              Tag('Workshop now: ${session.title}', color: Colors.deepPurple, icon: Icons.event),
          ],
          bottom: SearchField(hint: 'Search product or artist', onChanged: (v) => setState(() => _query = v)),
        ),
        Expanded(
          child: AsyncView(
            value: products,
            builder: (list) {
              if (list.isEmpty) return const EmptyState(icon: Icons.search_off, message: 'No products found');
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 120,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) => _ProductTile(product: list[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductTile extends ConsumerWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final p = product;
    final out = p.isOutOfStock;
    return Card(
      color: out ? scheme.surfaceContainerHighest : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: out ? null : () => _pick(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(p.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.outline)),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.perVariantPricing && p.variants.length > 1
                          ? 'from ${formatCents(p.variants.map(p.priceWithTaxFor).reduce((a, b) => a < b ? a : b))}'
                          : formatCents(p.variants.isEmpty ? 0 : p.priceWithTaxFor(p.variants.first)),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  out
                      ? Tag('Out of stock', color: scheme.error)
                      : Text('${p.totalStock} left', style: TextStyle(color: scheme.outline, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(cartProvider.notifier);
    final inStock = product.variants.where((v) => v.quantity > 0).toList();
    Variant? chosen;
    if (product.variants.length == 1) {
      chosen = product.variants.first;
    } else {
      chosen = await showModalBottomSheet<Variant>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => _VariantPicker(product: product),
      );
    }
    if (chosen == null) return;
    if (!inStock.contains(chosen) || !notifier.add(product, chosen)) {
      if (context.mounted) {
        showMessage(context, 'No more "${product.name} · ${chosen.label}" in stock', error: true);
      }
    }
  }
}

/// Shows every variant of a product with its stock, so the cashier can see
/// at a glance which sizes / languages are available.
class _VariantPicker extends ConsumerWidget {
  final Product product;
  const _VariantPicker({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: Theme.of(context).textTheme.titleLarge),
            Text('${product.artistName} · ${product.categoryName}', style: TextStyle(color: scheme.outline)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final v in product.variants)
                  Builder(builder: (context) {
                    final available = v.quantity - cart.quantityInCart(v.id!);
                    return ActionChip(
                      avatar: available > 0 ? null : Icon(Icons.block, size: 16, color: scheme.error),
                      label: Text('${v.label} · ${formatCents(product.priceWithTaxFor(v))} · '
                          '${available > 0 ? '$available left' : 'none left'}'),
                      onPressed: available > 0 ? () => Navigator.pop(context, v) : null,
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartPanel extends ConsumerWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final discounts = (ref.watch(discountsProvider).valueOrNull ?? []).where((d) => d.active).toList();
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
            child: Row(
              children: [
                Expanded(child: Text('Current sale', style: Theme.of(context).textTheme.titleLarge)),
                if (cart.lines.isNotEmpty)
                  TextButton(onPressed: notifier.clear, child: const Text('Clear')),
              ],
            ),
          ),
          Expanded(
            child: cart.lines.isEmpty
                ? const EmptyState(icon: Icons.shopping_bag_outlined, message: 'Tap a product to add it')
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: cart.lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final l = cart.lines[i];
                      final a = cart.amounts[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(l.product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${l.variant.label} · tax ${formatPercent(l.product.taxPercent)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => notifier.setQuantity(i, l.quantity - 1),
                            ),
                            Text('${l.quantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                if (!notifier.setQuantity(i, l.quantity + 1)) {
                                  showMessage(context, 'Only ${l.variant.quantity} in stock', error: true);
                                }
                              },
                            ),
                            SizedBox(
                              width: 72,
                              child: Text(formatCents(a.totalCents), textAlign: TextAlign.right),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Discounts: one at a time. More can be added in Settings.
                for (final d in discounts)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('${d.name} discount (${formatPercent(d.percent)})'),
                    value: cart.discount?.id == d.id,
                    onChanged: (on) => notifier.setDiscount(on == true ? d : null),
                  ),
                const SizedBox(height: 8),
                _row(context, 'Subtotal before tax', formatCents(cart.grossBaseCents)),
                if (cart.discountCents > 0) _row(context, 'Discount', '−${formatCents(cart.discountCents)}'),
                for (final e in cart.taxByRate.entries)
                  _row(context, 'Tax ${formatPercent(e.key)}', formatCents(e.value)),
                const SizedBox(height: 6),
                _row(context, 'Total', formatCents(cart.totalCents), big: true),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    for (final m in BusinessRules.paymentMethods)
                      ButtonSegment(
                        value: m,
                        label: Text(m),
                        icon: Icon(m == 'Cash' ? Icons.payments_outlined : Icons.credit_card),
                      ),
                  ],
                  selected: {cart.paymentMethod},
                  onSelectionChanged: (s) => notifier.setPayment(s.first),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: cart.lines.isEmpty ? null : () => _checkout(context, ref),
                  icon: const Icon(Icons.check),
                  label: Text('Complete sale · ${formatCents(cart.totalCents)}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool big = false}) {
    final style = big ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }

  Future<void> _checkout(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    final ok = await confirm(
      context,
      'Complete sale?',
      '${cart.units} item(s) · ${formatCents(cart.totalCents)} paid by ${cart.paymentMethod.toLowerCase()}'
          '${cart.discount != null ? '\n${cart.discount!.name} discount applied' : ''}',
      action: 'Complete sale',
    );
    if (!ok) return;
    try {
      final orderId = await ref.read(salesRepoProvider).checkout(
            lines: cart.lines,
            paymentMethod: cart.paymentMethod,
            discount: cart.discount,
          );
      ref.read(cartProvider.notifier).clear();
      refreshData(ref);
      if (context.mounted) await _showDone(context, ref, orderId);
    } on InsufficientStockException catch (e) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Not enough stock'),
            content: Text(e.problems.join('\n')),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
      refreshData(ref);
    }
  }

  Future<void> _showDone(BuildContext context, WidgetRef ref, int orderId) async {
    final order = await ref.read(salesRepoProvider).order(orderId);
    if (order == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        title: Text('Sale ${order.number} recorded'),
        content: Text('${formatCents(order.totalCents)} · ${order.paymentMethod}'
            '${order.calendarEventTitle != null ? '\nTagged with session: ${order.calendarEventTitle}' : ''}'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final store = await ref.read(storeInfoProvider.future);
              final bytes = await PdfService.receipt(order, store);
              await PdfService.share(bytes, 'receipt_${order.id}.pdf');
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Receipt PDF'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('New sale')),
        ],
      ),
    );
  }
}
