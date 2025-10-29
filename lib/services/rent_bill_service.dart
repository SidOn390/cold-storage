// lib/services/rent_bill_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cold_storage/models/rent_bill.dart';
import 'package:cold_storage/models/rent_bill_item.dart';
import 'package:cold_storage/models/rent_type.dart';
import 'package:cold_storage/models/receipt_model.dart';
import 'package:cold_storage/services/rent_calculation_service.dart';

/// Service for managing rent bills with Firestore integration.
///
/// Handles bill generation, CRUD operations, and bill number management.
class RentBillService {
  RentBillService._();
  static final RentBillService instance = RentBillService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'rent_bills';
  final RentCalculationService _calcService = RentCalculationService.instance;

  /// Get all rent bills as a stream
  Stream<List<RentBill>> getRentBillsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('billDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => RentBill.fromFirestore(doc)).toList();
    });
  }

  /// Get all rent bills (one-time fetch)
  Future<List<RentBill>> getRentBills() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('billDate', descending: true)
          .get();

      return snapshot.docs.map((doc) => RentBill.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching rent bills: $e');
      rethrow;
    }
  }

  /// Get rent bill by ID
  Future<RentBill?> getRentBillById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return RentBill.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching rent bill by ID: $e');
      rethrow;
    }
  }

  /// Get rent bills for a specific company
  Future<List<RentBill>> getBillsForCompany(String companyName) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyName', isEqualTo: companyName)
          .orderBy('billDate', descending: true)
          .get();

      return snapshot.docs.map((doc) => RentBill.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching bills for company: $e');
      rethrow;
    }
  }

  /// Get rent bills for a specific receipt
  Future<List<RentBill>> getBillsForReceipt(String receiptId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('receiptId', isEqualTo: receiptId)
          .orderBy('billDate', descending: true)
          .get();

      return snapshot.docs.map((doc) => RentBill.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching bills for receipt: $e');
      rethrow;
    }
  }

  /// Get rent bills for a date range
  Future<List<RentBill>> getBillsForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('billDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('billDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('billDate', descending: true)
          .get();

      return snapshot.docs.map((doc) => RentBill.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching bills for date range: $e');
      rethrow;
    }
  }

  /// Generate bill number (format: 5-digit incremental)
  Future<String> generateBillNumber() async {
    try {
      // Get the latest bill to determine next number
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('billNumber', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return '00001'; // First bill
      }

      final lastBillNumber = snapshot.docs.first.data()['billNumber'] as String;
      final lastNumber = int.tryParse(lastBillNumber) ?? 0;
      final nextNumber = lastNumber + 1;

      return nextNumber.toString().padLeft(5, '0');
    } catch (e) {
      debugPrint('❌ Error generating bill number: $e');
      // Fallback: use timestamp-based number
      return DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    }
  }

  /// Generate rent bill from receipt and its deliveries
  Future<RentBill> generateBillFromReceipt({
    required Receipt receipt,
    required List<Map<String, dynamic>> deliveries, // List of delivery data
    required String createdBy,
  }) async {
    try {
      debugPrint('📝 Generating rent bill for receipt: ${receipt.receiptNumber}');

      // Validate receipt has rent information
      if (receipt.rentType != 'monthly' && receipt.rentType != 'seasonal') {
        throw Exception('Invalid rent type in receipt');
      }

      final rentType = RentType.fromJson(receipt.rentType);

      // Build bill items from deliveries
      final List<RentBillItem> billItems = [];
      double totalRentAmount = 0.0;
      double totalQuantity = 0.0;

      for (final delivery in deliveries) {
        final outwardDate = (delivery['deliveryDate'] as Timestamp).toDate();
        final inwardDate = receipt.inwardDate.toDate();
        final quantity = (delivery['quantity'] as num).toDouble();
        // Use delivery ID as DC number if no deliveryNumber field exists
        final dcNumber = (delivery['deliveryNumber'] as String?) ??
                        (delivery['id'] as String?) ??
                        'DC-${DateTime.now().millisecondsSinceEpoch}';

        // Calculate days and months
        final days = outwardDate.difference(inwardDate).inDays + 1;
        final months = rentType == RentType.monthly
            ? _calcService.calculateMonths(inwardDate, outwardDate)
            : 0.0;

        // Calculate amount based on rent type
        double amount = 0.0;
        double ratePerUnit = 0.0;

        if (rentType == RentType.monthly) {
          ratePerUnit = receipt.monthlyRatePerUnit ?? 0.0;
          amount = _calcService.calculateMonthlyRentAmount(
            quantity: quantity,
            months: months,
            ratePerUnit: ratePerUnit,
          );
        } else {
          ratePerUnit = receipt.seasonalRatePerUnit ?? 0.0;
          amount = _calcService.calculateSeasonalRentAmount(
            quantity: quantity,
            ratePerUnit: ratePerUnit,
          );
        }

        // Create bill item
        final item = RentBillItem(
          deliveryId: delivery['id'] as String? ?? '',
          dcNumber: dcNumber,
          quantity: quantity,
          inwardDate: inwardDate,
          outwardDate: outwardDate,
          daysStored: days,
          months: months,
          ratePerUnit: ratePerUnit,
          amount: amount,
          gpNumber: receipt.receiptNumber,
        );

        billItems.add(item);
        totalRentAmount += amount;
        totalQuantity += quantity;
      }

      // Calculate labour charges (only for monthly rent)
      double labourCharges = 0.0;
      if (rentType == RentType.monthly) {
        final labourRate = receipt.labourRatePerUnit ?? 0.0;
        labourCharges = _calcService.calculateLabourCharges(
          totalReceiptQuantity: receipt.inwardQuantity.toDouble(),
          labourRatePerUnit: labourRate,
        );
      }

      // Calculate totals
      final totals = _calcService.calculateBillTotals(
        totalRentAmount: totalRentAmount,
        labourCharges: labourCharges,
        gstPercentage: receipt.gstPercentage,
      );

      // Generate bill number
      final billNumber = await generateBillNumber();

      // Create rent bill
      final rentBill = RentBill(
        billNumber: billNumber,
        receiptId: receipt.id ?? '',
        receiptNumber: receipt.receiptNumber,
        coldStorageName: receipt.coldStorageName,
        productName: receipt.productName,
        companyName: receipt.companyName,
        rentType: rentType,
        billDate: DateTime.now(),
        items: billItems,
        totalQuantity: totalQuantity,
        totalRentAmount: totals['totalRentAmount']!,
        labourCharges: totals['labourCharges']!,
        subtotalBeforeGst: totals['subtotalBeforeGst']!,
        sgst: totals['sgst']!,
        cgst: totals['cgst']!,
        igst: totals['igst']!,
        roundOff: totals['roundOff']!,
        finalAmount: totals['finalAmount']!,
        createdAt: DateTime.now(),
        createdBy: createdBy,
      );

      debugPrint('✅ Rent bill generated: ${rentBill.billNumber} - ₹${rentBill.finalAmount}');
      return rentBill;
    } catch (e) {
      debugPrint('❌ Error generating rent bill: $e');
      rethrow;
    }
  }

  /// Save rent bill to Firestore
  Future<String> saveBill(RentBill bill) async {
    try {
      final docRef = await _firestore.collection(_collection).add(bill.toJson());
      debugPrint('✅ Rent bill saved with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error saving rent bill: $e');
      rethrow;
    }
  }

  /// Update an existing rent bill
  Future<void> updateBill(RentBill bill) async {
    try {
      if (bill.id == null) {
        throw Exception('Cannot update rent bill without ID');
      }

      await _firestore
          .collection(_collection)
          .doc(bill.id)
          .update(bill.toJson());

      debugPrint('✅ Rent bill updated: ${bill.id}');
    } catch (e) {
      debugPrint('❌ Error updating rent bill: $e');
      rethrow;
    }
  }

  /// Delete a rent bill
  Future<void> deleteBill(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      debugPrint('✅ Rent bill deleted: $id');
    } catch (e) {
      debugPrint('❌ Error deleting rent bill: $e');
      rethrow;
    }
  }

  /// Get statistics about rent bills
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final bills = await getRentBills();

      final totalBills = bills.length;
      final totalAmount = bills.fold<double>(
        0.0,
        (total, bill) => total + bill.finalAmount,
      );

      final monthlyBills = bills.where((b) => b.rentType == RentType.monthly).length;
      final seasonalBills = bills.where((b) => b.rentType == RentType.seasonal).length;

      return {
        'totalBills': totalBills,
        'totalAmount': totalAmount,
        'monthlyBills': monthlyBills,
        'seasonalBills': seasonalBills,
      };
    } catch (e) {
      debugPrint('❌ Error getting statistics: $e');
      return {
        'totalBills': 0,
        'totalAmount': 0.0,
        'monthlyBills': 0,
        'seasonalBills': 0,
      };
    }
  }
}
