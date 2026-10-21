import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'export_file.dart';

const String desktopFolderName = 'Entre Sales';

bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// True where a saved file can be shown in the system file browser.
bool get canRevealFiles => _isDesktop;

Future<DeliveredFile> deliverFile(ExportFile file, {String? shareText}) async {
  if (_isDesktop) {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, desktopFolderName));
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, file.name));
    await target.writeAsBytes(file.bytes, flush: true);
    return DeliveredFile(savedPath: target.path);
  }
  final tmp = File(p.join((await getTemporaryDirectory()).path, file.name));
  await tmp.writeAsBytes(file.bytes, flush: true);
  await Share.shareXFiles([XFile(tmp.path, mimeType: file.mimeType)], text: shareText);
  return const DeliveredFile();
}

/// Opens the folder containing [path] (best effort).
Future<void> revealFile(String path) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,$path']);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [File(path).parent.path]);
    }
  } catch (_) {
    // Opening the folder is a convenience; the path is already shown.
  }
}
