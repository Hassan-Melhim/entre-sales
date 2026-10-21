import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// SQLite in the browser. Needs web/sqlite3.wasm and web/sqflite_sw.js,
/// created once with: dart run sqflite_common_ffi_web:setup
DatabaseFactory platformDatabaseFactory() => databaseFactoryFfiWeb;

/// In the browser the "path" is just the database name.
Future<String> platformDatabasePath(String fileName) async => fileName;

/// The browser keeps the database internally; no file to copy.
Future<List<int>?> readDatabaseFile(String path) async => null;
