/// An extra field asked for when logging a product of a category,
/// e.g. "Size" for clothes or "Language" for books.
class CategoryAttribute {
  final int? id;
  final String name;

  /// Fixed options to pick from. Empty = the value is typed as free text.
  final List<String> options;

  const CategoryAttribute({this.id, required this.name, this.options = const []});

  bool get isFreeText => options.isEmpty;
}
