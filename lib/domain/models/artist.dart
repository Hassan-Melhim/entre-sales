import '../business_rules.dart';

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
  bool get hasCustomCommission => commissionPercent != null;

  Artist copyWith({double? commissionPercent, bool clearCommission = false}) => Artist(
        id: id,
        name: name,
        gender: gender,
        address: address,
        legalName: legalName,
        taxId: taxId,
        iban: iban,
        bankName: bankName,
        isSpainResident: isSpainResident,
        commissionPercent: clearCommission ? null : (commissionPercent ?? this.commissionPercent),
      );
}
