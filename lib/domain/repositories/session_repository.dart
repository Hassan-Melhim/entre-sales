import '../models/calendar_session.dart';
import '../models/date_range.dart';

/// Workshop / event sessions (from Google Calendar or added by hand).
abstract interface class SessionRepository {
  /// Newest first; sessions overlapping [range] when given.
  Future<List<CalendarSession>> sessions({DateRange? range});
  Future<CalendarSession?> session(int id);

  /// The session running at [t], if any.
  Future<CalendarSession?> sessionAt(DateTime t);

  Future<int> add(CalendarSession session);
  Future<void> delete(int id);

  /// Stores the sessions fetched from Google for [window]. Google sessions
  /// in the window that disappeared are removed unless a sale uses them.
  Future<void> replaceGoogleSessions(DateRange window, List<CalendarSession> fetched);

  /// Tags sales made during a session that are not tagged yet.
  Future<int> autoTagSales();
}
