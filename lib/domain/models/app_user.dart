/// A signed-in owner. All owners have the same rights.
class AppUser {
  final String id;
  final String email;

  const AppUser({required this.id, required this.email});
}
