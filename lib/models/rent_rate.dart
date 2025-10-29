// lib/models/rent_rate.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'rent_type.dart';

/// Rent rate configuration for a specific cold storage + product + rent type combination.
///
/// Stores the rates that will be used to calculate rent bills.
/// Each combination can have either monthly or seasonal rates configured.
class RentRate {
  final String? id;
  final String coldStorageName;
  final String productName;
  final RentType rentType;

  // For Monthly Rent
  final double? monthlyRatePerUnit;  // Rent per unit per month
  final double? labourRatePerUnit;   // Labour charge per unit

  // For Seasonal Rent
  final double? seasonalRatePerUnit; // Fixed rate per unit for whole season

  final double gstPercentage; // Default 18%
  final bool isActive;

  // Audit fields
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  RentRate({
    this.id,
    required this.coldStorageName,
    required this.productName,
    required this.rentType,
    this.monthlyRatePerUnit,
    this.labourRatePerUnit,
    this.seasonalRatePerUnit,
    this.gstPercentage = 18.0,
    this.isActive = true,
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'coldStorageName': coldStorageName,
      'productName': productName,
      'rentType': rentType.toJson(),
      'monthlyRatePerUnit': monthlyRatePerUnit,
      'labourRatePerUnit': labourRatePerUnit,
      'seasonalRatePerUnit': seasonalRatePerUnit,
      'gstPercentage': gstPercentage,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'updatedBy': updatedBy,
    };
  }

  /// Create from Firestore document
  factory RentRate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RentRate(
      id: doc.id,
      coldStorageName: data['coldStorageName'] ?? '',
      productName: data['productName'] ?? '',
      rentType: RentType.fromJson(data['rentType'] ?? 'monthly'),
      monthlyRatePerUnit: data['monthlyRatePerUnit']?.toDouble(),
      labourRatePerUnit: data['labourRatePerUnit']?.toDouble(),
      seasonalRatePerUnit: data['seasonalRatePerUnit']?.toDouble(),
      gstPercentage: data['gstPercentage']?.toDouble() ?? 18.0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      updatedBy: data['updatedBy'],
    );
  }

  /// Create a copy with modified fields
  RentRate copyWith({
    String? id,
    String? coldStorageName,
    String? productName,
    RentType? rentType,
    double? monthlyRatePerUnit,
    double? labourRatePerUnit,
    double? seasonalRatePerUnit,
    double? gstPercentage,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return RentRate(
      id: id ?? this.id,
      coldStorageName: coldStorageName ?? this.coldStorageName,
      productName: productName ?? this.productName,
      rentType: rentType ?? this.rentType,
      monthlyRatePerUnit: monthlyRatePerUnit ?? this.monthlyRatePerUnit,
      labourRatePerUnit: labourRatePerUnit ?? this.labourRatePerUnit,
      seasonalRatePerUnit: seasonalRatePerUnit ?? this.seasonalRatePerUnit,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Validate that required fields are present based on rent type
  String? validate() {
    if (rentType == RentType.monthly) {
      if (monthlyRatePerUnit == null || monthlyRatePerUnit! <= 0) {
        return 'Monthly rate per unit is required';
      }
      if (labourRatePerUnit == null || labourRatePerUnit! < 0) {
        return 'Labour rate per unit is required (can be 0)';
      }
    } else if (rentType == RentType.seasonal) {
      if (seasonalRatePerUnit == null || seasonalRatePerUnit! <= 0) {
        return 'Seasonal rate per unit is required';
      }
    }
    return null; // Valid
  }

  @override
  String toString() {
    return 'RentRate($coldStorageName - $productName - ${rentType.displayName})';
  }
}
