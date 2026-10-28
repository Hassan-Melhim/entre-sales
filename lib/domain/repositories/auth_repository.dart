import '../models/app_user.dart';

/// Signing in and out. Accounts are created by hand in Supabase
/// (Authentication → Users); there is no public sign-up.
abstract interface class AuthRepository {
  /// The signed-in user, or null.
  AppUser? get currentUser;

  /// Emits the user after every sign-in, sign-out or expired session.
  Stream<AppUser?> get userChanges;

  /// Throws [SignInException] with a message for the user.
  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}
