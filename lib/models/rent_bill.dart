// lib/models/rent_bill.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'rent_type.dart';
import 'rent_bill_item.dart';

/// Represents a complete rent bill for stored goods.
/// Contains all deliveries from a receipt along with calculated amounts.
class RentBill {
  final String? id;
  final String billNumber;
  final String receiptId;
  final String receiptNumber;
  final String coldStorageName;
  final String productName;
  final String companyName;
  final RentType rentType;
  final DateTime billDate;

  final List<RentBillItem> items;

  // Financial calculations
  final double totalQuantity;
  final double totalRentAmount;       // Sum of all line item amounts
  final double labourCharges;         // Only for monthly rent
  final double subtotalBeforeGst;     // totalRentAmount + labourCharges
  final double sgst;                  // 9%
  final double cgst;                  // 9%
  final double igst;                  // 0% (for same state)
  final double roundOff;              // Round-off adjustment to nearest rupee
  final double finalAmount;           // Grand total (rounded to nearest rupee)

  // Audit fields
  final DateTime createdAt;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  RentBill({
    this.id,
    required this.billNumber,
    required this.receiptId,
    required this.receiptNumber,
    required this.coldStorageName,
    required this.productName,
    required this.companyName,
    required this.rentType,
    required this.billDate,
    required this.items,
    required this.totalQuantity,
    required this.totalRentAmount,
    required this.labourCharges,
    required this.subtotalBeforeGst,
    required this.sgst,
    required this.cgst,
    required this.igst,
    this.roundOff = 0.0,
    required this.finalAmount,
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'billNumber': billNumber,
      'receiptId': receiptId,
      'receiptNumber': receiptNumber,
      'coldStorageName': coldStorageName,
      'productName': productName,
      'companyName': companyName,
      'rentType': rentType.toJson(),
      'billDate': Timestamp.fromDate(billDate),
      'items': items.map((item) => item.toJson()).toList(),
      'totalQuantity': totalQuantity,
      'totalRentAmount': totalRentAmount,
      'labourCharges': labourCharges,
      'subtotalBeforeGst': subtotalBeforeGst,
      'sgst': sgst,
      'cgst': cgst,
      'igst': igst,
      'roundOff': roundOff,
      'finalAmount': finalAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'updatedBy': updatedBy,
    };
  }

  /// Create from Firestore document
  factory RentBill.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final itemsList = (data['items'] as List<dynamic>?)
        ?.map((item) => RentBillItem.fromJson(item as Map<String, dynamic>))
        .toList() ?? [];

    // Safely parse Timestamps with null checks
    final billDateTimestamp = data['billDate'];
    final createdAtTimestamp = data['createdAt'];
    final updatedAtTimestamp = data['updatedAt'];

    return RentBill(
      id: doc.id,
      billNumber: data['billNumber'] ?? '',
      receiptId: data['receiptId'] ?? '',
      receiptNumber: data['receiptNumber'] ?? '',
      coldStorageName: data['coldStorageName'] ?? '',
      productName: data['productName'] ?? '',
      companyName: data['companyName'] ?? '',
      rentType: RentType.fromJson(data['rentType'] ?? 'monthly'),
      billDate: billDateTimestamp != null
          ? (billDateTimestamp as Timestamp).toDate()
          : DateTime.now(),
      items: itemsList,
      totalQuantity: data['totalQuantity']?.toDouble() ?? 0.0,
      totalRentAmount: data['totalRentAmount']?.toDouble() ?? 0.0,
      labourCharges: data['labourCharges']?.toDouble() ?? 0.0,
      subtotalBeforeGst: data['subtotalBeforeGst']?.toDouble() ?? 0.0,
      sgst: data['sgst']?.toDouble() ?? 0.0,
      cgst: data['cgst']?.toDouble() ?? 0.0,
      igst: data['igst']?.toDouble() ?? 0.0,
      roundOff: data['roundOff']?.toDouble() ?? 0.0,
      finalAmount: data['finalAmount']?.toDouble() ?? 0.0,
      createdAt: createdAtTimestamp != null
          ? (createdAtTimestamp as Timestamp).toDate()
          : DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      updatedAt: updatedAtTimestamp != null
          ? (updatedAtTimestamp as Timestamp).toDate()
          : null,
      updatedBy: data['updatedBy'],
    );
  }

  /// Create a copy with modified fields
  RentBill copyWith({
    String? id,
    String? billNumber,
    String? receiptId,
    String? receiptNumber,
    String? coldStorageName,
    String? productName,
    String? companyName,
    RentType? rentType,
    DateTime? billDate,
    List<RentBillItem>? items,
    double? totalQuantity,
    double? totalRentAmount,
    double? labourCharges,
    double? subtotalBeforeGst,
    double? sgst,
    double? cgst,
    double? igst,
    double? roundOff,
    double? finalAmount,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return RentBill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      receiptId: receiptId ?? this.receiptId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      coldStorageName: coldStorageName ?? this.coldStorageName,
      productName: productName ?? this.productName,
      companyName: companyName ?? this.companyName,
      rentType: rentType ?? this.rentType,
      billDate: billDate ?? this.billDate,
      items: items ?? this.items,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      totalRentAmount: totalRentAmount ?? this.totalRentAmount,
      labourCharges: labourCharges ?? this.labourCharges,
      subtotalBeforeGst: subtotalBeforeGst ?? this.subtotalBeforeGst,
      sgst: sgst ?? this.sgst,
      cgst: cgst ?? this.cgst,
      igst: igst ?? this.igst,
      roundOff: roundOff ?? this.roundOff,
      finalAmount: finalAmount ?? this.finalAmount,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() {
    return 'RentBill($billNumber - $companyName - ₹$finalAmount)';
  }
}
