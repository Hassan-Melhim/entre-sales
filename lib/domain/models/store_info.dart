import 'store_logos.dart';

/// Store details printed at the top of every PDF (edited in Settings).
class StoreInfo {
  final String name;
  final String? address;
  final String? taxId;
  final StoreLogos logos;

  const StoreInfo({required this.name, this.address, this.taxId, this.logos = const StoreLogos.none()});
}
