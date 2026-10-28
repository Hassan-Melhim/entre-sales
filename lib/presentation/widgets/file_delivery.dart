import '../../data/export/browser_download.dart';
import '../../data/export/export_file.dart';
import 'app_messenger.dart';

/// Downloads [file] and tells the user what happened.
Future<void> deliverExport(ExportFile file) async {
  try {
    downloadFile(file);
    showAppMessage('Downloading ${file.name}');
  } catch (e) {
    showAppMessage('Could not download ${file.name}: $e', error: true);
  }
}
