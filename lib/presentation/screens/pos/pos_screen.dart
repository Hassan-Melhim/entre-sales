import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../data/export/pdf_service.dart';
import '../../../domain/business_rules.dart';
import '../../../domain/exceptions.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_filter.dart';
import '../../../domain/models/variant.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/async_view.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_delivery.dart';
import '../../widgets/page_header.dart';
import '../../widgets/search_field.dart';
import '../../widgets/tag.dart';
import 'cart.dart';

/// Point of sale.
///
/// Wide screens: products on the left, the current sale on the right.
/// Narrow screens: products fill the screen and a bar at the bottom opens
/// the current sale as a sheet.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= AppLayout.posSideCartMin) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _productPicker()),
            const VerticalDivider(width: 1),
            SizedBox(
              width: c.maxWidth >= AppLayout.posWideCartMin ? AppSizes.cartPanelWide : AppSizes.cartPanel,
              child: const CartPanel(),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: _productPicker()), const _CartBar()],
      );
    });
  }

  Widget _productPicker() {
    final products = ref.watch(productsProvider(ProductFilter(query: _query)));
    final session = ref.watch(currentSessionProvider).valueOrNull;
    final pad = context.pagePadding;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Sell',
          actions: [
            if (session != null) Tag('Workshop now: ${session.title}', color: context.appColors.session, icon: Icons.event),
          ],
          bottom: SearchField(hint: 'Search product or artist', onChanged: (v) => setState(() => _query = v)),
        ),
        Expanded(
          child: AsyncView(
            value: products,
            builder: (list) {
              if (list.isEmpty) return const EmptyState(icon: Icons.search_off, message: 'No products found');
              return GridView.builder(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, AppSpacing.xl),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  // Two tiles across on phones, more as the screen grows.
                  maxCrossAxisExtent: context.isCompact ? AppSizes.productTileCompact : AppSizes.productTile,
                  mainAxisExtent: AppSizes.productTileHeight,
                  crossAxisSpacing: AppSpacing.s + AppSpacing.xxs,
                  mainAxisSpacing: AppSpacing.s + AppSpacing.xxs,
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
    final text = Theme.of(context).textTheme;
    final p = product;
    final out = p.isOutOfStock;
    return Card(
      color: out ? scheme.surfaceContainerHighest : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: out ? null : () => _pick(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
              Text(p.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.outline)),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.hasVaryingPrices ? 'from ${formatCents(p.lowestPriceWithTax)}' : formatCents(p.lowestPriceWithTax),
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Flexible(
                    child: out
                        ? Tag('Out of stock', color: scheme.error)
                        : Text('${p.totalStock} left',
                            overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: scheme.outline)),
                  ),
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
    final Variant? chosen = product.variants.length == 1
        ? product.variants.first
        : await showModalBottomSheet<Variant>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (ctx) => _VariantPicker(product: product),
          );
    if (chosen == null) return;
    if (chosen.quantity <= 0 || !notifier.add(product, chosen)) {
      if (context.mounted) showMessage(context, 'No more "${product.name} · ${chosen.label}" in stock', error: true);
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
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(context.pagePadding, 0, context.pagePadding, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: Theme.of(context).textTheme.titleLarge),
            Text('${product.artistName} · ${product.categoryName}', style: TextStyle(color: scheme.outline)),
            const SizedBox(height: AppSpacing.l),
            Wrap(
              spacing: AppSpacing.s + AppSpacing.xxs,
              runSpacing: AppSpacing.s + AppSpacing.xxs,
              children: [
                for (final v in product.variants)
                  Builder(builder: (context) {
                    final available = v.quantity - cart.quantityInCart(v.id!);
                    return ActionChip(
                      avatar: available > 0 ? null : Icon(Icons.block, size: AppSizes.iconSmall, color: scheme.error),
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

/// Narrow screens: summary of the current sale; tap to open it.
class _CartBar extends ConsumerWidget {
  const _CartBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.pagePadding, vertical: AppSpacing.s + AppSpacing.xxs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  cart.isEmpty ? 'No items yet' : '${cart.units} item(s) · ${formatCents(cart.totalCents)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  builder: (sheetContext) => FractionallySizedBox(
                    heightFactor: 0.92,
                    child: CartPanel(onClose: () => Navigator.pop(sheetContext)),
                  ),
                ),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Current sale'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The current sale: lines, discount, payment method and checkout.
class CartPanel extends ConsumerWidget {
  /// Set when shown in a sheet: called to close it after a completed sale.
  final VoidCallback? onClose;
  const CartPanel({super.key, this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final discounts = (ref.watch(discountsProvider).valueOrNull ?? []).where((d) => d.active).toList();
    final scheme = Theme.of(context).colorScheme;
    final amounts = cart.amounts;

    return Container(
      color: scheme.surfaceContainerLow,
      child: LayoutBuilder(
        builder: (context, c) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.l + AppSpacing.xs, AppSpacing.l, AppSpacing.m, AppSpacing.s),
              child: Row(
                children: [
                  Expanded(child: Text('Current sale', style: Theme.of(context).textTheme.titleLarge)),
                  if (!cart.isEmpty) TextButton(onPressed: notifier.clear, child: const Text('Clear')),
                ],
              ),
            ),
            Expanded(
              child: cart.isEmpty
                  ? const EmptyState(icon: Icons.shopping_bag_outlined, message: 'Tap a product to add it')
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                      itemCount: cart.lines.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final l = cart.lines[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                          title: Text(l.product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${l.variant.label} · tax ${formatPercent(l.product.taxPercent)}\n'
                              '${formatCents(amounts[i].totalCents)}'),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => notifier.setQuantity(i, l.quantity - 1),
                              ),
                              Text('${l.quantity}', style: Theme.of(context).textTheme.titleSmall),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  if (!notifier.setQuantity(i, l.quantity + 1)) {
                                    showMessage(context, 'Only ${l.variant.quantity} in stock', error: true);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            // Totals take their natural height, but never more than 60% of
            // the panel; they scroll on short screens.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: c.maxHeight * 0.6),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.l + AppSpacing.xs),
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
                    const SizedBox(height: AppSpacing.s),
                    _row(context, 'Subtotal before tax', formatCents(cart.grossBaseCents)),
                    if (cart.discountCents > 0) _row(context, 'Discount', '−${formatCents(cart.discountCents)}'),
                    for (final e in cart.taxByRate.entries)
                      _row(context, 'Tax ${formatPercent(e.key)}', formatCents(e.value)),
                    const SizedBox(height: AppSpacing.s),
                    _row(context, 'Total', formatCents(cart.totalCents), big: true),
                    const SizedBox(height: AppSpacing.m),
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
                    const SizedBox(height: AppSpacing.m),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppSizes.checkoutButtonHeight)),
                      onPressed: cart.isEmpty ? null : () => _checkout(context, ref),
                      icon: const Icon(Icons.check),
                      label: Text('Complete sale · ${formatCents(cart.totalCents)}'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool big = false}) {
    final style = big ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
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
    if (!ok || !context.mounted) return;

    // The app-level navigator stays valid even if this panel's sheet closes.
    final navigator = Navigator.of(context, rootNavigator: true);
    final success = context.appColors.success;
    try {
      final sales = ref.read(salesRepositoryProvider);
      final orderId = await sales.checkout(
          lines: cart.lines, paymentMethod: cart.paymentMethod, discount: cart.discount, saleRef: cart.saleRef);
      // Read everything needed before the panel may be closed.
      final order = await sales.order(orderId);
      final store = await ref.read(storeInfoProvider.future);
      ref.read(cartProvider.notifier).clear();
      refreshData(ref);
      onClose?.call();
      if (order == null || !navigator.mounted) return;

      await showDialog<void>(
        context: navigator.context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.check_circle, color: success, size: AppSizes.emptyStateIcon),
          title: Text('Sale ${order.number} recorded'),
          content: Text('${formatCents(order.totalCents)} · ${order.paymentMethod}'
              '${order.calendarEventTitle != null ? '\nTagged with session: ${order.calendarEventTitle}' : ''}'),
          actions: [
            TextButton.icon(
              onPressed: () async => deliverExport(await PdfService.receipt(order, store)),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Receipt PDF'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('New sale')),
          ],
        ),
      );
    } on InsufficientStockException catch (e) {
      refreshData(ref);
      if (!navigator.mounted) return;
      await showDialog<void>(
        context: navigator.context,
        builder: (ctx) => AlertDialog(
          title: const Text('Not enough stock'),
          content: Text(e.problems.join('\n')),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    }
  }
}
