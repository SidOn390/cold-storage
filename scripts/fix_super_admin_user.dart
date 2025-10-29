// scripts/fix_super_admin_user.dart
//
// This script fixes or creates the Firestore user document for the super admin.
// Run this if you're getting "permission-denied" errors when accessing rent rates or other collections.
//
// Usage:
//   dart scripts/fix_super_admin_user.dart
//
// Or use Firebase emulators:
//   firebase emulators:start
//   FIRESTORE_EMULATOR_HOST="localhost:8080" dart scripts/fix_super_admin_user.dart

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import firebase options
import '../lib/firebase_options.dart';

Future<void> main() async {
  print('=== Super Admin User Document Fix Script ===\n');

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully\n');
  } catch (e) {
    print('❌ Failed to initialize Firebase: $e');
    exit(1);
  }

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // Super admin credentials (matching create_super_admin_helper.dart)
  const email = 'admin@coldapp.com';
  const displayName = 'Siddharth Shah';
  const role = 'super_admin';

  print('Checking for super admin user...');
  print('Email: $email');
  print('Display Name: $displayName\n');

  try {
    // Try to sign in to get the user UID
    // (If user doesn't exist in Auth, this will fail)
    UserCredential? userCred;

    // Check if already signed in
    User? currentUser = auth.currentUser;

    if (currentUser == null || currentUser.email != email) {
      print('📝 Note: To proceed, you need to provide the password for $email');
      print('Default password from setup: Admin123');
      stdout.write('Enter password (or press Enter to use default): ');
      final passwordInput = stdin.readLineSync()?.trim() ?? '';
      final password = passwordInput.isEmpty ? 'Admin123' : passwordInput;

      print('\nAttempting to sign in...');
      try {
        userCred = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        currentUser = userCred.user;
        print('✅ Successfully signed in as $email\n');
      } catch (e) {
        print('❌ Failed to sign in: $e');
        print('\nThe Firebase Auth user might not exist.');
        print('Please run: dart scripts/create_super_admin.dart');
        exit(1);
      }
    } else {
      print('✅ Already signed in as ${currentUser.email}\n');
    }

    if (currentUser == null) {
      print('❌ No user signed in');
      exit(1);
    }

    final uid = currentUser.uid;
    print('User UID: $uid');

    // Check if Firestore document exists
    final docRef = firestore.collection('users').doc(uid);
    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      print('✅ User document exists in Firestore');

      final data = docSnapshot.data() as Map<String, dynamic>;
      print('\nCurrent document data:');
      print('  - role: ${data['role']}');
      print('  - isActive: ${data['isActive']}');
      print('  - displayName: ${data['displayName']}');
      print('  - email: ${data['email']}');

      // Check if required fields are present and correct
      bool needsUpdate = false;
      final updates = <String, dynamic>{};

      if (data['role'] != role) {
        print('\n⚠️  Role is incorrect (${data['role']} != $role)');
        updates['role'] = role;
        needsUpdate = true;
      }

      if (data['isActive'] != true) {
        print('\n⚠️  isActive is not true');
        updates['isActive'] = true;
        needsUpdate = true;
      }

      if (data['displayName'] != displayName) {
        print('\n⚠️  displayName is incorrect');
        updates['displayName'] = displayName;
        needsUpdate = true;
      }

      if (data['email'] != email) {
        print('\n⚠️  email is incorrect');
        updates['email'] = email;
        needsUpdate = true;
      }

      if (!data.containsKey('uid')) {
        updates['uid'] = uid;
        needsUpdate = true;
      }

      if (!data.containsKey('email_lowercase')) {
        updates['email_lowercase'] = email.toLowerCase();
        needsUpdate = true;
      }

      if (needsUpdate) {
        print('\n📝 Updating user document...');
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await docRef.update(updates);
        print('✅ User document updated successfully!');
      } else {
        print('\n✅ All fields are correct. No update needed.');
      }
    } else {
      print('⚠️  User document does NOT exist in Firestore');
      print('\n📝 Creating user document...');

      await docRef.set({
        'uid': uid,
        'email': email,
        'email_lowercase': email.toLowerCase(),
        'displayName': displayName,
        'role': role,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'phoneNumber': null,
        'createdBy': uid, // Self-created
      });

      print('✅ User document created successfully!');
    }

    print('\n=== Summary ===');
    print('✅ Super admin user is now properly configured');
    print('✅ Email: $email');
    print('✅ Role: $role');
    print('✅ UID: $uid');
    print('\nYou should now be able to access rent rates and all other collections.');

    // Sign out
    await auth.signOut();
    print('\n✅ Signed out. You can now log in to the app.');

  } catch (e, stackTrace) {
    print('\n❌ Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }

  exit(0);
}
