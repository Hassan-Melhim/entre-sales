import '../models/artist.dart';

/// Artists whose work the store sells.
abstract interface class ArtistRepository {
  Future<List<Artist>> artists();
  Future<Artist?> artist(int id);

  /// Creates (id == null) or updates an artist. Returns its id.
  Future<int> save(Artist artist);

  /// Sets the artist's commission; null = back to the store default.
  Future<void> setCommission(int artistId, double? percent);

  /// False when the artist has products or sales (deleting would break history).
  Future<bool> canDelete(int id);
  Future<void> delete(int id);
}
