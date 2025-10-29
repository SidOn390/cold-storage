// lib/services/data_purge_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cold_storage/models/receipt_model.dart';

/// Service for purging old data to maintain database performance.
///
/// Provides functionality to:
/// - Identify receipts older than retention period (3 years)
/// - Preview data to be deleted
/// - Perform cascading deletion (receipts → deliveries → rent bills)
/// - Safety checks (only delete fully delivered receipts)
class DataPurgeService {
  DataPurgeService._();
  static final DataPurgeService instance = DataPurgeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Data retention period in years (current year + past 2 years = 3 years total)
  static const int retentionYears = 3;

  /// Calculate the cutoff date (beginning of the year that's 3 years old)
  /// Example: In 2025, returns Jan 1, 2023 (keeps 2025, 2024, 2023)
  DateTime getCutoffDate() {
    final now = DateTime.now();
    final cutoffYear = now.year - (retentionYears - 1);
    return DateTime(cutoffYear, 1, 1); // Jan 1 of cutoff year
  }

  /// Get statistics about old data that can be purged
  Future<PurgeStatistics> getOldDataStatistics() async {
    try {
      final cutoffDate = getCutoffDate();
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      debugPrint('📊 Calculating purge statistics for data before: ${cutoffDate.toString().split(' ')[0]}');

      // Get old receipts
      final oldReceiptsSnapshot = await _firestore
          .collection('receipts')
          .where('inwardDate', isLessThan: cutoffTimestamp)
          .get();

      final oldReceipts = oldReceiptsSnapshot.docs
          .map((doc) => Receipt.fromFirestore(doc))
          .toList();

      // Separate into deletable and non-deletable
      final deletableReceipts = oldReceipts.where((r) => r.remainingQuantity == 0).toList();
      final nonDeletableReceipts = oldReceipts.where((r) => r.remainingQuantity != 0).toList();

      // Count related deliveries for deletable receipts
      int totalDeliveries = 0;
      for (final receipt in deletableReceipts) {
        final deliveriesSnapshot = await _firestore
            .collection('deliveries')
            .where('receiptNumber', isEqualTo: receipt.receiptNumber)
            .where('coldStorageName', isEqualTo: receipt.coldStorageName)
            .count()
            .get();
        totalDeliveries += deliveriesSnapshot.count ?? 0;
      }

      // Count related rent bills for deletable receipts
      int totalBills = 0;
      for (final receipt in deletableReceipts) {
        if (receipt.id != null) {
          final billsSnapshot = await _firestore
              .collection('rent_bills')
              .where('receiptId', isEqualTo: receipt.id)
              .count()
              .get();
          totalBills += billsSnapshot.count ?? 0;
        }
      }

      final stats = PurgeStatistics(
        cutoffDate: cutoffDate,
        totalOldReceipts: oldReceipts.length,
        deletableReceipts: deletableReceipts.length,
        nonDeletableReceipts: nonDeletableReceipts.length,
        relatedDeliveries: totalDeliveries,
        relatedBills: totalBills,
        deletableReceiptsList: deletableReceipts,
        nonDeletableReceiptsList: nonDeletableReceipts,
      );

      debugPrint('✅ Statistics: ${stats.deletableReceipts} deletable, ${stats.nonDeletableReceipts} non-deletable (incomplete)');
      return stats;
    } catch (e) {
      debugPrint('❌ Error getting purge statistics: $e');
      rethrow;
    }
  }

  /// Preview receipts that will be deleted (for display purposes)
  Future<List<Receipt>> previewDeletableReceipts() async {
    try {
      final stats = await getOldDataStatistics();
      return stats.deletableReceiptsList;
    } catch (e) {
      debugPrint('❌ Error previewing deletable receipts: $e');
      rethrow;
    }
  }

  /// Purge old data (receipts + related deliveries + rent bills)
  /// Only deletes receipts with remainingQuantity = 0 (fully delivered)
  /// Returns the number of items deleted
  Future<PurgeResult> purgeOldData() async {
    try {
      final stats = await getOldDataStatistics();

      if (stats.deletableReceipts == 0) {
        debugPrint('ℹ️ No data to purge');
        return PurgeResult(
          receiptsDeleted: 0,
          deliveriesDeleted: 0,
          billsDeleted: 0,
          skippedReceipts: stats.nonDeletableReceipts,
        );
      }

      debugPrint('🗑️ Starting purge: ${stats.deletableReceipts} receipts, ${stats.relatedDeliveries} deliveries, ${stats.relatedBills} bills');

      int receiptsDeleted = 0;
      int deliveriesDeleted = 0;
      int billsDeleted = 0;

      // Use batched writes for efficiency (500 operations per batch max)
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;
      const int maxBatchSize = 400; // Leave some room for safety

      for (final receipt in stats.deletableReceiptsList) {
        // Delete related deliveries
        final deliveriesSnapshot = await _firestore
            .collection('deliveries')
            .where('receiptNumber', isEqualTo: receipt.receiptNumber)
            .where('coldStorageName', isEqualTo: receipt.coldStorageName)
            .get();

        for (final deliveryDoc in deliveriesSnapshot.docs) {
          batch.delete(deliveryDoc.reference);
          batchCount++;
          deliveriesDeleted++;

          if (batchCount >= maxBatchSize) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }

        // Delete related rent bills
        if (receipt.id != null) {
          final billsSnapshot = await _firestore
              .collection('rent_bills')
              .where('receiptId', isEqualTo: receipt.id)
              .get();

          for (final billDoc in billsSnapshot.docs) {
            batch.delete(billDoc.reference);
            batchCount++;
            billsDeleted++;

            if (batchCount >= maxBatchSize) {
              await batch.commit();
              batch = _firestore.batch();
              batchCount = 0;
            }
          }
        }

        // Delete the receipt itself
        if (receipt.id != null) {
          final receiptRef = _firestore.collection('receipts').doc(receipt.id);
          batch.delete(receiptRef);
          batchCount++;
          receiptsDeleted++;

          if (batchCount >= maxBatchSize) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }
      }

      // Commit remaining operations
      if (batchCount > 0) {
        await batch.commit();
      }

      final result = PurgeResult(
        receiptsDeleted: receiptsDeleted,
        deliveriesDeleted: deliveriesDeleted,
        billsDeleted: billsDeleted,
        skippedReceipts: stats.nonDeletableReceipts,
      );

      debugPrint('✅ Purge complete: $receiptsDeleted receipts, $deliveriesDeleted deliveries, $billsDeleted bills deleted');
      return result;
    } catch (e) {
      debugPrint('❌ Error during purge: $e');
      rethrow;
    }
  }
}

/// Statistics about old data available for purging
class PurgeStatistics {
  final DateTime cutoffDate;
  final int totalOldReceipts;
  final int deletableReceipts; // Fully delivered (remaining = 0)
  final int nonDeletableReceipts; // Still have remaining stock
  final int relatedDeliveries;
  final int relatedBills;
  final List<Receipt> deletableReceiptsList;
  final List<Receipt> nonDeletableReceiptsList;

  PurgeStatistics({
    required this.cutoffDate,
    required this.totalOldReceipts,
    required this.deletableReceipts,
    required this.nonDeletableReceipts,
    required this.relatedDeliveries,
    required this.relatedBills,
    required this.deletableReceiptsList,
    required this.nonDeletableReceiptsList,
  });

  String get cutoffDateString => '${cutoffDate.day.toString().padLeft(2, '0')}-${cutoffDate.month.toString().padLeft(2, '0')}-${cutoffDate.year}';
}

/// Result of purge operation
class PurgeResult {
  final int receiptsDeleted;
  final int deliveriesDeleted;
  final int billsDeleted;
  final int skippedReceipts;

  PurgeResult({
    required this.receiptsDeleted,
    required this.deliveriesDeleted,
    required this.billsDeleted,
    required this.skippedReceipts,
  });

  int get totalDeleted => receiptsDeleted + deliveriesDeleted + billsDeleted;
}
