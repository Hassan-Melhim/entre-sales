import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

import '../config/business_rules.dart';
import '../core/dates.dart';
import '../data/models.dart';
import '../data/repositories/calendar_repository.dart';

/// Reads workshop sessions from the store's Google Calendar.
///
/// Requires a one-time Google Cloud setup (see README → "Google Calendar").
/// Works offline after a sync: sessions are cached in the local database.
class CalendarService {
  final CalendarRepository calendarRepo;
  final SettingsRepository settings;

  CalendarService(this.calendarRepo, this.settings);

  final GoogleSignIn _signIn = GoogleSignIn(scopes: [gcal.CalendarApi.calendarReadonlyScope]);

  /// How far back and forward each sync looks.
  static const Duration syncPast = Duration(days: 365);
  static const Duration syncFuture = Duration(days: 90);

  Future<String?> currentAccount() => settings.get(SettingsRepository.calendarAccount);

  Future<String?> signIn() async {
    final account = await _signIn.signIn();
    await settings.set(SettingsRepository.calendarAccount, account?.email);
    return account?.email;
  }

  Future<void> signOut() async {
    await _signIn.signOut();
    await settings.set(SettingsRepository.calendarAccount, null);
  }

  /// Fetches events whose title contains the workshop keyword, stores them,
  /// then tags any untagged sales that fall inside a session.
  /// Returns the number of sessions found.
  Future<int> sync() async {
    final account = await _signIn.signInSilently() ?? await _signIn.signIn();
    if (account == null) throw StateError('Not signed in to Google');

    final client = await _signIn.authenticatedClient();
    if (client == null) throw StateError('Google did not grant calendar access');

    try {
      final api = gcal.CalendarApi(client);
      final calendarId = (await settings.get(SettingsRepository.calendarId))?.trim();
      final now = DateTime.now();
      final window = DateRange(startOfDay(now.subtract(syncPast)), endOfDayExclusive(now.add(syncFuture)));

      final keyword = BusinessRules.workshopKeyword.toLowerCase();
      final sessions = <CalendarSession>[];
      String? pageToken;
      do {
        final page = await api.events.list(
          (calendarId == null || calendarId.isEmpty) ? 'primary' : calendarId,
          timeMin: window.start.toUtc(),
          timeMax: window.end.toUtc(),
          singleEvents: true, // expands recurring workshops into single sessions
          orderBy: 'startTime',
          maxResults: 2500,
          pageToken: pageToken,
        );
        for (final e in page.items ?? const <gcal.Event>[]) {
          final title = e.summary ?? '';
          if (e.id == null || !title.toLowerCase().contains(keyword)) continue;
          if (e.status == 'cancelled') continue;
          final start = e.start?.dateTime?.toLocal() ?? _allDay(e.start?.date);
          final end = e.end?.dateTime?.toLocal() ?? _allDay(e.end?.date);
          if (start == null || end == null) continue;
          sessions.add(CalendarSession(googleId: e.id, title: title, start: start, end: end));
        }
        pageToken = page.nextPageToken;
      } while (pageToken != null);

      await calendarRepo.replaceGoogleSessions(window, sessions);
      await calendarRepo.autoTagSales();
      await settings.set(SettingsRepository.calendarLastSync, toDb(DateTime.now()));
      await settings.set(SettingsRepository.calendarAccount, account.email);
      return sessions.length;
    } finally {
      client.close();
    }
  }

  /// All-day events come as a UTC date; use it as local midnight.
  DateTime? _allDay(DateTime? d) => d == null ? null : DateTime(d.year, d.month, d.day);
}
