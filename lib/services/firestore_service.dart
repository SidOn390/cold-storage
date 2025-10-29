// lib/services/firestore_service.dart

import 'package:cold_storage/models/delivery_model.dart';
import 'package:cold_storage/models/receipt_model.dart';
import 'package:cold_storage/models/rent_rate.dart';
import 'package:cold_storage/models/rent_bill.dart';
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

  // ─── Rent Rates ────────────────────────────────────────────────────────

  /// Retrieves a stream of all rent rates, ordered by cold storage and product name.
  Stream<List<RentRate>> getRentRates() {
    return _db
        .collection('rent_rates')
        .orderBy('coldStorageName')
        .orderBy('productName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RentRate.fromFirestore(doc))
              .toList(),
        );
  }

  /// Adds a new rent rate document to the 'rent_rates' collection.
  Future<void> addRentRate(RentRate rentRate) {
    return _db.collection('rent_rates').add(rentRate.toJson());
  }

  /// Updates an existing rent rate document in Firestore.
  Future<void> updateRentRate(String id, RentRate rentRate) {
    return _db.collection('rent_rates').doc(id).update(rentRate.toJson());
  }

  /// Deletes a rent rate document from Firestore.
  Future<void> deleteRentRate(String id) {
    return _db.collection('rent_rates').doc(id).delete();
  }

  /// Checks if a rent rate already exists for a product-cold storage combination.
  Future<bool> doesRentRateExist({
    required String productName,
    required String coldStorageName,
    String? excludeId,
  }) async {
    var query = _db
        .collection('rent_rates')
        .where('productName', isEqualTo: productName)
        .where('coldStorageName', isEqualTo: coldStorageName);

    final snapshot = await query.get();

    if (excludeId != null) {
      // If updating, exclude the current document
      return snapshot.docs.any((doc) => doc.id != excludeId);
    }

    return snapshot.docs.isNotEmpty;
  }

  /// Gets a rent rate for a specific product-cold storage combination.
  Future<RentRate?> getRentRateFor({
    required String productName,
    required String coldStorageName,
  }) async {
    final snapshot = await _db
        .collection('rent_rates')
        .where('productName', isEqualTo: productName)
        .where('coldStorageName', isEqualTo: coldStorageName)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return RentRate.fromFirestore(snapshot.docs.first);
  }

  // ─── Rent Bills ────────────────────────────────────────────────────────

  /// Retrieves a stream of all rent bills, ordered by generation date.
  Stream<List<RentBill>> getRentBills() {
    return _db
        .collection('rent_bills')
        .orderBy('generatedDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RentBill.fromFirestore(doc))
              .toList(),
        );
  }

  /// Adds a new rent bill document to the 'rent_bills' collection.
  Future<void> addRentBill(RentBill rentBill) {
    return _db.collection('rent_bills').add(rentBill.toJson());
  }

  /// Updates an existing rent bill document in Firestore.
  Future<void> updateRentBill(String id, RentBill rentBill) {
    return _db.collection('rent_bills').doc(id).update(rentBill.toJson());
  }

  /// Deletes a rent bill document from Firestore.
  Future<void> deleteRentBill(String id) {
    return _db.collection('rent_bills').doc(id).delete();
  }

  /// Checks if a rent bill already exists for a receipt.
  Future<bool> doesRentBillExistForReceipt(String receiptId) async {
    final snapshot = await _db
        .collection('rent_bills')
        .where('receiptId', isEqualTo: receiptId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Gets a rent bill for a specific receipt.
  Future<RentBill?> getRentBillForReceipt(String receiptId) async {
    final snapshot = await _db
        .collection('rent_bills')
        .where('receiptId', isEqualTo: receiptId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return RentBill.fromFirestore(snapshot.docs.first);
  }

  /// Toggles the 'isPaid' status of a rent bill.
  Future<void> toggleRentBillPaidStatus(String billId, bool currentStatus) {
    return _db.collection('rent_bills').doc(billId).update({
      'isPaid': !currentStatus,
      'paymentDate':
          !currentStatus ? FieldValue.serverTimestamp() : null,
    });
  }

  /// Gets the next rent bill number (auto-increment).
  Future<String> getNextRentBillNumber() async {
    final now = DateTime.now();
    final year = now.year;

    // Get all bills from current year
    final snapshot = await _db
        .collection('rent_bills')
        .where('billNumber', isGreaterThanOrEqualTo: 'RB/001/$year')
        .where('billNumber', isLessThan: 'RB/001/${year + 1}')
        .orderBy('billNumber', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      // First bill of the year
      return 'RB/001/$year';
    }

    // Extract number from last bill (e.g., "RB/042/2025" -> 42)
    final lastBill = snapshot.docs.first.data()['billNumber'] as String;
    final parts = lastBill.split('/');
    final lastNumber = int.tryParse(parts[1]) ?? 0;
    final nextNumber = lastNumber + 1;

    return 'RB/${nextNumber.toString().padLeft(3, '0')}/$year';
  }
}

