import '../../core/dates.dart';
import 'date_range.dart';
import 'timeline_unit.dart';

enum PeriodKind {
  day('Day'),
  month('Month'),
  quarter('Quarter'),
  year('Year'),
  custom('Custom');

  final String label;
  const PeriodKind(this.label);
}

/// A period to report on: a day, month, quarter, year or a custom range.
class ReportPeriod {
  final PeriodKind kind;
  final DateRange range;

  const ReportPeriod._(this.kind, this.range);

  /// The [kind] period that contains [anchor]. For [PeriodKind.custom] use
  /// [ReportPeriod.custom].
  factory ReportPeriod.containing(PeriodKind kind, DateTime anchor) {
    switch (kind) {
      case PeriodKind.day:
        return ReportPeriod._(kind, DateRange.day(anchor));
      case PeriodKind.month:
        return ReportPeriod._(kind, DateRange.month(anchor.year, anchor.month));
      case PeriodKind.quarter:
        return ReportPeriod._(kind, DateRange.quarter(anchor.year, quarterOf(anchor)));
      case PeriodKind.year:
        return ReportPeriod._(kind, DateRange.year(anchor.year));
      case PeriodKind.custom:
        return ReportPeriod._(kind, DateRange.day(anchor));
    }
  }

  factory ReportPeriod.custom(DateRange range) => ReportPeriod._(PeriodKind.custom, range);

  static int quarterOf(DateTime d) => (d.month - 1) ~/ 3 + 1;

  bool get canStep => kind != PeriodKind.custom;

  /// The same kind of period before / after this one.
  ReportPeriod previous() => _shift(-1);
  ReportPeriod next() => _shift(1);

  ReportPeriod _shift(int n) {
    final s = range.start;
    switch (kind) {
      case PeriodKind.day:
        return ReportPeriod.containing(kind, DateTime(s.year, s.month, s.day + n));
      case PeriodKind.month:
        return ReportPeriod.containing(kind, DateTime(s.year, s.month + n, 1));
      case PeriodKind.quarter:
        return ReportPeriod.containing(kind, DateTime(s.year, s.month + 3 * n, 1));
      case PeriodKind.year:
        return ReportPeriod.containing(kind, DateTime(s.year + n, 1, 1));
      case PeriodKind.custom:
        return this;
    }
  }

  String get label {
    final s = range.start;
    switch (kind) {
      case PeriodKind.day:
        return formatLongDate(s);
      case PeriodKind.month:
        return formatMonth(s);
      case PeriodKind.quarter:
        return 'Q${quarterOf(s)} ${s.year}';
      case PeriodKind.year:
        return '${s.year}';
      case PeriodKind.custom:
        return range.label;
    }
  }

  /// Short text for file names, e.g. 2026-Q4, 2026-10, 20261001-20261015.
  String get fileLabel {
    final s = range.start;
    String two(int v) => v.toString().padLeft(2, '0');
    switch (kind) {
      case PeriodKind.day:
        return fileStamp(s);
      case PeriodKind.month:
        return '${s.year}-${two(s.month)}';
      case PeriodKind.quarter:
        return '${s.year}-Q${quarterOf(s)}';
      case PeriodKind.year:
        return '${s.year}';
      case PeriodKind.custom:
        return range.isSingleDay ? fileStamp(s) : '${fileStamp(s)}-${fileStamp(range.lastDay)}';
    }
  }

  /// How finely to break the period down in the timeline chart.
  TimelineUnit get timelineUnit {
    final days = range.dayCount;
    if (days <= 1) return TimelineUnit.hour;
    if (days <= 62) return TimelineUnit.day;
    if (days <= 200) return TimelineUnit.week;
    return TimelineUnit.month;
  }

  @override
  bool operator ==(Object other) => other is ReportPeriod && other.kind == kind && other.range == range;

  @override
  int get hashCode => Object.hash(kind, range);
}
