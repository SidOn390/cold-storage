// lib/models/delivery_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Delivery {
  final String? id;
  final String coldStorageName;
  final String receiptNumber;
  final int quantity;
  final String narration;
  final Timestamp deliveryDate;

  Delivery({
    this.id,
    required this.coldStorageName,
    required this.receiptNumber,
    required this.quantity,
    required this.narration,
    required this.deliveryDate,
  });

  // Converts a Delivery object into a Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'coldStorageName': coldStorageName,
      'receiptNumber': receiptNumber,
      'quantity': quantity,
      'narration': narration,
      'deliveryDate': deliveryDate,
    };
  }

  // Creates a Delivery object from a Firestore document
  factory Delivery.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Delivery(
      id: doc.id,
      coldStorageName: data['coldStorageName'],
      receiptNumber: data['receiptNumber'],
      quantity: data['quantity'],
      narration: data['narration'],
      deliveryDate: data['deliveryDate'],
    );
  }
}
