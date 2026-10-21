import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show databaseFactorySqflitePlugin;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi, sqfliteFfiInit;

bool get _usesFfi => Platform.isWindows || Platform.isLinux;

DatabaseFactory platformDatabaseFactory() {
  if (_usesFfi) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
  return databaseFactorySqflitePlugin;
}

/// - Android / iOS / macOS: the app's private databases folder.
/// - Windows: %APPDATA%\com.entre\entre_sales\
Future<String> platformDatabasePath(String fileName) async {
  if (_usesFfi) {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return p.join(dir.path, fileName);
  }
  return p.join(await platformDatabaseFactory().getDatabasesPath(), fileName);
}

/// The raw database file, for backups.
Future<List<int>?> readDatabaseFile(String path) async {
  final f = File(path);
  return await f.exists() ? f.readAsBytes() : null;
}
