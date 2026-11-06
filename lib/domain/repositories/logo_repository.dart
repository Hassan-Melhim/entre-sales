import '../models/store_logos.dart';

/// Where the logos for PDFs come from.
abstract interface class LogoRepository {
  /// Never throws: logos that can't be loaded are left out.
  Future<StoreLogos> logos();
}
