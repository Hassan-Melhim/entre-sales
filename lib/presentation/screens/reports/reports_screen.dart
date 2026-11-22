import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../data/export/csv_export_service.dart';
import '../../../data/export/pdf_service.dart';
import '../../../domain/models/breakdown.dart';
import '../../../domain/models/report_period.dart';
import '../../../domain/models/sales_report.dart';
import '../../../domain/models/timeline_unit.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/adaptive_button.dart';
import '../../widgets/async_view.dart';
import '../../widgets/date_range_field.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/file_delivery.dart';
import '../../widgets/page_header.dart';
import '../../widgets/responsive_fields.dart';
import 'report_guide.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.containing(PeriodKind.month, DateTime.now());

  Future<void> _setKind(PeriodKind kind) async {
    if (kind == PeriodKind.allTime) {
      // From the first sale ever made (today if there are none yet).
      DateTime? first;
      try {
        first = await ref.read(salesRepositoryProvider).firstSaleAt();
      } catch (e) {
        if (mounted) showMessage(context, 'Could not find the first sale: $e', error: true);
        return;
      }
      if (mounted) setState(() => _period = ReportPeriod.allTime(first ?? DateTime.now()));
      return;
    }
    setState(() => _period = kind == PeriodKind.custom
        ? ReportPeriod.custom(_period.range)
        : ReportPeriod.containing(kind, _period.range.start));
  }

  Future<void> _jumpTo() async {
    final d = await pickDate(context, _period.range.start);
    if (d != null) setState(() => _period = ReportPeriod.containing(_period.kind, d));
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(salesReportProvider(_period));
    final r = report.valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Reports',
          actions: [
            IconButton(
              tooltip: 'What the figures mean',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showReportGuide(context),
            ),
            AdaptiveButton(
              icon: Icons.file_download_outlined,
              label: 'CSV',
              onPressed: r == null ? null : () => deliverExport(CsvExportService.salesReport(r)),
            ),
            AdaptiveButton(
              icon: Icons.picture_as_pdf_outlined,
              label: 'PDF',
              filled: true,
              onPressed: r == null
                  ? null
                  : () async => deliverExport(await PdfService.salesReport(r, await ref.read(storeInfoProvider.future))),
            ),
          ],
          bottom: _periodPicker(),
        ),
        Expanded(child: AsyncView(value: report, builder: (r) => _ReportBody(report: r))),
      ],
    );
  }

  Widget _periodPicker() {
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Chips wrap on narrow screens (a segmented button would overflow).
        for (final k in PeriodKind.values)
          ChoiceChip(label: Text(k.label), selected: _period.kind == k, onSelected: (_) => _setKind(k)),
        const SizedBox(width: AppSpacing.s),
        if (_period.canStep)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous',
                onPressed: () => setState(() => _period = _period.previous()),
                icon: const Icon(Icons.chevron_left),
              ),
              TextButton.icon(
                onPressed: _jumpTo,
                icon: const Icon(Icons.calendar_today_outlined, size: AppSizes.iconSmall),
                label: Text(_period.label, style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: () => setState(() => _period = _period.next()),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          )
        else if (_period.kind == PeriodKind.allTime)
          Text(_period.label, style: Theme.of(context).textTheme.titleMedium)
        else
          DateRangeField(
            value: _period.range,
            showShortcuts: false,
            onChanged: (range) => setState(() => _period = ReportPeriod.custom(range)),
          ),
      ],
    );
  }
}

class _ReportBody extends StatelessWidget {
  final SalesReport report;
  const _ReportBody({required this.report});

  /// Two panels side by side when there is room, stacked otherwise.
  static Widget _pair(Widget a, Widget b) =>
      ResponsiveFields(minRowWidth: AppLayout.reportPairMin, spacing: AppSpacing.l, children: [a, b]);

  @override
  Widget build(BuildContext context) {
    final r = report;
    if (r.isEmpty) return EmptyState(icon: Icons.insights_outlined, message: 'No sales in ${r.period.label}');
    final hours = _openHours(r.revenueByHour);
    final pad = context.pagePadding;
    final unit = r.period.timelineUnit;
    const gap = SizedBox(height: AppSpacing.l);

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, AppSpacing.xxl),
      children: [
        _KpiGrid(tiles: [
          _Kpi('Total sales', formatCents(r.revenueCents), note: 'what customers paid'),
          _Kpi('Store profit', formatCents(r.profitCents),
              highlight: true,
              note: r.marginPercent == null ? null : '${r.marginPercent!.toStringAsFixed(1)}% of sales before VAT'),
          _Kpi('Artist payouts', formatCents(r.artistPayoutCents)),
          _Kpi('Taxes', formatCents(r.taxesCents),
              note: 'VAT ${formatCents(r.vatCents)} · resident ${formatCents(r.artistResidentTaxCents)}'),
          _Kpi('Sales', '${r.orderCount}'),
          _Kpi('Units sold', '${r.unitsSold}'),
          _Kpi('Average sale', formatCents(r.averageSaleCents)),
          _Kpi('Items per sale', r.itemsPerSale.toStringAsFixed(1)),
          _Kpi('Avg days to sell', r.avgDaysToSell?.toStringAsFixed(1) ?? '—'),
          if (r.refundsCents > 0) _Kpi('Refunds', formatCents(r.refundsCents)),
          if (r.discountCents > 0) _Kpi('Discounts', formatCents(r.discountCents)),
        ]),
        const SizedBox(height: AppSpacing.xl),
        _Panel(
          title: 'Revenue ${unit.label}',
          child: SizedBox(
            height: AppSizes.chartHeight,
            child: _Bars(
              values: [for (final p in r.timeline) p.revenueCents],
              label: (i) => r.timeline[i].label,
              tooltip: (i, v) => '${r.timeline[i].longLabel}\n${formatCents(v)} · ${r.timeline[i].orders} orders',
            ),
          ),
        ),
        gap,
        // A single day already shows hours above, and only one weekday.
        if (unit != TimelineUnit.hour)
          _pair(
            _Panel(
              title: 'Best hours',
              subtitle: 'Revenue by hour of day',
              child: SizedBox(
                height: AppSizes.chartHeight,
                child: _Bars(
                  values: hours.values,
                  label: (i) => '${hours.first + i}h',
                  tooltip: (i, v) {
                    final h = hours.first + i;
                    return '${h.toString().padLeft(2, '0')}:00–${(h + 1).toString().padLeft(2, '0')}:00\n'
                        '${formatCents(v)} · ${r.ordersByHour[h]} orders';
                  },
                ),
              ),
            ),
            _weekdayPanel(r),
          ),
        if (unit != TimelineUnit.hour) gap,
        _pair(
          _Panel(title: 'By category', child: _BreakdownBars(r.byCategory)),
          _Panel(title: 'By artist gender', child: _BreakdownBars(r.byGender)),
        ),
        gap,
        _Panel(title: 'By artist', child: _BreakdownBars(r.byArtist)),
        gap,
        _Panel(
          title: 'Store profit by artist',
          subtitle: 'What each artist\'s sales left the store, after taxes and their payout',
          child: _BreakdownBars(r.byArtistProfit, byProfit: true),
        ),
        gap,
        _pair(_paymentsPanel(r), _sessionsPanel(r)),
        gap,
        _Panel(
          title: 'Best-selling products',
          child: _SimpleTable(
            headers: const ['Product', 'Units', 'Revenue', 'Profit'],
            rows: [
              for (final b in r.topProducts) [b.label, '${b.units}', formatCents(b.revenueCents), formatCents(b.profitCents)],
            ],
          ),
        ),
        gap,
        _Panel(
          title: 'Turnover by category',
          subtitle: 'Sell-through = units sold in this period ÷ (sold + still in stock)',
          child: _SimpleTable(
            headers: const ['Category', 'Sold', 'In stock', 'Sell-through', 'Avg days'],
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
        gap,
        _pair(
          _Panel(
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
          _Panel(
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
        gap,
        _stockPanel(context, r.stockValue),
      ],
    );
  }

  Widget _paymentsPanel(SalesReport r) {
    final total = r.payments.fold<int>(0, (s, p) => s + p.revenueCents);
    return _Panel(
      title: 'Cash and card',
      subtitle: 'Sales as rung up, before refunds',
      child: _SimpleTable(
        headers: const ['Paid by', 'Sales', 'Amount', 'Share'],
        rows: [
          for (final p in r.payments)
            [
              p.method,
              '${p.orders}',
              formatCents(p.revenueCents),
              total == 0 ? '—' : '${(p.revenueCents * 100 / total).toStringAsFixed(0)}%',
            ],
        ],
      ),
    );
  }

  Widget _sessionsPanel(SalesReport r) {
    final s = r.sessions;
    return _Panel(
      title: 'Workshops and events',
      subtitle: s.sessionCount == 0
          ? 'No sales during a workshop or event in this period'
          : 'Sales during ${s.sessionCount} session${s.sessionCount == 1 ? '' : 's'} vs. other times',
      child: _SimpleTable(
        headers: const ['When', 'Sales', 'Amount', 'Average sale'],
        rows: [
          ['During sessions', '${s.sessionOrders}', formatCents(s.sessionRevenueCents), formatCents(s.sessionAverageCents)],
          ['Other times', '${s.otherOrders}', formatCents(s.otherRevenueCents), formatCents(s.otherAverageCents)],
        ],
      ),
    );
  }

  Widget _stockPanel(BuildContext context, StockValue? v) {
    if (v == null) {
      return const _Panel(
        title: 'Stock on the shelf',
        child: Text('Run supabase/migrations/20261122120000_report_details.sql in the Supabase SQL Editor '
            'to see the value of the stock.'),
      );
    }
    return _Panel(
      title: 'Stock on the shelf (today)',
      subtitle: 'Everything in stock now, at today\'s prices, as if it all sold without discount',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _KpiGrid(tiles: [
            _Kpi('Units', '${v.units}'),
            _Kpi('Shelf value', formatCents(v.shelfCents), note: 'VAT included'),
            _Kpi('Store profit to come', formatCents(v.storeProfitCents), highlight: true),
            _Kpi('Artist payouts to come', formatCents(v.artistPayoutCents)),
          ]),
          const SizedBox(height: AppSpacing.m),
          _SimpleTable(
            headers: const ['Artist', 'Units', 'Shelf value', 'Store profit'],
            rows: [
              for (final a in v.byArtist.take(15))
                [a.artist, '${a.units}', formatCents(a.shelfCents), formatCents(a.storeProfitCents)],
            ],
          ),
          if (v.byArtist.length > 15)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s),
              child: Text('Top 15 of ${v.byArtist.length} artists by shelf value. The CSV has them all.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _weekdayPanel(SalesReport r) => _Panel(
        title: 'Revenue by weekday',
        child: SizedBox(
          height: AppSizes.chartHeight,
          child: _Bars(
            values: r.revenueByWeekday,
            label: (i) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
            tooltip: (i, v) => formatCents(v),
          ),
        ),
      );

  /// Opening hours only: from the first to the last hour with sales.
  static ({int first, List<int> values}) _openHours(List<int> byHour) {
    var first = byHour.indexWhere((v) => v > 0);
    var last = byHour.lastIndexWhere((v) => v > 0);
    if (first < 0) {
      first = 10;
      last = 20;
    }
    return (first: first, values: byHour.sublist(first, last + 1));
  }
}

class _Kpi {
  final String label;
  final String value;
  final bool highlight;

  /// A short line under the number.
  final String? note;
  const _Kpi(this.label, this.value, {this.highlight = false, this.note});
}

/// Headline numbers: as many per row as fit (at least two).
class _KpiGrid extends StatelessWidget {
  final List<_Kpi> tiles;
  const _KpiGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    const spacing = AppSpacing.m;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, c) {
      final perRow = math.max(2, (c.maxWidth / AppSizes.kpiMinWidth).floor());
      final width = (c.maxWidth - spacing * (perRow - 1)) / perRow;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final t in tiles)
            SizedBox(
              width: width,
              child: Card(
                color: t.highlight ? scheme.primaryContainer : null,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m + AppSpacing.xxs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: AppSpacing.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(t.value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      if (t.note != null)
                        Text(t.note!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Panel({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.isCompact ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleMedium),
            if (subtitle != null)
              Text(subtitle!, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: AppSpacing.m),
            child,
          ],
        ),
      ),
    );
  }
}

/// Single-series bar chart (one colour) with a tooltip on touch / hover.
/// Bars get thinner, and labels sparser, as the chart gets narrower.
class _Bars extends StatelessWidget {
  final List<int> values;
  final String Function(int index) label;
  final String Function(int index, int value) tooltip;
  const _Bars({required this.values, required this.label, required this.tooltip});

  /// Minimum room for one axis label.
  static const double _labelSlot = 28;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = values.fold<int>(0, (m, v) => v > m ? v : m);
    final muted = Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    return LayoutBuilder(builder: (context, c) {
      final plotWidth = c.maxWidth - AppSizes.chartAxisWidth;
      final slot = plotWidth / math.max(1, values.length);
      final barWidth = (slot * 0.6).clamp(3.0, 18.0);
      final labelEvery = math.max(1, (_labelSlot / slot).ceil());
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
                reservedSize: AppSizes.chartAxisWidth,
                getTitlesWidget: (v, meta) =>
                    v == meta.max ? const SizedBox.shrink() : Text('${(v / 100).round()} €', style: muted),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: AppSpacing.xl - AppSpacing.xxs,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i % labelEvery != 0 || i >= values.length) return const SizedBox.shrink();
                  return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs), child: Text(label(i), style: muted));
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                tooltip(group.x, values[group.x]),
                Theme.of(context).textTheme.bodySmall!.copyWith(color: scheme.onInverseSurface),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: values[i].toDouble(),
                  color: scheme.primary,
                  width: barWidth,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.s)),
                ),
              ]),
          ],
        ),
      );
    });
  }
}

/// Horizontal bars for a breakdown (revenue), with units and profit as text.
/// Wide: label | bar | numbers on one line. Narrow: label and numbers above the bar.
class _BreakdownBars extends StatelessWidget {
  final List<Breakdown> items;

  /// Bars sized by store profit instead of sales.
  final bool byProfit;
  const _BreakdownBars(this.items, {this.byProfit = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty) return const Text('No data');
    int size(Breakdown b) => byProfit ? b.profitCents : b.revenueCents;
    final maxV = items.fold<int>(0, (m, b) => size(b) > m ? size(b) : m);
    final numbersStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    const barHeight = AppSpacing.m + AppSpacing.xxs;

    Widget bar(Breakdown b) => LayoutBuilder(
          builder: (context, c) => Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: barHeight,
              width: maxV <= 0 ? 0 : (c.maxWidth * size(b) / maxV).clamp(0.0, c.maxWidth),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(AppRadius.s)),
              ),
            ),
          ),
        );

    String numbers(Breakdown b) => byProfit
        ? 'profit ${formatCents(b.profitCents)} · sales ${formatCents(b.revenueCents)}'
        : '${formatCents(b.revenueCents)} · ${b.units} u · profit ${formatCents(b.profitCents)}';

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= AppLayout.breakdownRowMin;
      return Column(
        children: [
          for (final b in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1),
              child: wide
                  ? Row(
                      children: [
                        SizedBox(width: AppSizes.breakdownLabel, child: Text(b.label, overflow: TextOverflow.ellipsis)),
                        Expanded(child: bar(b)),
                        const SizedBox(width: AppSpacing.s),
                        SizedBox(
                          width: AppSizes.breakdownNumbers,
                          child: Text(numbers(b), style: numbersStyle, textAlign: TextAlign.right),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(b.label, overflow: TextOverflow.ellipsis)),
                            Text(numbers(b), style: numbersStyle),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        bar(b),
                      ],
                    ),
            ),
        ],
      );
    });
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
      columnWidths: {0: const FlexColumnWidth(3), for (var i = 1; i < headers.length; i++) i: const FlexColumnWidth(1.2)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(children: [
          for (var i = 0; i < headers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s - AppSpacing.xxs, right: AppSpacing.xs),
              child: Text(headers[i], style: head, textAlign: i == 0 ? TextAlign.left : TextAlign.right),
            ),
        ]),
        for (final r in rows)
          TableRow(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
            children: [
              for (var i = 0; i < r.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1, horizontal: AppSpacing.xxs),
                  child: Text(r[i], textAlign: i == 0 ? TextAlign.left : TextAlign.right),
                ),
            ],
          ),
      ],
    );
  }
}
