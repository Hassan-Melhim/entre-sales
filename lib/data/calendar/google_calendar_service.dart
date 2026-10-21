import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

import '../../core/dates.dart';
import '../../domain/business_rules.dart';
import '../../domain/exceptions.dart';
import '../../domain/models/calendar_session.dart';
import '../../domain/models/date_range.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/settings_repository.dart';

/// Reads workshop sessions from the store's Google Calendar.
///
/// Requires a one-time Google Cloud setup (see SETUP.md → Google Calendar).
/// Sessions are cached in the database, so tagging works offline.
///
/// Sign-in currently works in the Android / iOS app only. In the website it
/// will move to the server together with the shared database (Supabase), so
/// all devices see the same sessions; until then sessions can be added by hand.
class GoogleCalendarService {
  final SessionRepository sessions;
  final SettingsRepository settings;

  GoogleCalendarService(this.sessions, this.settings);

  /// True where Google sign-in works in this version.
  static bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  // Created on first use, so nothing Google-related runs where unsupported.
  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _signIn {
    if (!isSupported) {
      throw UnsupportedPlatformException(
          'Google Calendar sync is not available here yet. Add workshop sessions by hand for now.');
    }
    return _googleSignIn ??= GoogleSignIn(scopes: [gcal.CalendarApi.calendarReadonlyScope]);
  }

  /// How far back and forward each sync looks.
  static const Duration syncPast = Duration(days: 365);
  static const Duration syncFuture = Duration(days: 90);

  Future<String?> currentAccount() => settings.get(SettingKeys.calendarAccount);

  Future<String?> signIn() async {
    final account = await _signIn.signIn();
    await settings.set(SettingKeys.calendarAccount, account?.email);
    return account?.email;
  }

  Future<void> signOut() async {
    await _signIn.signOut();
    await settings.set(SettingKeys.calendarAccount, null);
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
      final calendarId = (await settings.get(SettingKeys.calendarId))?.trim();
      final now = DateTime.now();
      final window = DateRange(startOfDay(now.subtract(syncPast)), endOfDayExclusive(now.add(syncFuture)));

      final keyword = BusinessRules.workshopKeyword.toLowerCase();
      final found = <CalendarSession>[];
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
          found.add(CalendarSession(googleId: e.id, title: title, start: start, end: end));
        }
        pageToken = page.nextPageToken;
      } while (pageToken != null);

      await sessions.replaceGoogleSessions(window, found);
      await sessions.autoTagSales();
      await settings.set(SettingKeys.calendarLastSync, toDb(DateTime.now()));
      await settings.set(SettingKeys.calendarAccount, account.email);
      return found.length;
    } finally {
      client.close();
    }
  }

  /// All-day events come as a UTC date; use it as local midnight.
  DateTime? _allDay(DateTime? d) => d == null ? null : DateTime(d.year, d.month, d.day);
}
