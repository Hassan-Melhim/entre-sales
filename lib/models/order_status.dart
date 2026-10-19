enum OrderStatus {
  completed('completed', 'Completed'),
  partiallyRefunded('partially_refunded', 'Partially refunded'),
  refunded('refunded', 'Refunded');

  /// Value stored in the database.
  final String db;

  /// Text shown to the user.
  final String label;

  const OrderStatus(this.db, this.label);

  static OrderStatus fromDb(String s) => values.firstWhere((e) => e.db == s, orElse: () => completed);
}
