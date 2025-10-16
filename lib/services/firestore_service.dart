// lib/services/firestore_service.dart

import 'package:cold_storage/models/delivery_model.dart';
import 'package:cold_storage/models/receipt_model.dart';
import 'package:cold_storage/services/referential_integrity_service.dart';
import 'package:cold_storage/services/delivery_validation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ReferentialIntegrityService _integrity = ReferentialIntegrityService();
  final DeliveryValidationService _deliveryValidation =
      DeliveryValidationService();

  // ─── Cold Storages ─────────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getColdStorages() => _db
      .collection('cold_storages')
      .orderBy('name')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
            .toList(),
      );

  Future<void> addColdStorage(String name) => _db
      .collection('cold_storages')
      .add({'name': name.trim(), 'name_lowercase': name.trim().toLowerCase()});

  /// Updates a cold storage name with CASCADE UPDATE to all references.
  /// This updates receipts and deliveries that reference the old name.
  Future<void> updateColdStorage(
    String id,
    String newName, {
    String? oldName,
  }) async {
    final trimmedNewName = newName.trim();

    // If oldName provided and different, cascade update all references
    if (oldName != null && oldName != trimmedNewName) {
      await _integrity.cascadeUpdateColdStorage(
        oldName: oldName,
        newName: trimmedNewName,
      );
    }

    // Update the master record
    return _db.collection('cold_storages').doc(id).update({
      'name': trimmedNewName,
      'name_lowercase': trimmedNewName.toLowerCase(),
    });
  }

  Future<void> deleteColdStorage(String id) =>
      _db.collection('cold_storages').doc(id).delete();

  // ─── Products ───────────────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getProducts() => _db
      .collection('products')
      .orderBy('name')
      .snapshots()
      .map(
        (snap) => snap.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] as String,
            'weight': (data['weight'] as num?)?.toDouble() ?? 0.0,
          };
        }).toList(),
      );

  Future<void> addProduct(String name, double weight) =>
      _db.collection('products').add({
        'name': name.trim(),
        'name_lowercase': name.trim().toLowerCase(),
        'weight': weight,
      });

  /// Updates a product with CASCADE UPDATE to all references.
  Future<void> updateProduct(
    String id,
    String newName,
    double weight, {
    String? oldName,
  }) async {
    final trimmedNewName = newName.trim();

    // If oldName provided and different, cascade update all references
    if (oldName != null && oldName != trimmedNewName) {
      await _integrity.cascadeUpdateProduct(
        oldName: oldName,
        newName: trimmedNewName,
      );
    }

    // Update the master record
    return _db.collection('products').doc(id).update({
      'name': trimmedNewName,
      'name_lowercase': trimmedNewName.toLowerCase(),
      'weight': weight,
    });
  }

  Future<void> deleteProduct(String id) =>
      _db.collection('products').doc(id).delete();

  // ─── Brands ───────────────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getBrands() => _db
      .collection('brands')
      .orderBy('name')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
            .toList(),
      );

  Future<void> addBrand(String name) => _db.collection('brands').add({
    'name': name.trim(),
    'name_lowercase': name.trim().toLowerCase(),
  });

  /// Updates a brand with CASCADE UPDATE to all references.
  Future<void> updateBrand(String id, String newName, {String? oldName}) async {
    final trimmedNewName = newName.trim();

    // If oldName provided and different, cascade update all references
    if (oldName != null && oldName != trimmedNewName) {
      await _integrity.cascadeUpdateBrand(
        oldName: oldName,
        newName: trimmedNewName,
      );
    }

    // Update the master record
    return _db.collection('brands').doc(id).update({
      'name': trimmedNewName,
      'name_lowercase': trimmedNewName.toLowerCase(),
    });
  }

  Future<void> deleteBrand(String id) =>
      _db.collection('brands').doc(id).delete();

  // ─── Companies ─────────────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getCompanies() => _db
      .collection('companies')
      .orderBy('name')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
            .toList(),
      );

  Future<void> addCompany(String name) => _db.collection('companies').add({
    'name': name.trim(),
    'name_lowercase': name.trim().toLowerCase(),
  });

  /// Updates a company with CASCADE UPDATE to all references.
  Future<void> updateCompany(
    String id,
    String newName, {
    String? oldName,
  }) async {
    final trimmedNewName = newName.trim();

    // If oldName provided and different, cascade update all references
    if (oldName != null && oldName != trimmedNewName) {
      await _integrity.cascadeUpdateCompany(
        oldName: oldName,
        newName: trimmedNewName,
      );
    }

    // Update the master record
    return _db.collection('companies').doc(id).update({
      'name': trimmedNewName,
      'name_lowercase': trimmedNewName.toLowerCase(),
    });
  }

  Future<void> deleteCompany(String id) =>
      _db.collection('companies').doc(id).delete();

  // ─── Receipts ───────────────────────────────────────────────────────────

  /// Adds a new receipt document to the 'receipts' collection.
  Future<void> addReceipt(Map<String, dynamic> receiptData) {
    return _db.collection('receipts').add(receiptData);
  }

  /// Retrieves a stream of all receipts, ordered by creation date.
  Stream<List<Receipt>> getReceipts() {
    return _db
        .collection('receipts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Receipt.fromFirestore(doc)).toList(),
        );
  }

  /// Checks if a receipt with the given number already exists for a specific cold storage.
  /// This is how we prevent duplicates.
  Future<bool> doesReceiptExist(
    String receiptNumber,
    String coldStorageName,
  ) async {
    final query = await _db
        .collection('receipts')
        .where('receiptNumber', isEqualTo: receiptNumber)
        .where('coldStorageName', isEqualTo: coldStorageName)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  /// Updates an existing receipt document in Firestore.
  Future<void> updateReceipt(String id, Map<String, dynamic> data) {
    return _db.collection('receipts').doc(id).update(data);
  }

  /// Deletes a receipt document from Firestore.
  Future<void> deleteReceipt(String id) {
    return _db.collection('receipts').doc(id).delete();
  }

  /// CASCADE DELETE: Delete receipt and all associated deliveries
  Future<void> cascadeDeleteReceipt({
    required String receiptId,
    required String receiptNumber,
    required String coldStorageName,
  }) {
    return _integrity.cascadeDeleteReceipt(
      receiptId: receiptId,
      receiptNumber: receiptNumber,
      coldStorageName: coldStorageName,
    );
  }

  // ─── Generic Master Data ────────────────────────────────────────────────

  /// Adds a new master data item to the specified collection if it doesn't already exist.
  Future<void> addMasterItem(String collection, String name) async {
    try {
      final querySnapshot = await _db
          .collection(collection)
          .where('name_lowercase', isEqualTo: name.toLowerCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return;
      }
      await _db.collection(collection).add({
        'name': name,
        'name_lowercase': name.toLowerCase(),
      });
    } catch (e) {
      rethrow;
    }
  }
  // Add these methods to your FirestoreService class

  // ─── Referential Integrity Checks ──────────────────────────────────────

  /// Checks if a brand is used anywhere (comprehensive check).
  Future<bool> isBrandInUse(String brandName) async {
    final result = await _integrity.checkBrandUsage(brandName);
    return result.isInUse;
  }

  /// Checks if a product is used anywhere (comprehensive check).
  Future<bool> isProductInUse(String productName) async {
    final result = await _integrity.checkProductUsage(productName);
    return result.isInUse;
  }

  /// Checks if a cold storage is used anywhere (comprehensive check).
  /// Checks both receipts AND deliveries.
  Future<bool> isColdStorageInUse(String coldStorageName) async {
    final result = await _integrity.checkColdStorageUsage(coldStorageName);
    return result.isInUse;
  }

  /// Checks if a company is used anywhere (comprehensive check).
  Future<bool> isCompanyInUse(String companyName) async {
    final result = await _integrity.checkCompanyUsage(companyName);
    return result.isInUse;
  }

  /// Get detailed usage information for a master data item.
  /// Returns a comprehensive report including count and affected collections.
  Future<IntegrityCheckResult> getDetailedUsage({
    required String type,
    required String name,
  }) async {
    switch (type.toLowerCase()) {
      case 'brand':
        return _integrity.checkBrandUsage(name);
      case 'product':
        return _integrity.checkProductUsage(name);
      case 'cold_storage':
      case 'coldstorage':
        return _integrity.checkColdStorageUsage(name);
      case 'company':
        return _integrity.checkCompanyUsage(name);
      default:
        throw ArgumentError('Unknown type: $type');
    }
  }
  // Add these methods to your FirestoreService class

  // Add a new delivery document
  Future<void> addDelivery(Delivery delivery) {
    return _db.collection('deliveries').add(delivery.toJson());
  }

  // Get a stream of all deliveries
  Stream<List<Delivery>> getDeliveries() {
    return _db.collection('deliveries').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Delivery.fromSnapshot(doc)).toList();
    });
  }
  // Add these methods to your FirestoreService class

  // Update an existing delivery document
  Future<void> updateDelivery(String id, Map<String, dynamic> data) {
    return _db.collection('deliveries').doc(id).update(data);
  }

  // Delete a delivery document
  Future<void> deleteDelivery(String id) {
    return _db.collection('deliveries').doc(id).delete();
  }
  // Add this method to your FirestoreService class

  // Toggles the 'isPaid' status of a receipt.
  Future<void> toggleReceiptPaidStatus(String receiptId, bool currentStatus) {
    return _db.collection('receipts').doc(receiptId).update({
      'isPaid': !currentStatus,
    });
  }

  // ─── Delivery Validation ────────────────────────────────────────────────

  /// Calculate accurate remaining quantity by querying actual deliveries.
  /// This is the SOURCE OF TRUTH - always recalculates from delivery records.
  Future<int> calculateRemainingQuantity({
    required String receiptNumber,
    required String coldStorageName,
    required int inwardQuantity,
    String? excludeDeliveryId,
  }) {
    return _deliveryValidation.calculateRemainingQuantity(
      receiptNumber: receiptNumber,
      coldStorageName: coldStorageName,
      inwardQuantity: inwardQuantity,
      excludeDeliveryId: excludeDeliveryId,
    );
  }

  /// Validate a delivery quantity before creating/updating.
  /// Returns comprehensive validation result with details.
  Future<DeliveryValidationResult> validateDelivery({
    required Receipt receipt,
    required int attemptedQuantity,
    String? excludeDeliveryId,
  }) {
    return _deliveryValidation.validateDelivery(
      receipt: receipt,
      attemptedQuantity: attemptedQuantity,
      excludeDeliveryId: excludeDeliveryId,
    );
  }

  /// Recalculate and sync a receipt's remaining quantity from actual deliveries.
  /// Fixes any discrepancies between stored value and reality.
  Future<void> syncReceiptRemainingQuantity({
    required String receiptId,
    required String receiptNumber,
    required String coldStorageName,
    required int inwardQuantity,
  }) {
    return _deliveryValidation.syncReceiptRemainingQuantity(
      receiptId: receiptId,
      receiptNumber: receiptNumber,
      coldStorageName: coldStorageName,
      inwardQuantity: inwardQuantity,
    );
  }

  /// Batch sync ALL receipts' remaining quantities.
  /// Useful for data maintenance or after bulk operations.
  /// Returns the number of receipts that were updated.
  Future<int> syncAllReceiptsRemainingQuantity() {
    return _deliveryValidation.syncAllReceiptsRemainingQuantity();
  }

  /// Get comprehensive delivery summary for a receipt.
  Future<Map<String, dynamic>> getReceiptDeliverySummary({
    required String receiptNumber,
    required String coldStorageName,
    required int inwardQuantity,
  }) {
    return _deliveryValidation.getReceiptDeliverySummary(
      receiptNumber: receiptNumber,
      coldStorageName: coldStorageName,
      inwardQuantity: inwardQuantity,
    );
  }

  /// Get all deliveries for a specific receipt.
  Future<List<Map<String, dynamic>>> getDeliveriesForReceipt({
    required String receiptNumber,
    required String coldStorageName,
  }) {
    return _deliveryValidation.getDeliveriesForReceipt(
      receiptNumber: receiptNumber,
      coldStorageName: coldStorageName,
    );
  }
}

