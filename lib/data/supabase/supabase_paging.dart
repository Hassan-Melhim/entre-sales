import 'supabase_values.dart';

/// Supabase returns at most 1000 rows per request. Reads every page of a
/// query that has a fixed order. [page] receives the first and last row
/// index (inclusive) and must return that slice.
Future<List<DbRow>> fetchAllPages(Future<dynamic> Function(int from, int to) page, {int pageSize = 1000}) async {
  final all = <DbRow>[];
  for (var from = 0;; from += pageSize) {
    final rows = asRows(await page(from, from + pageSize - 1));
    all.addAll(rows);
    if (rows.length < pageSize) return all;
  }
}
