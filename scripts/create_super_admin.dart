// scripts/create_super_admin.dart
//
// Script to create the initial super admin user
// Run this once to bootstrap the user management system
//
// Usage:
//   dart run scripts/create_super_admin.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('╔════════════════════════════════════════════════════════════╗');
  print('║     Cold Storage - Create Super Admin User Script        ║');
  print('╚════════════════════════════════════════════════════════════╝\n');

  try {
    // Initialize Firebase
    print('Initializing Firebase...');
    await Firebase.initializeApp();
    print('✅ Firebase initialized\n');

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    // Super Admin Details
    const email = 'admin@coldstorage.com';
    const password = 'Admin123';
    const displayName = 'Siddharth Shah';
    const role = 'super_admin';

    print('Creating Super Admin User...');
    print('Email: $email');
    print('Display Name: $displayName');
    print('Role: Super Admin\n');

    // Check if user already exists
    try {
      final existingUsers = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        print('⚠️  User with email $email already exists!');
        print('User ID: ${existingUsers.docs.first.id}');
        print('\nWould you like to update this user to Super Admin? (This script will exit)');
        print('To update manually:');
        print('1. Go to Firebase Console → Firestore');
        print('2. Find users collection → ${existingUsers.docs.first.id}');
        print('3. Update "role" field to "super_admin"');
        return;
      }
    } catch (e) {
      print('Note: Could not check for existing user: $e');
    }

    // Create Firebase Auth user
    print('Creating authentication user...');
    UserCredential userCredential;
    try {
      userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ Authentication user created');
    } catch (e) {
      if (e.toString().contains('email-already-in-use')) {
        print('⚠️  Authentication user already exists');
        print('Signing in to get user ID...');
        userCredential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        throw Exception('Failed to create auth user: $e');
      }
    }

    final user = userCredential.user!;
    print('User ID: ${user.uid}\n');

    // Create Firestore user profile
    print('Creating user profile in Firestore...');
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
    print('✅ User profile created in Firestore\n');

    // Sign out
    await auth.signOut();

    print('╔════════════════════════════════════════════════════════════╗');
    print('║                    SUCCESS!                               ║');
    print('╚════════════════════════════════════════════════════════════╝\n');

    print('Super Admin user created successfully!\n');
    print('Login Credentials:');
    print('─────────────────────────────────────────────────────────────');
    print('Email:        $email');
    print('Password:     $password');
    print('Display Name: $displayName');
    print('Role:         Super Admin');
    print('─────────────────────────────────────────────────────────────\n');

    print('IMPORTANT:');
    print('1. Use these credentials to log into the app');
    print('2. You can now create more users via Masters → User Management');
    print('3. Consider changing the password after first login');
    print('4. KEEP THESE CREDENTIALS SECURE!\n');

    print('Next Steps:');
    print('1. Run the app: flutter run');
    print('2. Login with the credentials above');
    print('3. Navigate to Masters → User Management');
    print('4. Create additional users as needed\n');

  } catch (e, stackTrace) {
    print('\n❌ ERROR: Failed to create super admin user\n');
    print('Error: $e');
    print('Stack trace: $stackTrace\n');
    print('Troubleshooting:');
    print('1. Make sure Firebase is properly configured');
    print('2. Check your firebase_options.dart file exists');
    print('3. Verify Firebase Authentication is enabled in Firebase Console');
    print('4. Verify Firestore is set up in Firebase Console');
    print('5. Check your internet connection\n');
  }
}
