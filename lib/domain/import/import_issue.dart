import 'import_template.dart';

/// One problem found while checking the files, with the spreadsheet row it
/// is on (the header is row 1).
class ImportIssue {
  final ImportFileKind file;
  final int? row;
  final String message;

  /// A receipt that is already in the system: blocks the import unless the
  /// user chooses to skip those (to finish an interrupted import).
  final bool alreadyImported;

  const ImportIssue(this.file, this.row, this.message, {this.alreadyImported = false});

  @override
  String toString() => '${file.label}${row == null ? '' : ', row $row'}: $message';
}
