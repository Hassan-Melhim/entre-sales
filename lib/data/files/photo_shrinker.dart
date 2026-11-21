import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../domain/models/product_photo.dart';

/// Thrown when the browser can't open a picture (for example a HEIC photo
/// in Chrome: Safari can open those).
class PhotoUnreadableException implements Exception {
  final String fileName;
  PhotoUnreadableException(this.fileName);

  @override
  String toString() => '$fileName could not be opened. If it is a HEIC photo, use Safari, '
      'or save it as JPEG first.';
}

/// Makes the two sizes of a product photo, in the browser, without sending
/// the original anywhere:
///  * the picture is drawn upright (browsers apply the camera's rotation),
///  * shrunk to at most 1200 px and 400 px on the longest side,
///  * saved as JPEG on a white background. Redrawing it leaves out the
///    camera details (location, date, device).
Future<PhotoPair> shrinkPhoto(web.Blob source, {String fileName = 'photo'}) async {
  final img = await _open(source, fileName);
  final display = _draw(img, img.naturalWidth, img.naturalHeight, PhotoPair.displaySize);
  // The thumbnail is made from the display size: two smaller steps look
  // sharper than one big one.
  final thumb = _draw(display, display.width, display.height, PhotoPair.thumbSize);
  return PhotoPair(display: await _jpeg(display, 0.85), thumb: await _jpeg(thumb, 0.8));
}

/// Same, from bytes (the file chooser in the product form).
Future<PhotoPair> shrinkPhotoBytes(Uint8List bytes, {String fileName = 'photo'}) =>
    shrinkPhoto(web.Blob([bytes.toJS].toJS), fileName: fileName);

Future<web.HTMLImageElement> _open(web.Blob source, String fileName) async {
  final url = web.URL.createObjectURL(source);
  final img = web.HTMLImageElement()..src = url;
  try {
    await img.decode().toDart;
  } catch (_) {
    throw PhotoUnreadableException(fileName);
  } finally {
    web.URL.revokeObjectURL(url);
  }
  if (img.naturalWidth == 0 || img.naturalHeight == 0) throw PhotoUnreadableException(fileName);
  return img;
}

web.HTMLCanvasElement _draw(web.CanvasImageSource source, int width, int height, int maxSide) {
  final scale = width >= height ? maxSide / width : maxSide / height;
  final s = scale < 1 ? scale : 1.0;
  final w = math.max(1, math.min(maxSide, (width * s).round()));
  final h = math.max(1, math.min(maxSide, (height * s).round()));
  final canvas = web.HTMLCanvasElement()
    ..width = w
    ..height = h;
  final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  ctx
    ..fillStyle = '#ffffff'.toJS
    ..fillRect(0, 0, w, h)
    ..imageSmoothingEnabled = true
    ..imageSmoothingQuality = 'high'
    ..drawImage(source, 0, 0, w, h);
  return canvas;
}

Future<Uint8List> _jpeg(web.HTMLCanvasElement canvas, double quality) async {
  final done = Completer<web.Blob?>();
  canvas.toBlob(((web.Blob? blob) => done.complete(blob)).toJS, 'image/jpeg', quality.toJS);
  final blob = await done.future;
  if (blob == null) throw StateError('The browser could not save the photo.');
  final buffer = await blob.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}
