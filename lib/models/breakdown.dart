/// Sales totals for one group in a report (a category, artist, gender, product).
class Breakdown {
  final String label;
  int units = 0;
  int revenueCents = 0;
  int profitCents = 0;

  Breakdown(this.label);

  void add({required int units, required int revenueCents, required int profitCents}) {
    this.units += units;
    this.revenueCents += revenueCents;
    this.profitCents += profitCents;
  }
}
