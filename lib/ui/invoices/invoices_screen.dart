import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/business_rules.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../data/repositories/report_repository.dart';
import '../../providers.dart';
import '../../services/export_service.dart';
import '../../services/pdf_service.dart';
import '../common.dart';
import '../sales/sales_screen.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(title: 'Invoices'),
          const TabBar(
            tabAlignment: TabAlignment.start,
            isScrollable: true,
            tabs: [Tab(text: 'Artist payouts'), Tab(text: 'Workshop sessions')],
          ),
          const Expanded(child: TabBarView(children: [_ArtistPayouts(), _Sessions()])),
        ],
      ),
    );
  }
}

// ============================================================ Artist payouts

enum _PeriodMode { biweekly, custom }

class _ArtistPayouts extends ConsumerStatefulWidget {
  const _ArtistPayouts();

  @override
  ConsumerState<_ArtistPayouts> createState() => _ArtistPayoutsState();
}

class _ArtistPayoutsState extends ConsumerState<_ArtistPayouts> {
  _PeriodMode _mode = _PeriodMode.biweekly;
  DateRange _biweekly = DateRange.biweeklyContaining(DateTime.now());
  DateTime _customEnd = DateTime.now();

  DateRange get _range => _mode == _PeriodMode.biweekly
      ? _biweekly
      : DateRange.daysEndingOn(_customEnd, BusinessRules.customPeriodDays);

  @override
  Widget build(BuildContext context) {
    final statements = ref.watch(statementsProvider(StatementRequest(_range)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<_PeriodMode>(
                segments: const [
                  ButtonSegment(value: _PeriodMode.biweekly, label: Text('1–15 / 16–end')),
                  ButtonSegment(value: _PeriodMode.custom, label: Text('15 days up to a date')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              if (_mode == _PeriodMode.biweekly) ...[
                IconButton(
                  onPressed: () => setState(() => _biweekly = _biweekly.previousBiweekly()),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(_range.label, style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  onPressed: () => setState(() => _biweekly = _biweekly.nextBiweekly()),
                  icon: const Icon(Icons.chevron_right),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await pickDate(context, _customEnd);
                    if (d != null) setState(() => _customEnd = d);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_range.label),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final list = await ref.read(statementsProvider(StatementRequest(_range)).future);
                  await ExportService.shareStatementsCsv(list, _range);
                },
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Export CSV'),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView(
            value: statements,
            builder: (list) {
              if (list.isEmpty) {
                return const EmptyState(icon: Icons.request_quote_outlined, message: 'No artist sales in this period');
              }
              final totalToPay = list.fold(0, (s, x) => s + x.netPayoutCents);
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${list.length} artist(s) · ${formatCents(totalToPay)} to pay in total',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                  ),
                  Card(
                    child: DataTable(
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(label: Text('Artist')),
                        DataColumn(label: Text('Units'), numeric: true),
                        DataColumn(label: Text('Sales before tax'), numeric: true),
                        DataColumn(label: Text('Commission'), numeric: true),
                        DataColumn(label: Text('Artist share'), numeric: true),
                        DataColumn(label: Text('Resident tax'), numeric: true),
                        DataColumn(label: Text('To pay'), numeric: true),
                      ],
                      rows: [
                        for (final s in list)
                          DataRow(
                            onSelectChanged: (_) => _openStatement(s),
                            cells: [
                              DataCell(Text(s.artist.name)),
                              DataCell(Text('${s.soldUnits}')),
                              DataCell(Text(formatCents(s.salesBaseCents))),
                              DataCell(Text(formatCents(s.commissionCents))),
                              DataCell(Text(formatCents(s.payoutCents))),
                              DataCell(Text(s.artist.isSpainResident ? formatCents(s.residentTaxCents) : '—')),
                              DataCell(Text(formatCents(s.netPayoutCents),
                                  style: const TextStyle(fontWeight: FontWeight.w700))),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _openStatement(ArtistStatement s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${s.artist.name} · ${s.range.label}'),
        content: SizedBox(
          width: 640,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final l in s.sales)
                ListTile(
                  dense: true,
                  title: Text('${l.productName} · ${l.variantLabel}'),
                  subtitle: Text('${formatDate(l.date)} · ${l.orderNumber} · ${l.quantity} × · '
                      '${formatCents(l.baseCents)} before tax − ${formatPercent(l.commissionPercent)}'),
                  trailing: Text(formatCents(l.payoutCents)),
                ),
              for (final l in s.refunds)
                ListTile(
                  dense: true,
                  title: Text('Refund: ${l.productName} · ${l.variantLabel}'),
                  subtitle: Text('${formatDate(l.date)} · ${l.orderNumber} · ${l.quantity} ×'),
                  trailing: Text('−${formatCents(l.payoutCents)}', style: const TextStyle(color: Colors.red)),
                ),
              const Divider(),
              ListTile(dense: true, title: const Text('Artist share'), trailing: Text(formatCents(s.payoutCents))),
              if (s.artist.isSpainResident)
                ListTile(
                  dense: true,
                  title: Text('Spain resident tax (${formatPercent(s.residentTaxPercent)}, '
                      '${BusinessRules.residentTaxAddedOnTop ? 'added' : 'withheld'})'),
                  trailing: Text(formatCents(s.residentTaxCents)),
                ),
              ListTile(
                title: const Text('Amount to pay', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text(formatCents(s.netPayoutCents), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton.icon(
            onPressed: () async {
              final store = await ref.read(storeInfoProvider.future);
              final bytes = await PdfService.artistStatement(s, store);
              final name = s.artist.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
              await PdfService.share(bytes, 'settlement_${name}_${s.range.start.year}-'
                  '${s.range.start.month.toString().padLeft(2, '0')}-${s.range.start.day.toString().padLeft(2, '0')}.pdf');
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Invoice PDF'),
          ),
        ],
      ),
    );
  }
}

// ========================================================= Workshop sessions

class _Sessions extends ConsumerStatefulWidget {
  const _Sessions();

  @override
  ConsumerState<_Sessions> createState() => _SessionsState();
}

class _SessionsState extends ConsumerState<_Sessions> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final n = await ref.read(calendarServiceProvider).sync();
      refreshData(ref);
      if (mounted) showMessage(context, 'Synced: $n workshop session(s) found');
    } catch (e) {
      if (mounted) showMessage(context, 'Calendar sync failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _addManual() async {
    final title = TextEditingController(text: 'Workshop');
    var day = DateTime.now();
    var start = const TimeOfDay(hour: 18, minute: 0);
    var end = const TimeOfDay(hour: 20, minute: 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add session by hand'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  trailing: Text(formatDate(day)),
                  onTap: () async {
                    final d = await pickDate(ctx, day);
                    if (d != null) setLocal(() => day = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Starts'),
                  trailing: Text(start.format(ctx)),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: start);
                    if (t != null) setLocal(() => start = t);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ends'),
                  trailing: Text(end.format(ctx)),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: end);
                    if (t != null) setLocal(() => end = t);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    final name = title.text.trim();
    title.dispose();
    if (ok != true) return;
    final s = DateTime(day.year, day.month, day.day, start.hour, start.minute);
    final e = DateTime(day.year, day.month, day.day, end.hour, end.minute);
    if (!e.isAfter(s)) {
      if (mounted) showMessage(context, 'The end time must be after the start time', error: true);
      return;
    }
    await ref.read(calendarRepoProvider).addManualSession(name.isEmpty ? 'Workshop' : name, s, e);
    await ref.read(calendarRepoProvider).autoTagSales();
    refreshData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _syncing ? null : _sync,
                icon: _syncing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync),
                label: const Text('Sync Google Calendar'),
              ),
              OutlinedButton.icon(onPressed: _addManual, icon: const Icon(Icons.add), label: const Text('Add by hand')),
            ],
          ),
        ),
        Expanded(
          child: AsyncView(
            value: sessions,
            builder: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.event_outlined,
                  message: 'No workshop sessions yet.\nSync Google Calendar (events with "workshop" in the title).',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = list[i];
                  return ListTile(
                    leading: Icon(s.googleId == null ? Icons.edit_calendar_outlined : Icons.event),
                    title: Text(s.title),
                    subtitle: Text('${formatDateTime(s.start)} – ${formatDateTime(s.end)}'
                        '${s.googleId == null ? ' · added by hand' : ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class SessionDetailScreen extends ConsumerWidget {
  final CalendarSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider(OrderFilter(sessionId: session.id)));
    return Scaffold(
      appBar: AppBar(
        title: Text(session.title),
        actions: [
          if (session.googleId == null)
            IconButton(
              tooltip: 'Delete session',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirm(context, 'Delete session?', 'Sales stay recorded but lose this tag.',
                    action: 'Delete')) {
                  return;
                }
                await ref.read(calendarRepoProvider).deleteSession(session.id!);
                refreshData(ref);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          FilledButton.icon(
            onPressed: () async {
              final list = await ref.read(salesRepoProvider).orders(sessionId: session.id);
              final store = await ref.read(storeInfoProvider.future);
              final bytes = await PdfService.sessionReport(session, list, store);
              await PdfService.share(bytes, 'session_${session.start.year}-${session.start.month}-${session.start.day}.pdf');
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Session invoice PDF'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: AsyncView(
        value: orders,
        builder: (list) {
          final total = list.fold(0, (s, o) => s + o.totalCents);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('${formatDateTime(session.start)} – ${formatDateTime(session.end)}'),
              const SizedBox(height: 4),
              Text('${list.length} sale(s) · ${formatCents(total)}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const Text('No sales tagged with this session. Tag sales from the Sales tab.')
              else
                for (final o in list) Padding(padding: const EdgeInsets.only(bottom: 8), child: OrderCard(order: o)),
            ],
          );
        },
      ),
    );
  }
}
