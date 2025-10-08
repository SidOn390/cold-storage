// lib/services/firestore_service.dart

import 'package:cold_storage/models/delivery_model.dart';
import 'package:cold_storage/models/receipt_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  Future<void> updateColdStorage(String id, String newName) =>
      _db.collection('cold_storages').doc(id).update({
        'name': newName.trim(),
        'name_lowercase': newName.trim().toLowerCase(),
      });

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

  Future<void> updateProduct(String id, String newName, double weight) =>
      _db.collection('products').doc(id).update({
        'name': newName.trim(),
        'name_lowercase': newName.trim().toLowerCase(),
        'weight': weight,
      });

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

  Future<void> updateBrand(String id, String newName) =>
      _db.collection('brands').doc(id).update({
        'name': newName.trim(),
        'name_lowercase': newName.trim().toLowerCase(),
      });

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

  Future<void> updateCompany(String id, String newName) =>
      _db.collection('companies').doc(id).update({
        'name': newName.trim(),
        'name_lowercase': newName.trim().toLowerCase(),
      });

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

  /// Checks if a given brand name is used in any receipt.
  Future<bool> isBrandInUse(String brandName) async {
    final querySnapshot = await _db
        .collection('receipts')
        .where('brandName', isEqualTo: brandName)
        .limit(1)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  /// Checks if a given product name is used in any receipt.
  Future<bool> isProductInUse(String productName) async {
    final querySnapshot = await _db
        .collection('receipts')
        .where('productName', isEqualTo: productName)
        .limit(1)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  /// Checks if a given cold storage name is used in any receipt.
  Future<bool> isColdStorageInUse(String coldStorageName) async {
    final querySnapshot = await _db
        .collection('receipts')
        .where('coldStorageName', isEqualTo: coldStorageName)
        .limit(1)
        .get();
    return querySnapshot.docs.isNotEmpty;
  }

  /// Checks if a given company name is used in any receipt.
  Future<bool> isCompanyInUse(String companyName) async {
    final querySnapshot = await _db
        .collection('receipts')
        .where('companyName', isEqualTo: companyName)
        .limit(1)
        .get();
    return querySnapshot.docs.isNotEmpty;
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
}
