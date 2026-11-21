import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// A file inside the folder the user chose.
class FolderFile {
  /// Path from the chosen folder, e.g. "Photos/Clothes/Linen shirt - Ana/IMG_1.jpg".
  final String path;
  final int size;
  final web.File file;
  const FolderFile(this.path, this.size, this.file);
}

/// Opens the browser's folder chooser (Finder on a Mac, Explorer on a PC).
/// Returns null if the user cancels. Files are not read here, so choosing a
/// big folder is quick.
///
/// The iPad's Safari can't choose folders: it opens a normal file chooser and
/// gives no folder names, so the result's paths have no "/" in them.
Future<List<FolderFile>?> pickFolder() {
  final completer = Completer<List<FolderFile>?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true
    ..webkitdirectory = true
    ..style.display = 'none';
  web.document.body!.appendChild(input);

  void finish(List<FolderFile>? files) {
    if (!completer.isCompleted) completer.complete(files);
    input.remove();
  }

  input.addEventListener('change', ((web.Event _) {
    final list = input.files;
    if (list == null || list.length == 0) return finish(null);
    finish([
      for (var i = 0; i < list.length; i++)
        if (list.item(i) case final f?)
          FolderFile(f.webkitRelativePath.isEmpty ? f.name : f.webkitRelativePath, f.size, f),
    ]);
  }).toJS);
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return completer.future;
}
