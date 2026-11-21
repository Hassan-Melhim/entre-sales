import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_config.dart';
import '../../../domain/exceptions.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_photo.dart';
import '../../../domain/repositories/product_photo_repository.dart';
import '../supabase_errors.dart';

/// Photos live in the public "product-photos" bucket as
/// `products/<product id>/<time>.jpg` (and `<time>_thumb.jpg`). Every upload
/// gets a new name, so a changed photo is never confused with the old one in
/// a browser's cache.
class SupabaseProductPhotoRepository implements ProductPhotoRepository {
  final SupabaseClient _db;
  SupabaseProductPhotoRepository(this._db);

  StorageFileApi get _bucket => _db.storage.from(PhotoStorage.bucket);

  @override
  Future<void> setPhoto(int productId, PhotoPair photo, {Product? previous}) async {
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final display = 'products/$productId/$stamp.jpg';
    final thumb = 'products/$productId/${stamp}_thumb.jpg';
    final options = FileOptions(contentType: 'image/jpeg', cacheControl: PhotoStorage.cacheSeconds);
    await _storage(() => _bucket.uploadBinary(display, photo.display, fileOptions: options));
    await _storage(() => _bucket.uploadBinary(thumb, photo.thumb, fileOptions: options));
    try {
      await guard(() => _db.from('products').update({'photo_path': display, 'thumb_path': thumb}).eq('id', productId));
    } catch (_) {
      await _quietRemove([display, thumb]);
      rethrow;
    }
    if (previous != null) await deleteFilesOf(previous);
  }

  @override
  Future<void> removePhoto(Product product) async {
    if (product.id == null) return;
    await guard(() => _db.from('products').update({'photo_path': null, 'thumb_path': null}).eq('id', product.id!));
    await deleteFilesOf(product);
  }

  @override
  Future<void> deleteFilesOf(Product product) =>
      _quietRemove([product.photoPath, product.thumbPath].whereType<String>().toList());

  @override
  String urlFor(String path) => _bucket.getPublicUrl(path);

  Future<void> _quietRemove(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _bucket.remove(paths);
    } catch (_) {
      // A leftover file costs a little space and nothing else.
    }
  }

  static Future<T> _storage<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on StorageException catch (e) {
      final code = e.statusCode ?? '';
      final msg = e.message.toLowerCase();
      if (code == '404' || msg.contains('bucket not found')) {
        throw DataException('The photo storage is not set up yet. '
            'Run supabase/migrations/20261121120000_product_photos.sql in the SQL Editor.');
      }
      if (code == '403' || msg.contains('policy') || msg.contains('unauthorized')) {
        throw DataException('Uploading photos was refused. Sign in again, and check that '
            'migration 20261121120000_product_photos.sql has been run.');
      }
      if (code == '413' || msg.contains('too large') || msg.contains('size')) {
        throw DataException('The photo is too large to upload.');
      }
      throw DataException('The photo could not be uploaded: ${e.message}');
    }
  }
}
