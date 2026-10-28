import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase/repositories/supabase_artist_repository.dart';
import '../data/supabase/repositories/supabase_auth_repository.dart';
import '../data/supabase/repositories/supabase_backup_repository.dart';
import '../data/supabase/repositories/supabase_category_repository.dart';
import '../data/supabase/repositories/supabase_discount_repository.dart';
import '../data/supabase/repositories/supabase_product_repository.dart';
import '../data/supabase/repositories/supabase_report_repository.dart';
import '../data/supabase/repositories/supabase_sales_repository.dart';
import '../data/supabase/repositories/supabase_session_repository.dart';
import '../data/supabase/repositories/supabase_settings_repository.dart';
import '../domain/models/app_user.dart';
import '../domain/models/artist.dart';
import '../domain/models/artist_statement.dart';
import '../domain/models/calendar_session.dart';
import '../domain/models/date_range.dart';
import '../domain/models/discount.dart';
import '../domain/models/order_filter.dart';
import '../domain/models/product.dart';
import '../domain/models/product_category.dart';
import '../domain/models/product_filter.dart';
import '../domain/models/report_period.dart';
import '../domain/models/sale_order.dart';
import '../domain/models/sales_report.dart';
import '../domain/models/store_info.dart';
import '../domain/repositories/artist_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/backup_repository.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/device_settings_repository.dart';
import '../domain/repositories/discount_repository.dart';
import '../domain/repositories/product_repository.dart';
import '../domain/repositories/report_repository.dart';
import '../domain/repositories/sales_repository.dart';
import '../domain/repositories/session_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/services/report_service.dart';
import 'theme/app_theme.dart';

// ===================================================================== Wiring
//
// The only place that knows which database is used. Screens depend on the
// repository interfaces, never on Supabase directly.

/// The Supabase connection, opened in main().
final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// This device's own preferences. Overridden in main() once loaded.
final deviceSettingsProvider =
    Provider<DeviceSettingsRepository>((ref) => throw UnimplementedError('Device settings not loaded'));

final authRepositoryProvider = Provider<AuthRepository>((ref) => SupabaseAuthRepository(ref.watch(supabaseProvider).auth));
final artistRepositoryProvider =
    Provider<ArtistRepository>((ref) => SupabaseArtistRepository(ref.watch(supabaseProvider)));
final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) => SupabaseCategoryRepository(ref.watch(supabaseProvider)));
final productRepositoryProvider =
    Provider<ProductRepository>((ref) => SupabaseProductRepository(ref.watch(supabaseProvider)));
final salesRepositoryProvider = Provider<SalesRepository>((ref) => SupabaseSalesRepository(ref.watch(supabaseProvider)));
final sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => SupabaseSessionRepository(ref.watch(supabaseProvider)));
final discountRepositoryProvider =
    Provider<DiscountRepository>((ref) => SupabaseDiscountRepository(ref.watch(supabaseProvider)));
final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SupabaseSettingsRepository(ref.watch(supabaseProvider)));
final reportRepositoryProvider =
    Provider<ReportRepository>((ref) => SupabaseReportRepository(ref.watch(supabaseProvider)));
final backupRepositoryProvider =
    Provider<BackupRepository>((ref) => SupabaseBackupRepository(ref.watch(supabaseProvider)));

final reportServiceProvider = Provider((ref) => ReportService(ref.watch(reportRepositoryProvider)));

// ================================================================ Signing in

/// The signed-in owner, or null. Updates on sign-in, sign-out and expiry.
final currentUserProvider = StreamProvider<AppUser?>((ref) async* {
  final auth = ref.watch(authRepositoryProvider);
  yield auth.currentUser;
  yield* auth.userChanges;
});

/// Minutes without use before this device signs out (0 = never).
final idleSignOutMinutesProvider = StateNotifierProvider<IdleSignOutController, int>(
    (ref) => IdleSignOutController(ref.watch(deviceSettingsProvider)));

class IdleSignOutController extends StateNotifier<int> {
  /// Used until the owners choose otherwise on a device.
  static const defaultMinutes = 30;
  static const choices = [0, 5, 15, 30, 60, 120];

  final DeviceSettingsRepository _settings;
  IdleSignOutController(this._settings)
      : super(int.tryParse(_settings.get(DeviceSettingKeys.idleSignOutMinutes) ?? '') ?? defaultMinutes);

  Future<void> set(int minutes) async {
    state = minutes;
    await _settings.set(DeviceSettingKeys.idleSignOutMinutes, '$minutes');
  }
}

// ================================================================== Refreshing

/// Bumped after every write so that all lists reload.
final dataRevisionProvider = StateProvider<int>((ref) => 0);

/// Call after saving anything.
void refreshData(WidgetRef ref) => ref.read(dataRevisionProvider.notifier).state++;

// ===================================================================== Theme

/// Light / dark / follow the device; saved on this device only.
final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
    (ref) => ThemeModeController(ref.watch(deviceSettingsProvider)));

class ThemeModeController extends StateNotifier<ThemeMode> {
  final DeviceSettingsRepository _settings;
  ThemeModeController(this._settings)
      : super(AppTheme.modeFromSetting(_settings.get(DeviceSettingKeys.themeMode)));

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _settings.set(DeviceSettingKeys.themeMode, AppTheme.settingFromMode(mode));
  }
}

// ==================================================================== Queries

final artistsProvider = FutureProvider<List<Artist>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(artistRepositoryProvider).artists();
});

final categoriesProvider = FutureProvider<List<ProductCategory>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(categoryRepositoryProvider).categories();
});

final discountsProvider = FutureProvider<List<Discount>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(discountRepositoryProvider).discounts();
});

final productsProvider = FutureProvider.family<List<Product>, ProductFilter>((ref, f) {
  ref.watch(dataRevisionProvider);
  return ref.watch(productRepositoryProvider).products(f);
});

final ordersProvider = FutureProvider.family<List<SaleOrder>, OrderFilter>((ref, f) {
  ref.watch(dataRevisionProvider);
  return ref.watch(salesRepositoryProvider).orders(f);
});

final sessionsProvider = FutureProvider<List<CalendarSession>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(sessionRepositoryProvider).sessions();
});

final settingProvider = FutureProvider.family<String?, String>((ref, key) {
  ref.watch(dataRevisionProvider);
  return ref.watch(settingsRepositoryProvider).get(key);
});

/// Store details printed on PDFs.
final storeInfoProvider = FutureProvider<StoreInfo>((ref) async {
  ref.watch(dataRevisionProvider);
  final s = ref.watch(settingsRepositoryProvider);
  String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
  return StoreInfo(
    name: clean(await s.get(SettingKeys.storeName)) ?? 'Entre Salas',
    address: clean(await s.get(SettingKeys.storeAddress)),
    taxId: clean(await s.get(SettingKeys.storeTaxId)),
  );
});

/// Workshop session running right now (re-checked when data changes).
final currentSessionProvider = FutureProvider<CalendarSession?>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(sessionRepositoryProvider).sessionAt(DateTime.now());
});

final salesReportProvider = FutureProvider.family<SalesReport, ReportPeriod>((ref, period) {
  ref.watch(dataRevisionProvider);
  return ref.watch(reportServiceProvider).salesReport(period);
});

/// Artist settlements for a period (only artists with activity).
final statementsProvider = FutureProvider.family<List<ArtistStatement>, DateRange>((ref, range) async {
  ref.watch(dataRevisionProvider);
  final artists = await ref.watch(artistsProvider.future);
  return ref.watch(reportServiceProvider).statements(artists, range);
});
