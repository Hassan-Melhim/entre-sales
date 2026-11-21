/// How urgent the next backup is.
enum BackupUrgency { ok, due, overdue }

/// The last backup downloaded from any device, and by whom.
class BackupStatus {
  /// Suggested rhythm: once a week (plus before clearing or importing data).
  static const dueAfterDays = 7;
  static const overdueAfterDays = 14;

  final DateTime? at;

  /// Email of the login that downloaded it.
  final String? byEmail;

  const BackupStatus({this.at, this.byEmail});

  /// Whole calendar days since the last backup (0 = today); null = never.
  int? daysSince(DateTime now) {
    final last = at;
    if (last == null) return null;
    final from = DateTime(last.year, last.month, last.day);
    final to = DateTime(now.year, now.month, now.day);
    // Rounded, so a daylight-saving change (23 or 25 hours) still counts as a day.
    final days = (to.difference(from).inHours / 24).round();
    return days < 0 ? 0 : days;
  }

  BackupUrgency urgency(DateTime now) {
    final days = daysSince(now);
    if (days == null || days >= overdueAfterDays) return BackupUrgency.overdue;
    if (days >= dueAfterDays) return BackupUrgency.due;
    return BackupUrgency.ok;
  }

  /// "Today", "Yesterday", "12 days ago", "Never".
  String ageLabel(DateTime now) {
    final days = daysSince(now);
    return switch (days) {
      null => 'Never',
      0 => 'Today',
      1 => 'Yesterday',
      _ => '$days days ago',
    };
  }
}
