// test/test_utils.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test utilities for Firebase emulator testing
class TestUtils {
  static const String emulatorHost = 'localhost';
  static const int firestorePort = 8080;
  static const int authPort = 9099;

  /// Initialize Firebase for testing with emulators
  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender-id',
        projectId: 'cold-storage-inventory',
      ),
    );

    // Connect to Firestore emulator
    FirebaseFirestore.instance.settings = const Settings(
      host: '$emulatorHost:$firestorePort',
      sslEnabled: false,
      persistenceEnabled: false,
    );

    // Connect to Auth emulator
    await auth.FirebaseAuth.instance.useAuthEmulator(emulatorHost, authPort);
  }

  /// Clear all Firestore data
  static Future<void> clearFirestore() async {
    final firestore = FirebaseFirestore.instance;

    // Clear all collections
    final collections = [
      'receipts',
      'deliveries',
      'rent_bills',
      'cold_storages',
      'products',
      'brands',
      'companies',
      'rent_rates',
      'users',
    ];

    for (final collection in collections) {
      final snapshot = await firestore.collection(collection).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
  }

  /// Create test user and sign in
  static Future<auth.User?> signInTestUser({
    String email = 'test@example.com',
    String password = 'testpass123',
  }) async {
    try {
      final authInstance = auth.FirebaseAuth.instance;

      // Try to create user
      try {
        await authInstance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (e) {
        // User might already exist, that's okay
      }

      // Sign in
      final credential = await authInstance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return credential.user;
    } catch (e) {
      debugPrint('Error signing in test user: $e');
      return null;
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    await auth.FirebaseAuth.instance.signOut();
  }

  /// Seed test data into Firestore
  static Future<void> seedTestData() async {
    final firestore = FirebaseFirestore.instance;

    // Seed cold storages
    await firestore.collection('cold_storages').add({
      'name': 'Test Storage 1',
      'name_lowercase': 'test storage 1',
    });

    await firestore.collection('cold_storages').add({
      'name': 'Test Storage 2',
      'name_lowercase': 'test storage 2',
    });

    // Seed products
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

    // Seed brands
    await firestore.collection('brands').add({
      'name': 'Test Brand 1',
      'name_lowercase': 'test brand 1',
    });

    await firestore.collection('brands').add({
      'name': 'Test Brand 2',
      'name_lowercase': 'test brand 2',
    });

    // Seed companies
    await firestore.collection('companies').add({
      'name': 'Test Company 1',
      'name_lowercase': 'test company 1',
    });

    await firestore.collection('companies').add({
      'name': 'Test Company 2',
      'name_lowercase': 'test company 2',
    });

    // Seed a test receipt
    await firestore.collection('receipts').add({
      'receiptNumber': 'RCP001',
      'coldStorageName': 'Test Storage 1',
      'productName': 'Test Product 1',
      'brandName': 'Test Brand 1',
      'companyName': 'Test Company 1',
      'inwardDate': Timestamp.fromDate(DateTime(2025, 1, 1)),
      'inwardQuantity': 100,
      'remainingQuantity': 100,
      'rate': 50.0,
      'narration': 'Test receipt',
      'isPaid': false,
      'rentType': 'monthly',
      'createdAt': Timestamp.now(),
    });
  }

  /// Pump a widget with MaterialApp wrapper
  static Future<void> pumpWidget(
    WidgetTester tester,
    Widget widget, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: widget,
      ),
    );
  }

  /// Pump a widget and settle
  static Future<void> pumpAndSettle(
    WidgetTester tester,
    Widget widget, {
    ThemeData? theme,
    Duration? duration,
  }) async {
    await pumpWidget(tester, widget, theme: theme);
    await tester.pumpAndSettle(duration);
  }

  /// Wait for async operations to complete
  static Future<void> waitForAsync({Duration? timeout}) async {
    await Future.delayed(timeout ?? const Duration(milliseconds: 100));
  }
}

/// Test screen sizes for responsive testing
class TestScreenSizes {
  static const Size mobile = Size(375, 667); // iPhone SE
  static const Size tablet = Size(768, 1024); // iPad
  static const Size desktop = Size(1920, 1080); // Full HD
  static const Size wide = Size(2560, 1440); // 2K
}

/// Helper to test widget at different screen sizes
Future<void> testAtScreenSize(
  WidgetTester tester,
  Widget widget,
  Size size,
  String description,
  Future<void> Function() testCallback,
) async {
  await tester.binding.setSurfaceSize(size);
  await TestUtils.pumpAndSettle(tester, widget);

  debugPrint('Testing at size: ${size.width}x${size.height} - $description');
  await testCallback();

  // Reset size
  await tester.binding.setSurfaceSize(null);
}
