import 'dart:typed_data';

/// A generated file (PDF, CSV, backup) ready to be saved or shared.
class ExportFile {
  final String name;
  final Uint8List bytes;
  final String mimeType;

  const ExportFile(this.name, this.bytes, this.mimeType);

  static const pdf = 'application/pdf';
  static const csv = 'text/csv';
  static const json = 'application/json';
}
