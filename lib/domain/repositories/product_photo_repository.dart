import '../models/product.dart';
import '../models/product_photo.dart';

/// Where product photos are kept.
abstract interface class ProductPhotoRepository {
  /// Uploads [photo] for the product and makes it the product's photo.
  /// The previous photo of [previous] (if any) is deleted afterwards.
  Future<void> setPhoto(int productId, PhotoPair photo, {Product? previous});

  /// Takes the photo off the product and deletes its files.
  Future<void> removePhoto(Product product);

  /// Deletes the files of a product that is being deleted. Never throws.
  Future<void> deleteFilesOf(Product product);

  /// The address an image widget can load [path] from.
  String urlFor(String path);
}
