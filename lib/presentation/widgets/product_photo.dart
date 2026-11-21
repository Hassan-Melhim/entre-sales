import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/product.dart';
import '../providers.dart';
import '../theme/app_tokens.dart';
import 'category_icon.dart';

/// A product's photo, or its category's icon when it has none (or the photo
/// can't be loaded). Lists use the small thumbnail; [large] uses the full size.
class ProductPhoto extends ConsumerWidget {
  final Product product;
  final double size;
  final bool large;

  /// Tapping opens the photo full size.
  final bool canEnlarge;

  const ProductPhoto({
    super.key,
    required this.product,
    this.size = AppSizes.photoList,
    this.large = false,
    this.canEnlarge = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = large ? (product.photoPath ?? product.thumbPath) : (product.thumbPath ?? product.photoPath);
    final placeholder = CategoryIcon(categoryName: product.categoryName, size: size);
    if (path == null) return placeholder;
    final url = ref.watch(productPhotoRepositoryProvider).urlFor(path);
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.s * 2),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: pixels,
        semanticLabel: product.name,
        frameBuilder: (context, child, frame, sync) => sync || frame != null ? child : placeholder,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
    if (canEnlarge && product.photoPath != null) {
      image = InkWell(
        borderRadius: BorderRadius.circular(AppRadius.s * 2),
        onTap: () => showProductPhoto(context, product),
        child: image,
      );
    }
    return image;
  }
}

/// The full-size photo in a dialog.
Future<void> showProductPhoto(BuildContext context, Product product) => showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.photoDialog, maxHeight: AppSizes.photoDialog + 80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: _FullPhoto(product: product)),
              ListTile(
                title: Text(product.name),
                subtitle: Text(product.artistName),
                trailing: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );

class _FullPhoto extends ConsumerWidget {
  final Product product;
  const _FullPhoto({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(productPhotoRepositoryProvider).urlFor(product.photoPath!);
    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const SizedBox.square(
              dimension: AppSizes.photoForm, child: Center(child: CircularProgressIndicator())),
      errorBuilder: (_, __, ___) => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text('The photo could not be loaded.'),
      ),
    );
  }
}
