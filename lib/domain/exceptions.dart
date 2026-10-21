/// Thrown when a sale asks for more units than are in stock.
class InsufficientStockException implements Exception {
  final List<String> problems;
  InsufficientStockException(this.problems);

  @override
  String toString() => 'Not enough stock:\n${problems.join('\n')}';
}

/// Thrown when a feature is not available on this device (e.g. Google
/// Calendar on Windows).
class UnsupportedPlatformException implements Exception {
  final String message;
  UnsupportedPlatformException(this.message);

  @override
  String toString() => message;
}
