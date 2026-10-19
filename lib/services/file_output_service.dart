import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ui/app_messenger.dart';

/// Hands a generated file (PDF, CSV, backup) to the user.
///
/// - Android / iOS: opens the share sheet (save to Drive, email, Files…).
/// - Windows / macOS / Linux: saves it to Documents/Entre Sales and shows a
///   message with a button to open the folder.
class FileOutputService {
  FileOutputService._();

  static const String desktopFolderName = 'Entre Sales';

  static bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Delivers [bytes] as a file called [fileName].
  static Future<void> deliverBytes(String fileName, Uint8List bytes, {String? shareText}) async {
    if (isDesktop) {
      final file = File(p.join((await _desktopFolder()).path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      _announceSaved(file);
      return;
    }
    final tmp = File(p.join((await getTemporaryDirectory()).path, fileName));
    await tmp.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(tmp.path)], text: shareText);
  }

  /// Delivers an existing file (e.g. the database for a backup) under [fileName].
  static Future<void> deliverFile(File source, String fileName, {String? shareText}) async {
    if (isDesktop) {
      final target = File(p.join((await _desktopFolder()).path, fileName));
      await source.copy(target.path);
      _announceSaved(target);
      return;
    }
    await Share.shareXFiles([XFile(source.path, name: fileName)], text: shareText);
  }

  static Future<Directory> _desktopFolder() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, desktopFolderName));
    await dir.create(recursive: true);
    return dir;
  }

  static void _announceSaved(File file) {
    showAppMessage(
      'Saved to ${file.path}',
      actionLabel: 'Show in folder',
      onAction: () => _revealInFolder(file),
    );
  }

  static Future<void> _revealInFolder(File file) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,${file.path}']);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', file.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.parent.path]);
      }
    } catch (_) {
      // Opening the folder is a convenience; the path is already shown.
    }
  }
}
