import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../data/calendar/google_calendar_service.dart';
import '../data/sqlite/repositories/sqlite_artist_repository.dart';
import '../data/sqlite/repositories/sqlite_category_repository.dart';
import '../data/sqlite/repositories/sqlite_data_admin_repository.dart';
import '../data/sqlite/repositories/sqlite_discount_repository.dart';
import '../data/sqlite/repositories/sqlite_product_repository.dart';
import '../data/sqlite/repositories/sqlite_report_repository.dart';
import '../data/sqlite/repositories/sqlite_sales_repository.dart';
import '../data/sqlite/repositories/sqlite_session_repository.dart';
import '../data/sqlite/repositories/sqlite_settings_repository.dart';
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
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/data_admin_repository.dart';
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
// repository interfaces; to move to Supabase, provide Supabase
// implementations here and nothing else changes.

/// The open local database. Overridden in main() once opened.
final databaseProvider = Provider<Database>((ref) => throw UnimplementedError('Database not opened'));

final artistRepositoryProvider =
    Provider<ArtistRepository>((ref) => SqliteArtistRepository(ref.watch(databaseProvider)));
final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) => SqliteCategoryRepository(ref.watch(databaseProvider)));
final productRepositoryProvider =
    Provider<ProductRepository>((ref) => SqliteProductRepository(ref.watch(databaseProvider)));
final salesRepositoryProvider = Provider<SalesRepository>((ref) => SqliteSalesRepository(ref.watch(databaseProvider)));
final sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => SqliteSessionRepository(ref.watch(databaseProvider)));
final discountRepositoryProvider =
    Provider<DiscountRepository>((ref) => SqliteDiscountRepository(ref.watch(databaseProvider)));
final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SqliteSettingsRepository(ref.watch(databaseProvider)));
final reportRepositoryProvider =
    Provider<ReportRepository>((ref) => SqliteReportRepository(ref.watch(databaseProvider)));
final dataAdminRepositoryProvider =
    Provider<DataAdminRepository>((ref) => SqliteDataAdminRepository(ref.watch(databaseProvider)));

final reportServiceProvider = Provider((ref) => ReportService(ref.watch(reportRepositoryProvider)));
final calendarServiceProvider = Provider(
    (ref) => GoogleCalendarService(ref.watch(sessionRepositoryProvider), ref.watch(settingsRepositoryProvider)));

// ================================================================== Refreshing

/// Bumped after every write so that all lists reload.
final dataRevisionProvider = StateProvider<int>((ref) => 0);

/// Call after saving anything.
void refreshData(WidgetRef ref) => ref.read(dataRevisionProvider.notifier).state++;

// ===================================================================== Theme

/// Light / dark / follow the device. The starting value is read in main().
final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
    (ref) => throw UnimplementedError('Theme mode not loaded'));

class ThemeModeController extends StateNotifier<ThemeMode> {
  final SettingsRepository _settings;
  ThemeModeController(this._settings, ThemeMode initial) : super(initial);

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _settings.set(SettingKeys.themeMode, AppTheme.settingFromMode(mode));
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
