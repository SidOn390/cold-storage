// lib/models/rent_type.dart

/// Represents the type of rent calculation for stored goods.
///
/// - **Monthly**: Rent calculated per 15-day periods with labour charges
/// - **Seasonal**: Fixed rent for entire season without labour charges
enum RentType {
  monthly,
  seasonal;

  /// Display name for UI
  String get displayName {
    switch (this) {
      case RentType.monthly:
        return 'Monthly';
      case RentType.seasonal:
        return 'Seasonal';
    }
  }

  /// Convert to string for Firestore storage
  String toJson() => name;

  /// Parse from Firestore string
  static RentType fromJson(String value) {
    return RentType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => RentType.monthly,
    );
  }
}
