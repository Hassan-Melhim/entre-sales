/// What was created by loading the demo data.
class DemoLoadResult {
  final int artists;
  final int products;
  final int variants;
  final int sales;
  final int refunds;
  final int restocks;
  final int sessions;

  const DemoLoadResult({
    required this.artists,
    required this.products,
    required this.variants,
    required this.sales,
    required this.refunds,
    required this.restocks,
    required this.sessions,
  });

  String get summary => '$artists artists, $products products ($variants variants), '
      '$sales sales, $refunds refunds, $sessions workshop sessions';
}
