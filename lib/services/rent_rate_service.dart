// lib/services/rent_rate_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cold_storage/models/rent_rate.dart';
import 'package:cold_storage/models/rent_type.dart';

/// Service for managing rent rates with Firestore integration.
///
/// Provides CRUD operations and querying for rent rate configurations.
class RentRateService {
  RentRateService._();
  static final RentRateService instance = RentRateService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'rent_rates';

  /// Get all active rent rates as a stream
  Stream<List<RentRate>> getRentRatesStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('coldStorageName')
        .orderBy('productName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => RentRate.fromFirestore(doc)).toList();
    });
  }

  /// Get all active rent rates (one-time fetch)
  Future<List<RentRate>> getRentRates() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('coldStorageName')
          .orderBy('productName')
          .get();

      return snapshot.docs.map((doc) => RentRate.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching rent rates: $e');
      rethrow;
    }
  }

  /// Get rent rate by ID
  Future<RentRate?> getRentRateById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return RentRate.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching rent rate by ID: $e');
      rethrow;
    }
  }

  /// Get rent rate for specific cold storage + product + rent type
  Future<RentRate?> getRateFor({
    required String coldStorageName,
    required String productName,
    required RentType rentType,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('coldStorageName', isEqualTo: coldStorageName)
          .where('productName', isEqualTo: productName)
          .where('rentType', isEqualTo: rentType.toJson())
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return RentRate.fromFirestore(snapshot.docs.first);
      }

      debugPrint('⚠️ No rent rate found for: $coldStorageName - $productName - ${rentType.displayName}');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching rent rate: $e');
      rethrow;
    }
  }

  /// Get all rates for a specific cold storage
  Future<List<RentRate>> getRatesForColdStorage(String coldStorageName) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('coldStorageName', isEqualTo: coldStorageName)
          .where('isActive', isEqualTo: true)
          .orderBy('productName')
          .get();

      return snapshot.docs.map((doc) => RentRate.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching rates for cold storage: $e');
      rethrow;
    }
  }

  /// Get all rates for a specific product
  Future<List<RentRate>> getRatesForProduct(String productName) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('productName', isEqualTo: productName)
          .where('isActive', isEqualTo: true)
          .orderBy('coldStorageName')
          .get();

      return snapshot.docs.map((doc) => RentRate.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching rates for product: $e');
      rethrow;
    }
  }

  /// Add a new rent rate
  Future<String> addRentRate(RentRate rentRate) async {
    try {
      // Validate
      final error = rentRate.validate();
      if (error != null) {
        throw Exception(error);
      }

      // Check for duplicates
      final existing = await getRateFor(
        coldStorageName: rentRate.coldStorageName,
        productName: rentRate.productName,
        rentType: rentRate.rentType,
      );

      if (existing != null) {
        throw Exception(
          'Rent rate already exists for ${rentRate.coldStorageName} - ${rentRate.productName} (${rentRate.rentType.displayName})'
        );
      }

      // Add to Firestore
      final docRef = await _firestore.collection(_collection).add(rentRate.toJson());
      debugPrint('✅ Rent rate added with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error adding rent rate: $e');
      rethrow;
    }
  }

  /// Update an existing rent rate
  Future<void> updateRentRate(RentRate rentRate) async {
    try {
      if (rentRate.id == null) {
        throw Exception('Cannot update rent rate without ID');
      }

      // Validate
      final error = rentRate.validate();
      if (error != null) {
        throw Exception(error);
      }

      // Check for duplicates (excluding current rate)
      final existing = await getRateFor(
        coldStorageName: rentRate.coldStorageName,
        productName: rentRate.productName,
        rentType: rentRate.rentType,
      );

      if (existing != null && existing.id != rentRate.id) {
        throw Exception(
          'Another rent rate already exists for ${rentRate.coldStorageName} - ${rentRate.productName} (${rentRate.rentType.displayName})'
        );
      }

      // Update in Firestore
      await _firestore
          .collection(_collection)
          .doc(rentRate.id)
          .update(rentRate.toJson());

      debugPrint('✅ Rent rate updated: ${rentRate.id}');
    } catch (e) {
      debugPrint('❌ Error updating rent rate: $e');
      rethrow;
    }
  }

  /// Delete a rent rate (soft delete - mark as inactive)
  Future<void> deleteRentRate(String id, String deletedBy) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
        'updatedBy': deletedBy,
      });

      debugPrint('✅ Rent rate deleted (soft): $id');
    } catch (e) {
      debugPrint('❌ Error deleting rent rate: $e');
      rethrow;
    }
  }

  /// Check if a rent rate is being used in any receipts
  Future<bool> isRateInUse(String rateId) async {
    try {
      final rate = await getRentRateById(rateId);
      if (rate == null) return false;

      // Check if any receipts use this rate configuration
      final receipts = await _firestore
          .collection('receipts')
          .where('coldStorageName', isEqualTo: rate.coldStorageName)
          .where('productName', isEqualTo: rate.productName)
          .where('rentType', isEqualTo: rate.rentType.toJson())
          .limit(1)
          .get();

      return receipts.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking if rate is in use: $e');
      return false;
    }
  }

  /// Get statistics about rent rates
  Future<Map<String, int>> getStatistics() async {
    try {
      final rates = await getRentRates();

      final monthly = rates.where((r) => r.rentType == RentType.monthly).length;
      final seasonal = rates.where((r) => r.rentType == RentType.seasonal).length;

      return {
        'total': rates.length,
        'monthly': monthly,
        'seasonal': seasonal,
      };
    } catch (e) {
      debugPrint('❌ Error getting statistics: $e');
      return {'total': 0, 'monthly': 0, 'seasonal': 0};
    }
  }

  /// Search rent rates by query
  Future<List<RentRate>> searchRentRates(String query) async {
    try {
      final allRates = await getRentRates();
      final lowerQuery = query.toLowerCase();

      return allRates.where((rate) {
        return rate.coldStorageName.toLowerCase().contains(lowerQuery) ||
               rate.productName.toLowerCase().contains(lowerQuery);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error searching rent rates: $e');
      return [];
    }
  }
}
