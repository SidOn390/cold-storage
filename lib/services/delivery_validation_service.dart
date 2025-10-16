// File: lib/services/delivery_validation_service.dart
//
// Comprehensive delivery quantity validation service.
// Calculates remaining quantity by querying actual delivery records,
// ensuring accuracy even if manual updates were made.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cold_storage/models/receipt_model.dart';
import 'package:flutter/foundation.dart';

/// Result of a delivery validation check.
class DeliveryValidationResult {
  const DeliveryValidationResult({
    required this.isValid,
    required this.inwardQuantity,
    required this.totalDelivered,
    required this.remainingQuantity,
    required this.attemptedQuantity,
    this.errorMessage,
    this.deliveryCount = 0,
  });

  final bool isValid;
  final int inwardQuantity;
  final int totalDelivered;
  final int remainingQuantity;
  final int attemptedQuantity;
  final String? errorMessage;
  final int deliveryCount;

  @override
  String toString() {
    if (isValid) {
      return 'Valid: $remainingQuantity remaining (attempted: $attemptedQuantity)';
    }
    return 'Invalid: $errorMessage';
  }
}

/// Service for validating delivery quantities against actual data.
class DeliveryValidationService {
  DeliveryValidationService() : _db = FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Calculate the actual remaining quantity for a receipt by querying deliveries.
  /// This is the SOURCE OF TRUTH - always recalculates from actual data.
  Future<int> calculateRemainingQuantity({
    required String receiptNumber,
    required String coldStorageName,
    required int inwardQuantity,
    String? excludeDeliveryId,
  }) async {
    try {
      // Get all deliveries for this receipt
      var query = _db
          .collection('deliveries')
          .where('receiptNumber', isEqualTo: receiptNumber)
          .where('coldStorageName', isEqualTo: coldStorageName);

      final snapshot = await query.get();

      // Sum up all delivered quantities (excluding the specified delivery if editing)
      int totalDelivered = 0;
      for (final doc in snapshot.docs) {
        if (excludeDeliveryId != null && doc.id == excludeDeliveryId) {
          continue; // Skip this delivery (we're editing it)
        }
        totalDelivered += (doc['quantity'] as int?) ?? 0;
      }

      final remaining = inwardQuantity - totalDelivered;

      debugPrint(
        '📊 Remaining calculation: $inwardQuantity (inward) - $totalDelivered (delivered) = $remaining',
      );

      return remaining;
    } catch (e, stackTrace) {
      debugPrint('❌ Error calculating remaining quantity: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  /// Get all deliveries for a specific receipt.
  Future<List<Map<String, dynamic>>> getDeliveriesForReceipt({
    required String receiptNumber,
    required String coldStorageName,
  }) async {
    final snapshot = await _db
        .collection('deliveries')
        .where('receiptNumber', isEqualTo: receiptNumber)
        .where('coldStorageName', isEqualTo: coldStorageName)
        .orderBy('deliveryDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => {
              'id': doc.id,
              'quantity': doc['quantity'] as int,
              'deliveryDate': doc['deliveryDate'] as Timestamp,
              'narration': doc['narration'] as String?,
            })
        .toList();
  }

  /// Validate a delivery quantity against actual remaining stock.
  /// Use this before creating or updating a delivery.
  Future<DeliveryValidationResult> validateDelivery({
    required Receipt receipt,
    required int attemptedQuantity,
    String? excludeDeliveryId,
  }) async {
    try {
      // Calculate actual remaining quantity
      final remaining = await calculateRemainingQuantity(
        receiptNumber: receipt.receiptNumber,
        coldStorageName: receipt.coldStorageName,
        inwardQuantity: receipt.inwardQuantity,
        excludeDeliveryId: excludeDeliveryId,
      );

      final totalDelivered = receipt.inwardQuantity - remaining;

      // Get delivery count for reporting
      final deliveries = await getDeliveriesForReceipt(
        receiptNumber: receipt.receiptNumber,
        coldStorageName: receipt.coldStorageName,
      );

      // Validate
      if (attemptedQuantity <= 0) {
        return DeliveryValidationResult(
          isValid: false,
          inwardQuantity: receipt.inwardQuantity,
          totalDelivered: totalDelivered,
          remainingQuantity: remaining,
          attemptedQuantity: attemptedQuantity,
          errorMessage: 'Quantity must be greater than zero',
          deliveryCount: deliveries.length,
        );
      }

      if (attemptedQuantity > remaining) {
        return DeliveryValidationResult(
          isValid: false,
          inwardQuantity: receipt.inwardQuantity,
          totalDelivered: totalDelivered,
          remainingQuantity: remaining,
          attemptedQuantity: attemptedQuantity,
          errorMessage:
              'Quantity ($attemptedQuantity) exceeds available stock ($remaining)',
          deliveryCount: deliveries.length,
        );
      }

      return DeliveryValidationResult(
        isValid: true,
        inwardQuantity: receipt.inwardQuantity,
        totalDelivered: totalDelivered,
        remainingQuantity: remaining,
        attemptedQuantity: attemptedQuantity,
        deliveryCount: deliveries.length,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Delivery validation error: $e');
      debugPrint(stackTrace.toString());
      return DeliveryValidationResult(
        isValid: false,
        inwardQuantity: receipt.inwardQuantity,
        totalDelivered: 0,
        remainingQuantity: 0,
        attemptedQuantity: attemptedQuantity,
        errorMessage: 'Validation error: $e',
      );
    }
  }

  /// Recalculate and sync the remainingQuantity field in a receipt document.
  /// This fixes any discrepancies between stored value and actual deliveries.
  Future<void> syncReceiptRemainingQuantity({
    required String receiptId,
    required String receiptNumber,
    required String coldStorageName,
    required int inwardQuantity,
  }) async {
    try {
      final actualRemaining = await calculateRemainingQuantity(
        receiptNumber: receiptNumber,
        coldStorageName: coldStorageName,
        inwardQuantity: inwardQuantity,
      );

      await _db.collection('receipts').doc(receiptId).update({
        'remainingQuantity': actualRemaining,
      });

      debugPrint(
        '✅ Synced remaining quantity for receipt $receiptNumber: $actualRemaining',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error syncing remaining quantity: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  /// Batch sync all receipts' remaining quantities.
  /// Useful for data integrity maintenance or after bulk operations.
  Future<int> syncAllReceiptsRemainingQuantity() async {
    try {
      debugPrint('🔄 Starting batch sync of all receipt remaining quantities...');

      final receiptsSnapshot = await _db.collection('receipts').get();
      final batch = _db.batch();
      int syncCount = 0;

      for (final doc in receiptsSnapshot.docs) {
        final receiptNumber = doc['receiptNumber'] as String;
        final coldStorageName = doc['coldStorageName'] as String;
        final inwardQuantity = doc['inwardQuantity'] as int;
        final storedRemaining = doc['remainingQuantity'] as int;

        // Calculate actual remaining
        final actualRemaining = await calculateRemainingQuantity(
          receiptNumber: receiptNumber,
          coldStorageName: coldStorageName,
          inwardQuantity: inwardQuantity,
        );

        // Only update if different
        if (actualRemaining != storedRemaining) {
          batch.update(doc.reference, {'remainingQuantity': actualRemaining});
          syncCount++;
          debugPrint(
            '  📝 Receipt $receiptNumber: $storedRemaining → $actualRemaining',
          );
        }
      }

      if (syncCount > 0) {
        await batch.commit();
        debugPrint('✅ Batch sync complete: $syncCount receipts updated');
      } else {
        debugPrint('✅ All receipts already in sync');
      }

      return syncCount;
    } catch (e, stackTrace) {
      debugPrint('❌ Batch sync error: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  /// Get a summary of deliveries for a receipt.
  Future<Map<String, dynamic>> getReceiptDeliverySummary({
    required String receiptNumber,
    required String coldStorageName,
    required int inwardQuantity,
  }) async {
    final deliveries = await getDeliveriesForReceipt(
      receiptNumber: receiptNumber,
      coldStorageName: coldStorageName,
    );

    final totalDelivered = deliveries.fold<int>(
      0,
      (sum, delivery) => sum + (delivery['quantity'] as int),
    );

    final remaining = inwardQuantity - totalDelivered;

    return {
      'receiptNumber': receiptNumber,
      'coldStorageName': coldStorageName,
      'inwardQuantity': inwardQuantity,
      'totalDelivered': totalDelivered,
      'remainingQuantity': remaining,
      'deliveryCount': deliveries.length,
      'deliveries': deliveries,
      'utilizationPercentage':
          inwardQuantity > 0 ? (totalDelivered / inwardQuantity * 100) : 0.0,
    };
  }
}
