import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/repositories/report_repository.dart';
import '../../providers.dart';
import '../../services/export_service.dart';
import '../../services/pdf_service.dart';
import '../common.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int months) => setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(monthlyReportProvider(_month));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Reports',
          actions: [
            IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
            Text(formatMonth(_month), style: Theme.of(context).textTheme.titleMedium),
            IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
            OutlinedButton.icon(
              onPressed: report.valueOrNull == null ? null : () => ExportService.shareMonthlyReportCsv(report.value!),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('CSV'),
            ),
            FilledButton.icon(
              onPressed: report.valueOrNull == null
                  ? null
                  : () async {
                      final store = await ref.read(storeInfoProvider.future);
                      final bytes = await PdfService.monthlyReport(report.value!, store);
                      await PdfService.share(bytes,
                          'report_${_month.year}-${_month.month.toString().padLeft(2, '0')}.pdf');
                    },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF'),
            ),
          ],
        ),
        Expanded(child: AsyncView(value: report, builder: (r) => _ReportBody(report: r))),
      ],
    );
  }
}

class _ReportBody extends StatelessWidget {
  final MonthlyReport report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    final r = report;
    if (r.orderCount == 0 && r.refundsCents == 0) {
      return const EmptyState(icon: Icons.insights_outlined, message: 'No sales this month');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Kpi('Store profit', formatCents(r.profitCents), highlight: true),
            _Kpi('Revenue (incl. tax)', formatCents(r.revenueCents)),
            _Kpi('Artist payouts', formatCents(r.artistPayoutCents + r.artistResidentTaxCents)),
            _Kpi('VAT collected', formatCents(r.vatCents)),
            _Kpi('Orders', '${r.orderCount}'),
            _Kpi('Units sold', '${r.unitsSold}'),
            _Kpi('Avg days to sell', r.avgDaysToSell?.toStringAsFixed(1) ?? '—'),
            if (r.refundsCents > 0) _Kpi('Refunds', formatCents(r.refundsCents)),
            if (r.discountCents > 0) _Kpi('Discounts', formatCents(r.discountCents)),
          ],
        ),
        const SizedBox(height: 24),
        _Panel(
          title: 'Revenue per day',
          child: SizedBox(
            height: 200,
            child: _Bars(
              values: r.revenueByDay,
              label: (i) => '${i + 1}',
              labelEvery: 5,
              tooltip: (i, v) => '${formatDate(r.range.start.add(Duration(days: i)))}\n${formatCents(v)}',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Panel(
                title: 'Best hours (revenue by hour of day)',
                child: SizedBox(
                  height: 200,
                  child: _Bars(
                    values: _trimHours(r.revenueByHour).values,
                    label: (i) => '${_trimHours(r.revenueByHour).first + i}h',
                    labelEvery: 2,
                    tooltip: (i, v) {
                      final h = _trimHours(r.revenueByHour).first + i;
                      return '${h.toString().padLeft(2, '0')}:00–${(h + 1).toString().padLeft(2, '0')}:00\n'
                          '${formatCents(v)} · ${r.ordersByHour[h]} orders';
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Panel(
                title: 'Revenue by weekday',
                child: SizedBox(
                  height: 200,
                  child: _Bars(
                    values: r.revenueByWeekday,
                    label: (i) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                    tooltip: (i, v) => formatCents(v),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Panel(title: 'By category', child: _BreakdownBars(r.byCategory))),
            const SizedBox(width: 16),
            Expanded(child: _Panel(title: 'By artist gender', child: _BreakdownBars(r.byGender))),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(title: 'By artist', child: _BreakdownBars(r.byArtist)),
        const SizedBox(height: 16),
        _Panel(
          title: 'Best-selling products',
          child: _SimpleTable(
            headers: const ['Product', 'Units', 'Revenue', 'Profit'],
            rows: [
              for (final b in r.topProducts)
                [b.label, '${b.units}', formatCents(b.revenueCents), formatCents(b.profitCents)],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Turnover by category',
          subtitle: 'Sell-through = units sold this month ÷ (sold + still in stock)',
          child: _SimpleTable(
            headers: const ['Category', 'Sold', 'In stock now', 'Sell-through', 'Avg days to sell'],
            rows: [
              for (final t in r.turnover)
                [
                  t.category,
                  '${t.soldUnits}',
                  '${t.inStockUnits}',
                  '${(t.sellThrough * 100).toStringAsFixed(0)}%',
                  t.avgDaysToSell?.toStringAsFixed(1) ?? '—',
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Panel(
                title: 'Fastest sellers',
                subtitle: 'Days from arrival to sale',
                child: _SimpleTable(
                  headers: const ['Product', 'Days', 'Units'],
                  rows: [
                    for (final s in r.fastestSellers)
                      ['${s.productName}\n${s.artistName}', s.days.toStringAsFixed(1), '${s.units}'],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _Panel(
                title: 'Longest on display',
                subtitle: 'Unsold stock, days since arrival',
                child: _SimpleTable(
                  headers: const ['Product', 'Days', 'Units'],
                  rows: [
                    for (final s in r.longestOnDisplay)
                      ['${s.productName}\n${s.artistName}', s.days.toStringAsFixed(0), '${s.units}'],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Opening hours only: from the first to the last hour with sales.
  static ({int first, List<int> values}) _trimHours(List<int> byHour) {
    var first = byHour.indexWhere((v) => v > 0);
    var last = byHour.lastIndexWhere((v) => v > 0);
    if (first < 0) {
      first = 10;
      last = 20;
    }
    return (first: first, values: byHour.sublist(first, last + 1));
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _Kpi(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 190,
      child: Card(
        color: highlight ? scheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Panel({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null)
              Text(subtitle!, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Single-series bar chart (one colour) with a tooltip on touch.
class _Bars extends StatelessWidget {
  final List<int> values;
  final String Function(int index) label;
  final String Function(int index, int value) tooltip;
  final int labelEvery;
  const _Bars({required this.values, required this.label, required this.tooltip, this.labelEvery = 1});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = values.fold(0, (m, v) => v > m ? v : m);
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 10);
    return BarChart(
      BarChartData(
        maxY: maxV == 0 ? 1 : maxV * 1.1,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (v, meta) =>
                  v == meta.max ? const SizedBox.shrink() : Text('${(v / 100).round()} €', style: muted),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i % labelEvery != 0 || i >= values.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 4), child: Text(label(i), style: muted));
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              tooltip(group.x, values[group.x]),
              TextStyle(color: scheme.onInverseSurface, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: values[i].toDouble(),
                color: scheme.primary,
                width: values.length > 20 ? 8 : 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]),
        ],
      ),
    );
  }
}

/// Horizontal bars for a breakdown (revenue), with units and profit as text.
class _BreakdownBars extends StatelessWidget {
  final List<Breakdown> items;
  const _BreakdownBars(this.items);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) return const Text('No data');
    final maxV = items.fold(0, (m, b) => b.revenueCents > m ? b.revenueCents : m);
    return Column(
      children: [
        for (final b in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(width: 130, child: Text(b.label, overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 14,
                        width: maxV <= 0 ? 0 : (c.maxWidth * b.revenueCents / maxV).clamp(0.0, c.maxWidth),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 170,
                  child: Text('${formatCents(b.revenueCents)} · ${b.units} u · profit ${formatCents(b.profitCents)}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant), textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SimpleTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  const _SimpleTable({required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('No data');
    final head = Theme.of(context).textTheme.labelMedium;
    return Table(
      columnWidths: {0: const FlexColumnWidth(3), for (var i = 1; i < headers.length; i++) i: const FlexColumnWidth(1)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          for (var i = 0; i < headers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(headers[i], style: head, textAlign: i == 0 ? TextAlign.left : TextAlign.right),
            ),
        ]),
        for (final r in rows)
          TableRow(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
            children: [
              for (var i = 0; i < r.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(r[i], textAlign: i == 0 ? TextAlign.left : TextAlign.right),
                ),
            ],
          ),
      ],
    );
  }
}
