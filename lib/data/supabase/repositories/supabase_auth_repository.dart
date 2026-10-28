import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/exceptions.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final GoTrueClient _auth;
  SupabaseAuthRepository(this._auth);

  static AppUser? _user(User? u) => u == null ? null : AppUser(id: u.id, email: u.email ?? '');

  @override
  AppUser? get currentUser => _user(_auth.currentUser);

  @override
  Stream<AppUser?> get userChanges => _auth.onAuthStateChange.map((s) => _user(s.session?.user));

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
        throw SignInException('Wrong email or password.');
      }
      if (msg.contains('rate limit') || e.statusCode == '429') {
        throw SignInException('Too many attempts. Wait a few minutes and try again.');
      }
      throw SignInException(e.message);
    } catch (e) {
      throw SignInException('Could not reach the server. Check the internet connection.');
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
