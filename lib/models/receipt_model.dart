import 'package:cloud_firestore/cloud_firestore.dart';

class Receipt {
  final String? id; // To store the document ID from Firestore
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

  // A method to convert a Receipt instance into a map, for saving to Firestore.
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

  // A factory constructor to create a Receipt instance from a Firestore document.
  factory Receipt.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Receipt(
      id: doc.id,
      receiptNumber: data['receiptNumber'],
      coldStorageName: data['coldStorageName'],
      inwardDate: data['inwardDate'],
      productName: data['productName'],
      brandName: data['brandName'],
      inwardQuantity: data['inwardQuantity'],
      remainingQuantity: data['remainingQuantity'],
      rate: (data['rate'] as num?)?.toDouble() ?? 0.0,
      narration: data['narration'],
      isPaid: data['isPaid'],
      status: data['status'],
      createdAt: data['createdAt'],
    );
  }
}
