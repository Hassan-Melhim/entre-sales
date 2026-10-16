import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'core/dates.dart';
import 'data/models.dart';
import 'data/repositories/calendar_repository.dart';
import 'data/repositories/discount_repository.dart';
import 'data/repositories/inventory_repository.dart';
import 'data/repositories/report_repository.dart';
import 'data/repositories/sales_repository.dart';
import 'services/calendar_service.dart';
import 'services/pdf_service.dart';

/// The open database. Overridden in main() once the database is opened.
final databaseProvider = Provider<Database>((ref) => throw UnimplementedError('Database not opened'));

final inventoryRepoProvider = Provider((ref) => InventoryRepository(ref.watch(databaseProvider)));
final salesRepoProvider = Provider((ref) => SalesRepository(ref.watch(databaseProvider)));
final calendarRepoProvider = Provider((ref) => CalendarRepository(ref.watch(databaseProvider)));
final settingsRepoProvider = Provider((ref) => SettingsRepository(ref.watch(databaseProvider)));
final discountRepoProvider = Provider((ref) => DiscountRepository(ref.watch(databaseProvider)));
final reportRepoProvider = Provider((ref) => ReportRepository(ref.watch(databaseProvider)));
final calendarServiceProvider =
    Provider((ref) => CalendarService(ref.watch(calendarRepoProvider), ref.watch(settingsRepoProvider)));

/// Bumped after every write so that all lists reload.
final dataRevisionProvider = StateProvider<int>((ref) => 0);

/// Call after saving anything to the database.
void refreshData(WidgetRef ref) => ref.read(dataRevisionProvider.notifier).state++;

// ------------------------------------------------------------------ Queries

final artistsProvider = FutureProvider<List<Artist>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(inventoryRepoProvider).artists();
});

final categoriesProvider = FutureProvider<List<ProductCategory>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(inventoryRepoProvider).categories();
});

final discountsProvider = FutureProvider<List<Discount>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(discountRepoProvider).discounts();
});

class ProductFilter {
  final String query;
  final int? artistId;
  final int? categoryId;
  const ProductFilter({this.query = '', this.artistId, this.categoryId});

  @override
  bool operator ==(Object other) =>
      other is ProductFilter && other.query == query && other.artistId == artistId && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(query, artistId, categoryId);
}

final productsProvider = FutureProvider.family<List<Product>, ProductFilter>((ref, f) {
  ref.watch(dataRevisionProvider);
  return ref.watch(inventoryRepoProvider).products(query: f.query, artistId: f.artistId, categoryId: f.categoryId);
});

class OrderFilter {
  final DateRange? range;
  final int? sessionId;
  final String query;
  const OrderFilter({this.range, this.sessionId, this.query = ''});

  @override
  bool operator ==(Object other) =>
      other is OrderFilter &&
      other.range?.start == range?.start &&
      other.range?.end == range?.end &&
      other.sessionId == sessionId &&
      other.query == query;

  @override
  int get hashCode => Object.hash(range?.start, range?.end, sessionId, query);
}

final ordersProvider = FutureProvider.family<List<SaleOrder>, OrderFilter>((ref, f) {
  ref.watch(dataRevisionProvider);
  return ref.watch(salesRepoProvider).orders(range: f.range, sessionId: f.sessionId, query: f.query);
});

final sessionsProvider = FutureProvider<List<CalendarSession>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(calendarRepoProvider).sessions();
});

final settingProvider = FutureProvider.family<String?, String>((ref, key) {
  ref.watch(dataRevisionProvider);
  return ref.watch(settingsRepoProvider).get(key);
});

/// Store details printed on PDFs.
final storeInfoProvider = FutureProvider<StoreInfo>((ref) async {
  ref.watch(dataRevisionProvider);
  final s = ref.watch(settingsRepoProvider);
  String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
  return StoreInfo(
    name: clean(await s.get(SettingsRepository.storeName)) ?? 'Entre',
    address: clean(await s.get(SettingsRepository.storeAddress)),
    taxId: clean(await s.get(SettingsRepository.storeTaxId)),
  );
});

/// Workshop session running right now (re-checked when data changes).
final currentSessionProvider = FutureProvider<CalendarSession?>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(calendarRepoProvider).sessionAt(DateTime.now());
});

final monthlyReportProvider = FutureProvider.family<MonthlyReport, DateTime>((ref, month) {
  ref.watch(dataRevisionProvider);
  return ref.watch(reportRepoProvider).monthly(DateRange.month(month.year, month.month));
});

class StatementRequest {
  final DateRange range;
  const StatementRequest(this.range);
  @override
  bool operator ==(Object other) =>
      other is StatementRequest && other.range.start == range.start && other.range.end == range.end;
  @override
  int get hashCode => Object.hash(range.start, range.end);
}

final statementsProvider = FutureProvider.family<List<ArtistStatement>, StatementRequest>((ref, req) async {
  ref.watch(dataRevisionProvider);
  final artists = await ref.watch(artistsProvider.future);
  return ref.watch(reportRepoProvider).allStatements(artists, req.range);
});
