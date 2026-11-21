import 'dart:typed_data';

/// A product photo ready to upload: JPEG bytes in two sizes, already turned
/// upright and stripped of camera details (location, date, device).
class PhotoPair {
  /// Longest side at most [displaySize] px.
  final Uint8List display;

  /// Longest side at most [thumbSize] px; used in lists and the Sell grid.
  final Uint8List thumb;

  const PhotoPair({required this.display, required this.thumb});

  static const displaySize = 1200;
  static const thumbSize = 400;
}
