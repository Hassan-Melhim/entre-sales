import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../export/export_file.dart';

/// Sharing a file through the device's share sheet (iPad / iPhone, Mac
/// Safari and Chrome): Mail, Messages, AirDrop… with the file attached.

web.File _toBrowserFile(ExportFile f) =>
    web.File(<JSAny>[f.bytes.toJS].toJS, f.name, web.FilePropertyBag(type: f.mimeType));

/// Whether this browser can attach [file] to a share.
bool canShareFile(ExportFile file) {
  try {
    return web.window.navigator.canShare(web.ShareData(files: <web.File>[_toBrowserFile(file)].toJS));
  } catch (_) {
    return false; // browsers without file sharing (e.g. Firefox)
  }
}

/// Opens the share sheet with [file] attached. Returns false if the user
/// closed it without sharing. Must be called straight from a tap (browsers
/// only open the sheet in response to one), so prepare the file beforehand.
Future<bool> shareFile(ExportFile file, {String title = '', String text = ''}) async {
  try {
    await web.window.navigator
        .share(web.ShareData(files: <web.File>[_toBrowserFile(file)].toJS, title: title, text: text))
        .toDart;
    return true;
  } catch (e) {
    if ('$e'.contains('AbortError')) return false; // cancelled
    rethrow;
  }
}
