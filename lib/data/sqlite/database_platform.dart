// Picks the SQLite implementation for the platform the app is built for:
// - Web: SQLite compiled to WebAssembly, stored in the browser (IndexedDB).
// - Android / iOS / macOS: the sqflite plugin.
// - Windows / Linux: sqflite_common_ffi.
export 'database_platform_io.dart' if (dart.library.js_interop) 'database_platform_web.dart';
