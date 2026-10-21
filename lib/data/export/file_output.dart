// Hands a generated file to the user, depending on the platform:
// - Web (Macs, iPad): a browser download.
// - Android / iOS: the share sheet.
// - Windows / macOS / Linux app: saved to Documents/Entre Sales.
export 'file_output_io.dart' if (dart.library.js_interop) 'file_output_web.dart';
