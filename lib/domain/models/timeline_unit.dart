/// Size of each bar in a report's timeline chart.
enum TimelineUnit {
  hour('per hour'),
  day('per day'),
  week('per week'),
  month('per month');

  final String label;
  const TimelineUnit(this.label);
}
