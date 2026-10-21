import 'dart:typed_data';

/// A generated file (PDF, CSV, backup) ready to be saved or shared.
class ExportFile {
  final String name;
  final Uint8List bytes;
  final String mimeType;

  const ExportFile(this.name, this.bytes, this.mimeType);

  static const pdf = 'application/pdf';
  static const csv = 'text/csv';
  static const sqlite = 'application/vnd.sqlite3';
}

/// What happened to a delivered file.
class DeliveredFile {
  /// Where it was saved (computers), so the UI can offer "Show in folder".
  final String? savedPath;

  const DeliveredFile({this.savedPath});
}
