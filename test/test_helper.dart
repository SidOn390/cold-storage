// test/test_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper class for setting up Firebase emulators in tests
class TestHelper {
  static bool _initialized = false;

  /// Initialize Firebase with emulator configuration for testing
  ///
  /// Call this in setUpAll() of your test suite
  static Future<void> setupFirebaseEmulators() async {
    if (_initialized) {
      return;
    }

    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase with test project
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender-id',
        projectId: 'cold-storage-test',
      ),
    );

    // Connect to Firestore emulator
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);

    // Connect to Auth emulator
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);

    _initialized = true;
  }

  /// Clear all Firestore data
  ///
  /// Call this in setUp() or tearDown() to ensure clean state between tests
  static Future<void> clearFirestoreData() async {
    final firestore = FirebaseFirestore.instance;

    // Delete all collections
    final collections = [
      'users',
      'cold_storages',
      'products',
      'brands',
      'companies',
      'receipts',
      'deliveries',
      'rent_rates',
      'rent_bills',
    ];

    for (final collectionName in collections) {
      final snapshot = await firestore.collection(collectionName).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
  }

  /// Create a test user and sign in
  ///
  /// Returns the UserCredential for the signed-in user
  static Future<UserCredential> signInTestUser({
    String email = 'test@example.com',
    String password = 'testpass123',
  }) async {
    try {
      // Try to sign in
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // If user doesn't exist, create it
      return await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  /// Sign out the current user
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  /// Add test user document to Firestore
  ///
  /// Creates a user document with required fields for the app
  static Future<void> addTestUserDocument({
    required String uid,
    String username = 'testuser',
    String role = 'manager',
    bool isActive = true,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'username': username,
      'role': role,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add test master data (cold storage, products, brands, companies)
  static Future<void> addTestMasterData() async {
    final firestore = FirebaseFirestore.instance;

    // Add cold storages
    await firestore.collection('cold_storages').add({
      'name': 'Test Cold Storage 1',
      'name_lowercase': 'test cold storage 1',
    });

    await firestore.collection('cold_storages').add({
      'name': 'Test Cold Storage 2',
      'name_lowercase': 'test cold storage 2',
    });

    // Add products
    await firestore.collection('products').add({
      'name': 'Test Product 1',
      'name_lowercase': 'test product 1',
      'weight': 50.0,
    });

    await firestore.collection('products').add({
      'name': 'Test Product 2',
      'name_lowercase': 'test product 2',
      'weight': 25.0,
    });

    // Add brands
    await firestore.collection('brands').add({
      'name': 'Test Brand 1',
      'name_lowercase': 'test brand 1',
    });

    // Add companies
    await firestore.collection('companies').add({
      'name': 'Test Company 1',
      'name_lowercase': 'test company 1',
    });
  }

  /// Add test rent rate
  static Future<DocumentReference> addTestRentRate({
    required String coldStorageName,
    required String productName,
    required String rentType,
    double? monthlyRatePerUnit,
    double? labourRatePerUnit,
    double? seasonalRatePerUnit,
    double gstPercentage = 18.0,
  }) async {
    return await FirebaseFirestore.instance.collection('rent_rates').add({
      'coldStorageName': coldStorageName,
      'coldStorageName_lowercase': coldStorageName.toLowerCase(),
      'productName': productName,
      'productName_lowercase': productName.toLowerCase(),
      'rentType': rentType,
      'monthlyRatePerUnit': monthlyRatePerUnit,
      'labourRatePerUnit': labourRatePerUnit,
      'seasonalRatePerUnit': seasonalRatePerUnit,
      'gstPercentage': gstPercentage,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': 'test-user',
    });
  }

  /// Add test receipt
  static Future<DocumentReference> addTestReceipt({
    required String receiptNumber,
    required String coldStorageName,
    required String productName,
    required String brandName,
    required String companyName,
    required String rentType,
    DateTime? inwardDate,
    int inwardQuantity = 100,
    double rate = 10.0,
  }) async {
    return await FirebaseFirestore.instance.collection('receipts').add({
      'receiptNumber': receiptNumber,
      'coldStorageName': coldStorageName,
      'productName': productName,
      'brandName': brandName,
      'companyName': companyName,
      'rentType': rentType,
      'inwardDate': Timestamp.fromDate(inwardDate ?? DateTime.now()),
      'inwardQuantity': inwardQuantity,
      'remainingQuantity': inwardQuantity,
      'rate': rate,
      'narration': 'Test receipt',
      'isPaid': false,
      'status': 'Active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add test delivery
  static Future<DocumentReference> addTestDelivery({
    required String receiptId,
    required String coldStorageName,
    required String receiptNumber,
    DateTime? deliveryDate,
    int quantity = 50,
  }) async {
    return await FirebaseFirestore.instance.collection('deliveries').add({
      'receiptId': receiptId,
      'coldStorageName': coldStorageName,
      'receiptNumber': receiptNumber,
      'deliveryDate': Timestamp.fromDate(deliveryDate ?? DateTime.now()),
      'quantity': quantity,
      'narration': 'Test delivery',
    });
  }
}
