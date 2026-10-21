enum OrderStatus {
  completed('completed', 'Completed'),
  partiallyRefunded('partially_refunded', 'Partially refunded'),
  refunded('refunded', 'Refunded');

  /// Stable code used when storing the status.
  final String code;

  /// Text shown to the user.
  final String label;

  const OrderStatus(this.code, this.label);

  static OrderStatus fromCode(String s) => values.firstWhere((e) => e.code == s, orElse: () => completed);
}
