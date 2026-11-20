import 'dart:typed_data';

/// One logo file: PNG / JPEG bytes, or an SVG drawing.
class LogoImage {
  final Uint8List bytes;
  final bool isSvg;
  const LogoImage(this.bytes, {required this.isSvg});
}

/// The logos printed on invoices and receipts. Any of them may be missing.
class StoreLogos {
  final LogoImage? corner;
  final LogoImage? footer;
  final LogoImage? kisses;

  /// Why a logo couldn't be loaded, one line per file (empty when all are fine).
  final List<String> problems;

  const StoreLogos({this.corner, this.footer, this.kisses, this.problems = const []});
  const StoreLogos.none() : this();
}
