// File: lib/services/referential_integrity_service.dart
//
// Comprehensive referential integrity management for Cold Storage app.
// Handles detection, prevention, and cascading operations for master data.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Result of a referential integrity check.
class IntegrityCheckResult {
  const IntegrityCheckResult({
    required this.isInUse,
    required this.affectedCollections,
    this.affectedCount = 0,
    this.details,
  });

  final bool isInUse;
  final List<String> affectedCollections;
  final int affectedCount;
  final Map<String, dynamic>? details;

  @override
  String toString() {
    if (!isInUse) return 'Not in use';
    return 'In use: $affectedCount references across ${affectedCollections.join(", ")}';
  }
}

/// Service for managing referential integrity across collections.
class ReferentialIntegrityService {
  ReferentialIntegrityService() : _db = FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ========== DELETION CHECKS ==========

  /// Comprehensive check if a cold storage is used anywhere.
  /// Checks both receipts and deliveries collections.
  Future<IntegrityCheckResult> checkColdStorageUsage(
    String coldStorageName,
  ) async {
    final results = await Future.wait([
      _db
          .collection('receipts')
          .where('coldStorageName', isEqualTo: coldStorageName)
          .count()
          .get(),
      _db
          .collection('deliveries')
          .where('coldStorageName', isEqualTo: coldStorageName)
          .count()
          .get(),
    ]);

    final receiptCount = results[0].count;
    final deliveryCount = results[1].count;
    final totalCount = (receiptCount ?? 0) + (deliveryCount ?? 0);

    final affectedCollections = <String>[];
    if (receiptCount != null && receiptCount > 0) {
      affectedCollections.add('receipts');
    }
    if (deliveryCount != null && deliveryCount > 0) {
      affectedCollections.add('deliveries');
    }

    return IntegrityCheckResult(
      isInUse: totalCount > 0,
      affectedCollections: affectedCollections,
      affectedCount: totalCount,
      details: {
        'receiptCount': receiptCount ?? 0,
        'deliveryCount': deliveryCount ?? 0,
      },
    );
  }

  /// Check if a product is used in receipts.
  Future<IntegrityCheckResult> checkProductUsage(String productName) async {
    final count = await _db
        .collection('receipts')
        .where('productName', isEqualTo: productName)
        .count()
        .get();

    final receiptCount = count.count ?? 0;

    return IntegrityCheckResult(
      isInUse: receiptCount > 0,
      affectedCollections: receiptCount > 0 ? ['receipts'] : [],
      affectedCount: receiptCount,
      details: {'receiptCount': receiptCount},
    );
  }

  /// Check if a brand is used in receipts.
  Future<IntegrityCheckResult> checkBrandUsage(String brandName) async {
    final count = await _db
        .collection('receipts')
        .where('brandName', isEqualTo: brandName)
        .count()
        .get();

    final receiptCount = count.count ?? 0;

    return IntegrityCheckResult(
      isInUse: receiptCount > 0,
      affectedCollections: receiptCount > 0 ? ['receipts'] : [],
      affectedCount: receiptCount,
      details: {'receiptCount': receiptCount},
    );
  }

  /// Check if a company is used in receipts.
  Future<IntegrityCheckResult> checkCompanyUsage(String companyName) async {
    final count = await _db
        .collection('receipts')
        .where('companyName', isEqualTo: companyName)
        .count()
        .get();

    final receiptCount = count.count ?? 0;

    return IntegrityCheckResult(
      isInUse: receiptCount > 0,
      affectedCollections: receiptCount > 0 ? ['receipts'] : [],
      affectedCount: receiptCount,
      details: {'receiptCount': receiptCount},
    );
  }

  /// Check if a receipt can be deleted (has no deliveries).
  Future<IntegrityCheckResult> checkReceiptDeletion({
    required String receiptNumber,
    required String coldStorageName,
  }) async {
    final count = await _db
        .collection('deliveries')
        .where('receiptNumber', isEqualTo: receiptNumber)
        .where('coldStorageName', isEqualTo: coldStorageName)
        .count()
        .get();

    final deliveryCount = count.count ?? 0;

    return IntegrityCheckResult(
      isInUse: deliveryCount > 0,
      affectedCollections: deliveryCount > 0 ? ['deliveries'] : [],
      affectedCount: deliveryCount,
      details: {'deliveryCount': deliveryCount},
    );
  }

  // ========== CASCADE UPDATE OPERATIONS ==========

  /// Update all references to a cold storage name across all collections.
  /// This is a CASCADE UPDATE operation.
  Future<void> cascadeUpdateColdStorage({
    required String oldName,
    required String newName,
  }) async {
    debugPrint('🔄 CASCADE UPDATE: Cold Storage "$oldName" → "$newName"');

    final batch = _db.batch();
    int updateCount = 0;

    // Update receipts
    final receipts = await _db
        .collection('receipts')
        .where('coldStorageName', isEqualTo: oldName)
        .get();

    for (final doc in receipts.docs) {
      batch.update(doc.reference, {'coldStorageName': newName});
      updateCount++;
    }

    // Update deliveries
    final deliveries = await _db
        .collection('deliveries')
        .where('coldStorageName', isEqualTo: oldName)
        .get();

    for (final doc in deliveries.docs) {
      batch.update(doc.reference, {'coldStorageName': newName});
      updateCount++;
    }

    await batch.commit();
    debugPrint('✅ CASCADE UPDATE complete: $updateCount documents updated');
  }

  /// Update all references to a product name.
  Future<void> cascadeUpdateProduct({
    required String oldName,
    required String newName,
  }) async {
    debugPrint('🔄 CASCADE UPDATE: Product "$oldName" → "$newName"');

    final receipts = await _db
        .collection('receipts')
        .where('productName', isEqualTo: oldName)
        .get();

    if (receipts.docs.isEmpty) {
      debugPrint('ℹ️ No receipts to update');
      return;
    }

    final batch = _db.batch();
    for (final doc in receipts.docs) {
      batch.update(doc.reference, {'productName': newName});
    }

    await batch.commit();
    debugPrint('✅ CASCADE UPDATE complete: ${receipts.docs.length} receipts updated');
  }

  /// Update all references to a brand name.
  Future<void> cascadeUpdateBrand({
    required String oldName,
    required String newName,
  }) async {
    debugPrint('🔄 CASCADE UPDATE: Brand "$oldName" → "$newName"');

    final receipts = await _db
        .collection('receipts')
        .where('brandName', isEqualTo: oldName)
        .get();

    if (receipts.docs.isEmpty) {
      debugPrint('ℹ️ No receipts to update');
      return;
    }

    final batch = _db.batch();
    for (final doc in receipts.docs) {
      batch.update(doc.reference, {'brandName': newName});
    }

    await batch.commit();
    debugPrint('✅ CASCADE UPDATE complete: ${receipts.docs.length} receipts updated');
  }

  /// Update all references to a company name.
  Future<void> cascadeUpdateCompany({
    required String oldName,
    required String newName,
  }) async {
    debugPrint('🔄 CASCADE UPDATE: Company "$oldName" → "$newName"');

    final receipts = await _db
        .collection('receipts')
        .where('companyName', isEqualTo: oldName)
        .get();

    if (receipts.docs.isEmpty) {
      debugPrint('ℹ️ No receipts to update');
      return;
    }

    final batch = _db.batch();
    for (final doc in receipts.docs) {
      batch.update(doc.reference, {'companyName': newName});
    }

    await batch.commit();
    debugPrint('✅ CASCADE UPDATE complete: ${receipts.docs.length} receipts updated');
  }

  /// Update receipt number across receipts and deliveries.
  /// This is complex because receipt number is NOT unique globally,
  /// only within a cold storage.
  Future<void> cascadeUpdateReceiptNumber({
    required String oldReceiptNumber,
    required String newReceiptNumber,
    required String coldStorageName,
  }) async {
    debugPrint(
      '🔄 CASCADE UPDATE: Receipt "$oldReceiptNumber" → "$newReceiptNumber" in "$coldStorageName"',
    );

    final batch = _db.batch();
    int updateCount = 0;

    // Update receipts (should be only one)
    final receipts = await _db
        .collection('receipts')
        .where('receiptNumber', isEqualTo: oldReceiptNumber)
        .where('coldStorageName', isEqualTo: coldStorageName)
        .get();

    for (final doc in receipts.docs) {
      batch.update(doc.reference, {'receiptNumber': newReceiptNumber});
      updateCount++;
    }

    // Update deliveries
    final deliveries = await _db
        .collection('deliveries')
        .where('receiptNumber', isEqualTo: oldReceiptNumber)
        .where('coldStorageName', isEqualTo: coldStorageName)
        .get();

    for (final doc in deliveries.docs) {
      batch.update(doc.reference, {'receiptNumber': newReceiptNumber});
      updateCount++;
    }

    await batch.commit();
    debugPrint('✅ CASCADE UPDATE complete: $updateCount documents updated');
  }

  // ========== CASCADE DELETE OPERATIONS ==========

  /// Delete a receipt and all associated deliveries.
  /// This is a CASCADE DELETE operation.
  Future<void> cascadeDeleteReceipt({
    required String receiptId,
    required String receiptNumber,
    required String coldStorageName,
  }) async {
    debugPrint(
      '🗑️ CASCADE DELETE: Receipt "$receiptNumber" in "$coldStorageName"',
    );

    final batch = _db.batch();

    // Delete the receipt
    batch.delete(_db.collection('receipts').doc(receiptId));

    // Delete all associated deliveries
    final deliveries = await _db
        .collection('deliveries')
        .where('receiptNumber', isEqualTo: receiptNumber)
        .where('coldStorageName', isEqualTo: coldStorageName)
        .get();

    for (final doc in deliveries.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    debugPrint(
      '✅ CASCADE DELETE complete: 1 receipt + ${deliveries.docs.length} deliveries deleted',
    );
  }

  // ========== UTILITY METHODS ==========

  /// Get detailed usage report for a master data item.
  Future<Map<String, dynamic>> getUsageReport({
    required String type,
    required String name,
  }) async {
    switch (type.toLowerCase()) {
      case 'cold_storage':
        final check = await checkColdStorageUsage(name);
        return {
          'type': 'Cold Storage',
          'name': name,
          'isInUse': check.isInUse,
          'totalReferences': check.affectedCount,
          'details': check.details,
        };
      case 'product':
        final check = await checkProductUsage(name);
        return {
          'type': 'Product',
          'name': name,
          'isInUse': check.isInUse,
          'totalReferences': check.affectedCount,
          'details': check.details,
        };
      case 'brand':
        final check = await checkBrandUsage(name);
        return {
          'type': 'Brand',
          'name': name,
          'isInUse': check.isInUse,
          'totalReferences': check.affectedCount,
          'details': check.details,
        };
      case 'company':
        final check = await checkCompanyUsage(name);
        return {
          'type': 'Company',
          'name': name,
          'isInUse': check.isInUse,
          'totalReferences': check.affectedCount,
          'details': check.details,
        };
      default:
        throw ArgumentError('Unknown type: $type');
    }
  }
}
