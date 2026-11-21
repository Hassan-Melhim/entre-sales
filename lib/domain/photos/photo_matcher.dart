import '../models/product.dart';

/// Links the photo folders chosen by the user to products.
///
/// The Drive is laid out as `Category / Product name - Artist name / images`.
/// Each image's folder name is split at a " - " and compared with the
/// product name and artist name (ignoring capitals, accents, extra spaces
/// and the kind of dash). The first image of a folder, in the order a person
/// would sort the names (IMG_2 before IMG_10), becomes the product's photo.
class PhotoMatcher {
  static const imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif'};

  /// [paths] are the chosen files' paths relative to the chosen folder, with
  /// "/" between folders. With [replaceExisting] false, products that already
  /// have a photo are left alone.
  static PhotoPlan plan(List<String> paths, List<Product> products, {bool replaceExisting = false}) {
    // Image files grouped by the folder that holds them.
    final byFolder = <String, List<String>>{};
    var ignoredFiles = 0;
    for (final raw in paths) {
      final path = raw.replaceAll('\\', '/');
      final parts = path.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.length < 2 ||
          parts.any((p) => p.startsWith('.') || p == '__MACOSX') ||
          !isImage(parts.last)) {
        ignoredFiles++;
        continue;
      }
      byFolder.putIfAbsent(parts.sublist(0, parts.length - 1).join('/'), () => []).add(path);
    }

    final index = <String, List<Product>>{};
    for (final p in products) {
      index.putIfAbsent(_key(p.name, p.artistName), () => []).add(p);
    }

    final matches = <PhotoMatch>[];
    final unmatched = <String>[];
    final matchedIds = <int>{};
    final skipped = <Product>[];
    final folders = byFolder.keys.toList()..sort(naturalCompare);
    for (final folder in folders) {
      final found = productsForFolder(folder.split('/').last, index);
      if (found.isEmpty) {
        unmatched.add(folder);
        continue;
      }
      final files = byFolder[folder]!..sort((a, b) => naturalCompare(a.split('/').last, b.split('/').last));
      for (final product in found) {
        if (product.id == null || !matchedIds.add(product.id!)) continue;
        if (product.hasPhoto && !replaceExisting) {
          skipped.add(product);
        } else {
          matches.add(PhotoMatch(product: product, folder: folder, file: files.first));
        }
      }
    }
    final withoutFolder = products.where((p) => p.id != null && !matchedIds.contains(p.id) && !p.hasPhoto).toList()
      ..sort((a, b) => naturalCompare(a.name, b.name));
    return PhotoPlan(
      matches: matches,
      alreadyHavePhoto: skipped,
      unmatchedFolders: unmatched,
      productsWithoutPhoto: withoutFolder,
      ignoredFiles: ignoredFiles,
    );
  }

  static bool isImage(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 && imageExtensions.contains(fileName.substring(dot + 1).toLowerCase());
  }

  /// Products named by a folder like "Linen shirt - Ana Ruiz". Every " - "
  /// is tried as the split point (a product name can contain one), and both
  /// orders are accepted (in case a folder was named "Artist - Product").
  static List<Product> productsForFolder(String folderName, Map<String, List<Product>> index) {
    final name = normalize(folderName);
    final dashes = RegExp(r'\s*-\s*').allMatches(name).toList();
    for (final d in dashes) {
      final left = name.substring(0, d.start).trim();
      final right = name.substring(d.end).trim();
      if (left.isEmpty || right.isEmpty) continue;
      final hit = index['$left|$right'] ?? index['$right|$left'];
      if (hit != null) return hit;
    }
    return const [];
  }

  static String _key(String product, String artist) => '${normalize(product)}|${normalize(artist)}';

  /// Lower case, no accents, one kind of dash, single spaces.
  static String normalize(String s) {
    final buffer = StringBuffer();
    for (final rune in s.toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      buffer.write(_plain[c] ?? c);
    }
    return buffer.toString().replaceAll(RegExp(r'[‐-―−]'), '-').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const _plain = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c', '’': "'", '‘': "'", '´': "'", '`': "'",
  };

  /// Compares names the way people sort them: "IMG_2" before "IMG_10".
  static int naturalCompare(String a, String b) {
    final re = RegExp(r'(\d+)|(\D+)');
    final pa = re.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
    final pb = re.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final x = pa[i], y = pb[i];
      final nx = int.tryParse(x), ny = int.tryParse(y);
      final c = (nx != null && ny != null) ? nx.compareTo(ny) : x.compareTo(y);
      if (c != 0) return c;
    }
    final c = pa.length.compareTo(pb.length);
    return c != 0 ? c : a.compareTo(b);
  }
}

/// One product and the image chosen for it.
class PhotoMatch {
  final Product product;
  final String folder;
  final String file;
  const PhotoMatch({required this.product, required this.folder, required this.file});
}

/// What an import of photos would do, shown before anything is uploaded.
class PhotoPlan {
  final List<PhotoMatch> matches;

  /// Matched, but left alone because they already have a photo.
  final List<Product> alreadyHavePhoto;

  /// Folders with images whose name matched no product.
  final List<String> unmatchedFolders;

  /// Products that will still have no photo (they get the category icon).
  final List<Product> productsWithoutPhoto;

  /// Files that aren't images, hidden files, etc.
  final int ignoredFiles;

  const PhotoPlan({
    required this.matches,
    required this.alreadyHavePhoto,
    required this.unmatchedFolders,
    required this.productsWithoutPhoto,
    required this.ignoredFiles,
  });
}
