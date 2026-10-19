/// Store details printed at the top of every PDF (edited in Settings).
class StoreInfo {
  final String name;
  final String? address;
  final String? taxId;

  const StoreInfo({required this.name, this.address, this.taxId});
}
