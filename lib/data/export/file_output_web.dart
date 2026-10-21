import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'export_file.dart';

bool get canRevealFiles => false;

/// Starts a browser download. On the iPad the file goes to the Files app
/// (Downloads), on a Mac to the Downloads folder.
Future<DeliveredFile> deliverFile(ExportFile file, {String? shareText}) async {
  final blob = web.Blob([file.bytes.toJS].toJS, web.BlobPropertyBag(type: file.mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = file.name
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // Give the browser a moment to start the download before freeing it.
  Future<void>.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  return const DeliveredFile();
}

Future<void> revealFile(String path) async {}
