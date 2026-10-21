import '../../data/export/export_file.dart';
import '../../data/export/file_output.dart';
import 'app_messenger.dart';

/// Saves / downloads / shares [file] and tells the user what happened.
Future<void> deliverExport(ExportFile file, {String? shareText}) async {
  try {
    final result = await deliverFile(file, shareText: shareText);
    final path = result.savedPath;
    if (path != null) {
      showAppMessage(
        'Saved to $path',
        actionLabel: canRevealFiles ? 'Show in folder' : null,
        onAction: () => revealFile(path),
      );
    } else {
      showAppMessage('${file.name} is ready');
    }
  } catch (e) {
    showAppMessage('Could not save ${file.name}: $e', error: true);
  }
}
