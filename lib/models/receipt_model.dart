// lib/models/receipt_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Receipt {
  final String? id;
  final String receiptNumber;
  final String coldStorageName;
  final Timestamp inwardDate;
  final String productName;
  final String brandName;
  final int inwardQuantity;
  final int remainingQuantity;
  final double rate;
  final String narration;
  final bool isPaid;
  final String status;
  final Timestamp? createdAt;

  Receipt({
    this.id,
    required this.receiptNumber,
    required this.coldStorageName,
    required this.inwardDate,
    required this.productName,
    required this.brandName,
    required this.inwardQuantity,
    required this.remainingQuantity,
    required this.rate,
    required this.narration,
    this.isPaid = false,
    this.status = 'Active',
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'receiptNumber': receiptNumber,
      'coldStorageName': coldStorageName,
      'inwardDate': inwardDate,
      'productName': productName,
      'brandName': brandName,
      'inwardQuantity': inwardQuantity,
      'remainingQuantity': remainingQuantity,
      'rate': rate,
      'narration': narration,
      'isPaid': isPaid,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory Receipt.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Receipt(
      id: doc.id,
      receiptNumber: data['receiptNumber'] ?? '',
      coldStorageName: data['coldStorageName'] ?? '',
      inwardDate: data['inwardDate'] ?? Timestamp.now(),
      productName: data['productName'] ?? '',
      brandName: data['brandName'] ?? '',
      inwardQuantity: data['inwardQuantity'] ?? 0,
      remainingQuantity: data['remainingQuantity'] ?? 0,
      rate: (data['rate'] as num?)?.toDouble() ?? 0.0,
      narration: data['narration'] ?? '',
      isPaid: data['isPaid'] ?? false,
      status: data['status'] ?? 'Active',
      createdAt: data['createdAt'],
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
    int? inwardQuantity,
    int? remainingQuantity,
    double? rate,
    String? narration,
    bool? isPaid,
    String? status,
    Timestamp? createdAt,
  }) {
    return Receipt(
      id: id ?? this.id,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      coldStorageName: coldStorageName ?? this.coldStorageName,
      inwardDate: inwardDate ?? this.inwardDate,
      productName: productName ?? this.productName,
      brandName: brandName ?? this.brandName,
      inwardQuantity: inwardQuantity ?? this.inwardQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      rate: rate ?? this.rate,
      narration: narration ?? this.narration,
      isPaid: isPaid ?? this.isPaid,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
