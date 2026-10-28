/// Thrown when a sale asks for more units than are in stock.
class InsufficientStockException implements Exception {
  final List<String> problems;
  InsufficientStockException(this.problems);

  @override
  String toString() => 'Not enough stock:\n${problems.join('\n')}';
}

/// Thrown when the user is not signed in (or the session has expired).
class NotSignedInException implements Exception {
  @override
  String toString() => 'You are signed out. Sign in again to continue.';
}

/// Sign-in failed; [message] is meant for the user.
class SignInException implements Exception {
  final String message;
  SignInException(this.message);

  @override
  String toString() => message;
}

/// A save or delete was refused by the database; [message] is meant for the user.
class DataException implements Exception {
  final String message;
  DataException(this.message);

  @override
  String toString() => message;
}
