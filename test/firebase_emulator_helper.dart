// test/firebase_emulator_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Helper class to configure Firebase to use local emulator
class FirebaseEmulatorHelper {
  static bool _initialized = false;

  /// Initialize Firebase with emulator settings
  static Future<void> setupEmulator() async {
    if (_initialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: 'test-app-id',
          messagingSenderId: 'test-sender-id',
          projectId: 'cold-storage-inventory',
        ),
      );

      // Connect to Firestore emulator
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);

      // Connect to Auth emulator
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);

      _initialized = true;
      print('✅ Firebase Emulator configured successfully');
    } catch (e) {
      print('⚠️  Firebase already initialized or error: $e');
      _initialized = true; // Prevent retry
    }
  }

  /// Clear all Firestore data in emulator
  static Future<void> clearFirestoreData() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Clear all collections
      final collections = [
        'receipts',
        'deliveries',
        'cold_storages',
        'products',
        'brands',
        'companies',
      ];

      for (final collection in collections) {
        final snapshot = await firestore.collection(collection).get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }

      print('✅ Firestore data cleared');
    } catch (e) {
      print('⚠️  Error clearing Firestore: $e');
    }
  }

  /// Create a test user in Auth emulator
  static Future<UserCredential> createTestUser({
    required String email,
    required String password,
  }) async {
    try {
      return await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // If user already exists, sign in instead
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  /// Check if emulator is running
  static Future<bool> isEmulatorRunning() async {
    try {
      // Try to connect to Firestore emulator
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('_test_')
          .doc('_test_')
          .get()
          .timeout(const Duration(seconds: 2));
      return true;
    } catch (e) {
      return false;
    }
  }
}
