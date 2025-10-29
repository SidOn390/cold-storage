// lib/models/rent_bill_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single line item in a rent bill.
/// Each item corresponds to a delivery from a receipt.
class RentBillItem {
  final String deliveryId;
  final String dcNumber;      // Delivery challan number
  final double quantity;
  final DateTime inwardDate;
  final DateTime outwardDate;
  final int daysStored;
  final double months;        // For monthly rent (in 0.5 increments)
  final double ratePerUnit;
  final double amount;
  final String gpNumber;      // Receipt/GP number

  RentBillItem({
    required this.deliveryId,
    required this.dcNumber,
    required this.quantity,
    required this.inwardDate,
    required this.outwardDate,
    required this.daysStored,
    required this.months,
    required this.ratePerUnit,
    required this.amount,
    required this.gpNumber,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toJson() {
    return {
      'deliveryId': deliveryId,
      'dcNumber': dcNumber,
      'quantity': quantity,
      'inwardDate': Timestamp.fromDate(inwardDate),
      'outwardDate': Timestamp.fromDate(outwardDate),
      'daysStored': daysStored,
      'months': months,
      'ratePerUnit': ratePerUnit,
      'amount': amount,
      'gpNumber': gpNumber,
    };
  }

  /// Create from Firestore map
  factory RentBillItem.fromJson(Map<String, dynamic> json) {
    // Safely parse Timestamps with null checks
    final inwardTimestamp = json['inwardDate'];
    final outwardTimestamp = json['outwardDate'];

    return RentBillItem(
      deliveryId: json['deliveryId'] ?? '',
      dcNumber: json['dcNumber'] ?? '',
      quantity: json['quantity']?.toDouble() ?? 0.0,
      inwardDate: inwardTimestamp != null
          ? (inwardTimestamp as Timestamp).toDate()
          : DateTime.now(),
      outwardDate: outwardTimestamp != null
          ? (outwardTimestamp as Timestamp).toDate()
          : DateTime.now(),
      daysStored: json['daysStored'] ?? 0,
      months: json['months']?.toDouble() ?? 0.0,
      ratePerUnit: json['ratePerUnit']?.toDouble() ?? 0.0,
      amount: json['amount']?.toDouble() ?? 0.0,
      gpNumber: json['gpNumber'] ?? '',
    );
  }

  /// Create a copy with modified fields
  RentBillItem copyWith({
    String? deliveryId,
    String? dcNumber,
    double? quantity,
    DateTime? inwardDate,
    DateTime? outwardDate,
    int? daysStored,
    double? months,
    double? ratePerUnit,
    double? amount,
    String? gpNumber,
  }) {
    return RentBillItem(
      deliveryId: deliveryId ?? this.deliveryId,
      dcNumber: dcNumber ?? this.dcNumber,
      quantity: quantity ?? this.quantity,
      inwardDate: inwardDate ?? this.inwardDate,
      outwardDate: outwardDate ?? this.outwardDate,
      daysStored: daysStored ?? this.daysStored,
      months: months ?? this.months,
      ratePerUnit: ratePerUnit ?? this.ratePerUnit,
      amount: amount ?? this.amount,
      gpNumber: gpNumber ?? this.gpNumber,
    );
  }

  @override
  String toString() {
    return 'RentBillItem(DC: $dcNumber, Qty: $quantity, Days: $daysStored, Amount: $amount)';
  }
}
