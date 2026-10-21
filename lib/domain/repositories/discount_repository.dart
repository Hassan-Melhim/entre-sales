import '../models/discount.dart';

abstract interface class DiscountRepository {
  Future<List<Discount>> discounts({bool activeOnly = false});
  Future<void> save(Discount discount);
}
