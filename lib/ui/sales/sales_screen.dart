import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../models/date_range.dart';
import '../../models/order_filter.dart';
import '../../models/order_status.dart';
import '../../models/sale_order.dart';
import '../../providers.dart';
import '../../services/export_service.dart';
import '../../services/pdf_service.dart';
import '../common.dart';
import '../responsive.dart';

/// Sales history: refunds, receipts and tagging sales with workshop sessions.
class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  late DateRange _range = DateRange.month(DateTime.now().year, DateTime.now().month);
  String _query = '';

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _range.start, end: _range.lastDay),
    );
    if (picked != null) setState(() => _range = DateRange.days(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider(OrderFilter(range: _range, query: _query)));
    final pad = context.pagePadding;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Sales',
          actions: [
            OutlinedButton.icon(onPressed: _pickRange, icon: const Icon(Icons.date_range), label: Text(_range.label)),
            AdaptiveButton(
              icon: Icons.file_download_outlined,
              label: 'Export CSV',
              onPressed: () async =>
                  ExportService.exportSalesCsv(await ref.read(salesRepoProvider).orders(range: _range), _range),
            ),
          ],
          bottom: SearchField(hint: 'Search by product', onChanged: (v) => setState(() => _query = v)),
        ),
        Expanded(
          child: AsyncView(
            value: orders,
            builder: (list) {
              if (list.isEmpty) {
                return const EmptyState(icon: Icons.receipt_long_outlined, message: 'No sales in this period');
              }
              final total = list.fold(0, (s, o) => s + o.totalCents);
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
                itemCount: list.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => i == 0
                    ? Text('${list.length} sales · ${formatCents(total)} (before refunds)',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline))
                    : OrderCard(order: list[i - 1]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class OrderCard extends ConsumerWidget {
  final SaleOrder order;
  const OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = order;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        title: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${o.number} · ${formatDateTime(o.createdAt)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (o.status != OrderStatus.completed) Tag(o.status.label, color: scheme.error),
            if (o.calendarEventTitle != null) Tag(o.calendarEventTitle!, color: Colors.deepPurple, icon: Icons.event),
          ],
        ),
        subtitle: Text('${o.units} item(s) · ${o.paymentMethod}'
            '${o.discountName != null ? ' · ${o.discountName} discount' : ''}'),
        trailing: Text(formatCents(o.totalCents), style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final i in o.items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${i.productName} · ${i.variantLabel}'),
              subtitle: Text('${i.quantity} × ${formatCents(i.unitBaseCents)} before tax · tax ${formatPercent(i.taxPercent)}'
                  '${i.refundedQuantity > 0 ? ' · ${i.refundedQuantity} refunded' : ''}'),
              trailing: Text(formatCents(i.totalCents)),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final store = await ref.read(storeInfoProvider.future);
                    await PdfService.deliver(await PdfService.receipt(o, store), 'receipt_${o.id}.pdf');
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Receipt PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _tagSession(context, ref),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(o.calendarEventId == null ? 'Tag workshop session' : 'Change session'),
                ),
                if (o.status != OrderStatus.refunded)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                    onPressed: () => _refund(context, ref),
                    icon: const Icon(Icons.undo),
                    label: const Text('Refund'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _tagSession(BuildContext context, WidgetRef ref) async {
    // Sessions from the same day first, then everything else.
    final all = await ref.read(calendarRepoProvider).sessions();
    final sameDay = all.where((s) => startOfDay(s.start) == startOfDay(order.createdAt)).toList();
    final others = all.where((s) => !sameDay.contains(s)).toList();
    if (!context.mounted) return;
    final result = await showDialog<_SessionChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Workshop session for this sale'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, const _SessionChoice(null)),
            child: const Text('No session'),
          ),
          if (sameDay.isNotEmpty) const _DialogLabel('Same day'),
          for (final s in sameDay)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, _SessionChoice(s.id)), child: Text(s.label)),
          if (others.isNotEmpty) const _DialogLabel('Other sessions'),
          for (final s in others.take(30))
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, _SessionChoice(s.id)), child: Text(s.label)),
          if (all.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No sessions yet. Sync Google Calendar or add one in Invoices → Workshop sessions.'),
            ),
        ],
      ),
    );
    if (result == null) return;
    await ref.read(salesRepoProvider).setSession(order.id, result.sessionId);
    refreshData(ref);
  }

  Future<void> _refund(BuildContext context, WidgetRef ref) async {
    final refundable = order.items.where((i) => i.refundableQuantity > 0).toList();
    final qty = {for (final i in refundable) i.id: 0};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Refund items from ${order.number}'),
          content: SizedBox(
            width: ctx.dialogWidth(480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final i in refundable)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${i.productName} · ${i.variantLabel}'),
                      subtitle: Text('${i.refundableQuantity} can be refunded'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: qty[i.id]! > 0 ? () => setLocal(() => qty[i.id] = qty[i.id]! - 1) : null,
                          ),
                          Text('${qty[i.id]}'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: qty[i.id]! < i.refundableQuantity
                                ? () => setLocal(() => qty[i.id] = qty[i.id]! + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text('Refunded items go back into stock immediately.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setLocal(() {
                for (final i in refundable) {
                  qty[i.id] = i.refundableQuantity;
                }
              }),
              child: const Text('Select all'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: qty.values.any((q) => q > 0) ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Refund'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await ref.read(salesRepoProvider).refund(order.id, qty);
    refreshData(ref);
    if (context.mounted) showMessage(context, 'Refund recorded and items returned to stock');
  }
}

class _SessionChoice {
  final int? sessionId;
  const _SessionChoice(this.sessionId);
}

class _DialogLabel extends StatelessWidget {
  final String text;
  const _DialogLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
      );
}
