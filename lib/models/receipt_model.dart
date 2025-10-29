// lib/models/receipt_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Receipt {
  final String? id;
  final String receiptNumber;
  final String coldStorageName;
  final Timestamp inwardDate;
  final String productName;
  final String brandName;
  final String companyName;
  final int inwardQuantity;
  final int remainingQuantity;
  final double rate;
  final String narration;
  final bool isPaid;
  final String status;
  final Timestamp? createdAt;

  // Rent-related fields
  final String rentType; // 'monthly' or 'seasonal'
  final double? monthlyRatePerUnit; // For monthly rent
  final double? labourRatePerUnit;  // For monthly rent
  final double? seasonalRatePerUnit; // For seasonal rent
  final double gstPercentage; // Default 18%

  // Rate locking fields (for bill immutability)
  final bool isRateLocked; // If true, rate is frozen and won't update from Rent Master
  final Timestamp? rateLockDate; // When the rate was locked
  final String? lockedByBillNumber; // Which bill locked this rate

  Receipt({
    this.id,
    required this.receiptNumber,
    required this.coldStorageName,
    required this.inwardDate,
    required this.productName,
    required this.brandName,
    required this.companyName,
    required this.inwardQuantity,
    required this.remainingQuantity,
    required this.rate,
    required this.narration,
    this.isPaid = false,
    this.status = 'Active',
    this.createdAt,
    this.rentType = 'monthly', // Default to monthly
    this.monthlyRatePerUnit,
    this.labourRatePerUnit,
    this.seasonalRatePerUnit,
    this.gstPercentage = 18.0,
    this.isRateLocked = false, // Default: use live rates from Rent Master
    this.rateLockDate,
    this.lockedByBillNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'receiptNumber': receiptNumber,
      'coldStorageName': coldStorageName,
      'inwardDate': inwardDate,
      'productName': productName,
      'brandName': brandName,
      'companyName': companyName,
      'inwardQuantity': inwardQuantity,
      'remainingQuantity': remainingQuantity,
      'rate': rate,
      'narration': narration,
      'isPaid': isPaid,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'rentType': rentType,
      'monthlyRatePerUnit': monthlyRatePerUnit,
      'labourRatePerUnit': labourRatePerUnit,
      'seasonalRatePerUnit': seasonalRatePerUnit,
      'gstPercentage': gstPercentage,
      'isRateLocked': isRateLocked,
      'rateLockDate': rateLockDate,
      'lockedByBillNumber': lockedByBillNumber,
    };
  }

  factory Receipt.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Receipt(
      id: doc.id,
      receiptNumber: data['receiptNumber'] ?? '',
      coldStorageName: data['coldStorageName'] ?? '',
      inwardDate: data['inwardDate'] ?? Timestamp.now(),
      productName: data['productName'] ?? '',
      brandName: data['brandName'] ?? '',
      companyName: data['companyName'] ?? '',
      inwardQuantity: data['inwardQuantity'] ?? 0,
      remainingQuantity: data['remainingQuantity'] ?? 0,
      rate: (data['rate'] as num?)?.toDouble() ?? 0.0,
      narration: data['narration'] ?? '',
      isPaid: data['isPaid'] ?? false,
      status: data['status'] ?? 'Active',
      createdAt: data['createdAt'],
      rentType: data['rentType'] ?? 'monthly', // Default to monthly for existing data
      monthlyRatePerUnit: data['monthlyRatePerUnit']?.toDouble(),
      labourRatePerUnit: data['labourRatePerUnit']?.toDouble(),
      seasonalRatePerUnit: data['seasonalRatePerUnit']?.toDouble(),
      gstPercentage: data['gstPercentage']?.toDouble() ?? 18.0,
      isRateLocked: data['isRateLocked'] ?? false, // Default to unlocked for existing receipts
      rateLockDate: data['rateLockDate'],
      lockedByBillNumber: data['lockedByBillNumber'],
    );
  }
  

  // --- ADD THIS METHOD ---
  // Creates a copy of the receipt with optional new values
  Receipt copyWith({
    String? id,
    String? receiptNumber,
    String? coldStorageName,
    Timestamp? inwardDate,
    String? productName,
    String? brandName,
    String? companyName,
    int? inwardQuantity,
    int? remainingQuantity,
    double? rate,
    String? narration,
    bool? isPaid,
    String? status,
    Timestamp? createdAt,
    String? rentType,
    double? monthlyRatePerUnit,
    double? labourRatePerUnit,
    double? seasonalRatePerUnit,
    double? gstPercentage,
    bool? isRateLocked,
    Timestamp? rateLockDate,
    String? lockedByBillNumber,
  }) {
    return Receipt(
      id: id ?? this.id,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      coldStorageName: coldStorageName ?? this.coldStorageName,
      inwardDate: inwardDate ?? this.inwardDate,
      productName: productName ?? this.productName,
      brandName: brandName ?? this.brandName,
      companyName: companyName ?? this.companyName,
      inwardQuantity: inwardQuantity ?? this.inwardQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      rate: rate ?? this.rate,
      narration: narration ?? this.narration,
      isPaid: isPaid ?? this.isPaid,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rentType: rentType ?? this.rentType,
      monthlyRatePerUnit: monthlyRatePerUnit ?? this.monthlyRatePerUnit,
      labourRatePerUnit: labourRatePerUnit ?? this.labourRatePerUnit,
      seasonalRatePerUnit: seasonalRatePerUnit ?? this.seasonalRatePerUnit,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      isRateLocked: isRateLocked ?? this.isRateLocked,
      rateLockDate: rateLockDate ?? this.rateLockDate,
      lockedByBillNumber: lockedByBillNumber ?? this.lockedByBillNumber,
    );
  }
}
