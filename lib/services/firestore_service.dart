// lib/services/firestore_service.dart

import 'package:business_management_app/models/receipt_model.dart';
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

  Future<void> addColdStorage(String name) =>
      _db.collection('cold_storages').add({'name': name.trim()});

  Future<void> updateColdStorage(String id, String newName) =>
      _db.collection('cold_storages').doc(id).update({'name': newName.trim()});

  Future<void> deleteColdStorage(String id) =>
      _db.collection('cold_storages').doc(id).delete();

  // ─── Products ───────────────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getProducts() => _db
      .collection('products')
      .orderBy('name')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
            .toList(),
      );

  Future<void> addProduct(String name) =>
      _db.collection('products').add({'name': name.trim()});

  Future<void> updateProduct(String id, String newName) =>
      _db.collection('products').doc(id).update({'name': newName.trim()});

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

  Future<void> addBrand(String name) =>
      _db.collection('brands').add({'name': name.trim()});

  Future<void> updateBrand(String id, String newName) =>
      _db.collection('brands').doc(id).update({'name': newName.trim()});

  Future<void> deleteBrand(String id) =>
      _db.collection('brands').doc(id).delete();

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
}
