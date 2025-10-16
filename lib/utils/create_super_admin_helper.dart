// lib/utils/create_super_admin_helper.dart
//
// Helper function to create initial super admin user
// Can be called from anywhere in the app during first-time setup

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CreateSuperAdminHelper {
  static Future<Map<String, dynamic>> createInitialSuperAdmin() async {
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      // Super Admin Details
      const email = 'admin@coldstorage.com';
      const password = 'Admin123';
      const displayName = 'Siddharth Shah';
      const role = 'super_admin';

      debugPrint('Creating Super Admin User...');
      debugPrint('Email: $email');
      debugPrint('Display Name: $displayName');

      // Check if user already exists
      final existingUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        debugPrint('User with email $email already exists!');
        return {
          'success': false,
          'error': 'User already exists',
          'userId': existingUsers.docs.first.id,
        };
      }

      // Create Firebase Auth user
      debugPrint('Creating authentication user...');
      UserCredential userCredential;
      try {
        userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint('Authentication user created');
      } catch (e) {
        if (e.toString().contains('email-already-in-use')) {
          debugPrint('Authentication user already exists, signing in...');
          userCredential = await auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          throw Exception('Failed to create auth user: $e');
        }
      }

      final user = userCredential.user!;
      debugPrint('User ID: ${user.uid}');

      // Create Firestore user profile
      debugPrint('Creating user profile in Firestore...');
      await firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'email_lowercase': email.toLowerCase(),
        'displayName': displayName,
        'role': role,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'phoneNumber': null,
        'createdBy': user.uid, // Self-created
      });
      debugPrint('User profile created in Firestore');

      // Sign out
      await auth.signOut();

      debugPrint('✅ Super Admin created successfully!');

      return {
        'success': true,
        'email': email,
        'password': password,
        'displayName': displayName,
        'userId': user.uid,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to create super admin: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
