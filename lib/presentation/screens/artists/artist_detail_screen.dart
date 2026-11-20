import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates.dart';
import '../../../core/money.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/product_filter.dart';
import '../../../domain/models/refunded_item.dart';
import '../../../domain/models/sale_order.dart';
import '../../../domain/models/sold_item.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/async_view.dart';
import '../../widgets/commission_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_row.dart';
import '../inventory/inventory_screen.dart';
import 'artists_screen.dart';

/// One artist: their details on top, then tabs with their products and
/// everything they have sold.
class ArtistDetailScreen extends ConsumerWidget {
  final int artistId;
  const ArtistDetailScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider);
    final artist = artists.valueOrNull?.where((a) => a.id == artistId).firstOrNull;

    if (artist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: artists.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(icon: Icons.person_off_outlined, message: 'This artist no longer exists'),
      );
    }

    final products = ref.watch(productsProvider(ProductFilter(artistId: artistId)));
    final productCount = products.valueOrNull?.length;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(artist.name),
          actions: [
            CommissionButton(
              percent: artist.effectiveCommission,
              isCustom: artist.hasCustomCommission,
              tooltip: 'Change ${artist.name}\'s commission',
              onPressed: () => editArtistCommission(context, ref, artist),
            ),
            IconButton(
              tooltip: 'Edit details',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showArtistForm(context, artist: artist),
            ),
            const SizedBox(width: AppSpacing.s),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(child: _Centered(child: _Details(artist))),
            SliverToBoxAdapter(
              child: _Centered(
                child: TabBar(
                  tabs: [
                    Tab(text: productCount == null ? 'Products' : 'Products ($productCount)'),
                    const Tab(text: 'Sales'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _Centered(
                child: AsyncView(
                  value: products,
                  builder: (list) => list.isEmpty
                      ? const EmptyState(icon: Icons.inventory_2_outlined, message: 'No products from this artist yet')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s),
                          itemBuilder: (_, i) => ProductCard(product: list[i]),
                        ),
                ),
              ),
              _Centered(child: _SalesTab(artistId: artistId)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps a readable width on wide screens, with the page's side padding.
class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentMax),
          child: Padding(padding: EdgeInsets.symmetric(horizontal: context.pagePadding), child: child),
        ),
      );
}

class _Details extends StatelessWidget {
  final Artist artist;
  const _Details(this.artist);

  @override
  Widget build(BuildContext context) {
    final a = artist;
    final rows = <(String, String)>[
      (
        'Commission',
        '${formatPercent(a.effectiveCommission)}${a.hasCustomCommission ? '' : ' (store default)'}',
      ),
      ('Residency', a.isSpainResident ? 'Spain resident' : 'Non-resident'),
      if (a.gender != null) ('Gender', a.gender!),
      if (a.legalName != null) ('Legal name', a.legalName!),
      if (a.taxId != null) ('NIF / Tax ID', a.taxId!),
      if (a.address != null) ('Address', a.address!),
      if (a.iban != null) ('IBAN', a.iban!),
      if (a.bankName != null) ('Bank', a.bankName!),
    ];
    // Two columns of details when there is room.
    final half = (rows.length / 2).ceil();
    final columns = context.isCompact ? [rows] : [rows.sublist(0, half), rows.sublist(half)];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xl),
              Expanded(child: Column(children: [for (final (l, v) in columns[i]) InfoRow(l, v)])),
            ],
          ],
        ),
      ),
    );
  }
}

/// Every item the artist has sold, and refunds, newest first, with totals.
class _SalesTab extends ConsumerWidget {
  final int artistId;
  const _SalesTab({required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(artistSalesProvider(artistId)),
      builder: (history) {
        if (history.sold.isEmpty && history.refunded.isEmpty) {
          return const EmptyState(icon: Icons.receipt_long_outlined, message: 'No sales yet');
        }
        final entries = <_Entry>[
          for (final s in history.sold) _Entry.sale(s),
          for (final r in history.refunded) _Entry.refund(r),
        ]..sort((a, b) => b.at.compareTo(a.at));

        int sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);
        final units = sum(history.sold.map((s) => s.quantity)) - sum(history.refunded.map((r) => r.quantity));
        final total = sum(history.sold.map((s) => s.totalCents)) - sum(history.refunded.map((r) => r.totalCents));
        final share =
            sum(history.sold.map((s) => s.artistPayoutCents)) - sum(history.refunded.map((r) => r.artistPayoutCents));

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: entries.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                child: Wrap(
                  spacing: AppSpacing.l,
                  runSpacing: AppSpacing.s,
                  children: [
                    _Figure('Items sold', '$units'),
                    _Figure('Sales incl. VAT', formatCents(total)),
                    _Figure('Artist share', formatCents(share)),
                  ],
                ),
              );
            }
            return _EntryTile(entries[i - 1]);
          },
        );
      },
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  const _Figure(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
        Text(value, style: theme.textTheme.titleLarge),
      ],
    );
  }
}

/// A sold item or a refund, for one list.
class _Entry {
  final DateTime at;
  final int orderId;
  final String product;
  final String variant;
  final int quantity;
  final int totalCents;
  final int shareCents;
  final bool isRefund;

  _Entry.sale(SoldItem s)
      : at = s.soldAt,
        orderId = s.orderId,
        product = s.productName,
        variant = s.variantLabel,
        quantity = s.quantity,
        totalCents = s.totalCents,
        shareCents = s.artistPayoutCents,
        isRefund = false;

  _Entry.refund(RefundedItem r)
      : at = r.refundedAt,
        orderId = r.orderId,
        product = r.productName,
        variant = r.variantLabel,
        quantity = r.quantity,
        totalCents = r.totalCents,
        shareCents = r.artistPayoutCents,
        isRefund = true;
}

class _EntryTile extends StatelessWidget {
  final _Entry e;
  const _EntryTile(this.e);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sign = e.isRefund ? '−' : '';
    final color = e.isRefund ? theme.colorScheme.error : null;
    final name = e.variant == 'Standard' ? e.product : '${e.product} · ${e.variant}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: e.isRefund ? Icon(Icons.undo, color: color) : null,
      title: Text('${e.isRefund ? 'Refund: ' : ''}$name', style: TextStyle(color: color)),
      subtitle: Text('${formatDateTime(e.at)} · ${SaleOrder.formatOrderNumber(e.orderId)} · $sign${e.quantity} pcs'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$sign${formatCents(e.totalCents)}', style: theme.textTheme.titleSmall?.copyWith(color: color)),
          Text('artist $sign${formatCents(e.shareCents)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}
