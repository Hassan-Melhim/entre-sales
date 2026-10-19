import '../core/dates.dart';

/// A workshop / event session, from Google Calendar or added by hand.
class CalendarSession {
  final int? id;

  /// NULL for sessions added by hand.
  final String? googleId;
  final String title;
  final DateTime start;
  final DateTime end;

  const CalendarSession({this.id, this.googleId, required this.title, required this.start, required this.end});

  bool get isManual => googleId == null;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  String get label => '$title · ${formatDateTime(start)}';

  factory CalendarSession.fromMap(Map<String, Object?> m) => CalendarSession(
        id: m['id'] as int,
        googleId: m['google_id'] as String?,
        title: m['title'] as String,
        start: fromDb(m['start_at'] as String),
        end: fromDb(m['end_at'] as String),
      );
}
