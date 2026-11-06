import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// A file the user picked.
class PickedFile {
  final String name;
  final Uint8List bytes;
  const PickedFile(this.name, this.bytes);
}

/// Opens the browser's file chooser (Files app on the iPad, Finder on a Mac).
/// Returns null if the user cancels.
Future<PickedFile?> pickFile({String accept = '.csv,text/csv'}) {
  final completer = Completer<PickedFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..style.display = 'none';
  web.document.body!.appendChild(input);

  void finish(PickedFile? f) {
    if (!completer.isCompleted) completer.complete(f);
    input.remove();
  }

  Future<void> read() async {
    final file = input.files?.item(0);
    if (file == null) return finish(null);
    try {
      final buffer = await file.arrayBuffer().toDart;
      finish(PickedFile(file.name, buffer.toDart.asUint8List()));
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
      input.remove();
    }
  }

  // Event handlers given to the browser must not return a Future.
  input.addEventListener('change', ((web.Event _) {
    read();
  }).toJS);
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return completer.future;
}
