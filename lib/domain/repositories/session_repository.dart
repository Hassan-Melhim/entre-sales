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


  /// Tags sales made during a session that are not tagged yet.
  Future<int> autoTagSales();
}
