/// One bar of a report's timeline chart.
class TimelinePoint {
  final DateTime start;

  /// Short axis label, e.g. "14h", "21", "W43", "Oct".
  final String label;

  /// Longer label for tooltips, e.g. "Wed 21/10/2026".
  final String longLabel;
  final int revenueCents;
  final int orders;

  const TimelinePoint({
    required this.start,
    required this.label,
    required this.longLabel,
    required this.revenueCents,
    required this.orders,
  });
}
