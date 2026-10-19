import '../config/business_rules.dart';
import '../core/db_values.dart';

/// An artist whose work is sold in the store.
class Artist {
  final int? id;
  final String name;

  /// Used only for sales analysis (see [BusinessRules.genders]).
  final String? gender;
  final String? address;
  final String? legalName;
  final String? taxId;
  final String? iban;
  final String? bankName;
  final bool isSpainResident;

  /// NULL means the store default ([BusinessRules.defaultCommissionPercent]).
  final double? commissionPercent;

  const Artist({
    this.id,
    required this.name,
    this.gender,
    this.address,
    this.legalName,
    this.taxId,
    this.iban,
    this.bankName,
    this.isSpainResident = true,
    this.commissionPercent,
  });

  double get effectiveCommission => commissionPercent ?? BusinessRules.defaultCommissionPercent;

  factory Artist.fromMap(Map<String, Object?> m) => Artist(
        id: m['id'] as int,
        name: m['name'] as String,
        gender: m['gender'] as String?,
        address: m['address'] as String?,
        legalName: m['legal_name'] as String?,
        taxId: m['tax_id'] as String?,
        iban: m['iban'] as String?,
        bankName: m['bank_name'] as String?,
        isSpainResident: boolFromDb(m['is_spain_resident']),
        commissionPercent: doubleFromDb(m['commission_percent']),
      );

  Map<String, Object?> toMap() => {
        'name': name,
        'gender': gender,
        'address': address,
        'legal_name': legalName,
        'tax_id': taxId,
        'iban': iban,
        'bank_name': bankName,
        'is_spain_resident': isSpainResident ? 1 : 0,
        'commission_percent': commissionPercent,
      };
}
