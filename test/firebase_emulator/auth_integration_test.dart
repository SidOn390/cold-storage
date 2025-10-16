// test/firebase_emulator/auth_integration_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_emulator_helper.dart';

void main() {
  group('Firebase Auth Integration Tests (Emulator)', () {
    setUpAll(() async {
      await FirebaseEmulatorHelper.setupEmulator();
    });

    setUp(() async {
      // Sign out before each test
      await FirebaseEmulatorHelper.signOut();
    });

    test('Can create new user in emulator', () async {
      final email = 'test${DateTime.now().millisecondsSinceEpoch}@test.com';
      final password = 'testPassword123';

      final userCredential = await FirebaseEmulatorHelper.createTestUser(
        email: email,
        password: password,
      );

      expect(userCredential.user, isNotNull);
      expect(userCredential.user!.email, email);
    });

    test('Can sign in with email and password', () async {
      final email = 'signin${DateTime.now().millisecondsSinceEpoch}@test.com';
      final password = 'Password123!';

      // First create the user
      await FirebaseEmulatorHelper.createTestUser(
        email: email,
        password: password,
      );

      // Sign out
      await FirebaseAuth.instance.signOut();

      // Now sign in
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      expect(userCredential.user, isNotNull);
      expect(userCredential.user!.email, email);
    });

    test('Sign in fails with wrong password', () async {
      final email = 'wrong${DateTime.now().millisecondsSinceEpoch}@test.com';
      final password = 'CorrectPassword123!';

      // Create user
      await FirebaseEmulatorHelper.createTestUser(
        email: email,
        password: password,
      );

      // Sign out
      await FirebaseAuth.instance.signOut();

      // Try to sign in with wrong password
      expect(
        () => FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: 'WrongPassword123!',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('Can sign out successfully', () async {
      final email = 'signout${DateTime.now().millisecondsSinceEpoch}@test.com';
      final password = 'Password123!';

      // Create and sign in user
      await FirebaseEmulatorHelper.createTestUser(
        email: email,
        password: password,
      );

      expect(FirebaseAuth.instance.currentUser, isNotNull);

      // Sign out
      await FirebaseAuth.instance.signOut();

      expect(FirebaseAuth.instance.currentUser, isNull);
    });

    test('Current user persists after sign in', () async {
      final email = 'persist${DateTime.now().millisecondsSinceEpoch}@test.com';
      final password = 'Password123!';

      await FirebaseEmulatorHelper.createTestUser(
        email: email,
        password: password,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      expect(currentUser, isNotNull);
      expect(currentUser!.email, email);
    });

    test('User UID is generated correctly', () async {
      final email = 'uid${DateTime.now().millisecondsSinceEpoch}@test.com';
      final password = 'Password123!';

      final userCredential = await FirebaseEmulatorHelper.createTestUser(
        email: email,
        password: password,
      );

      expect(userCredential.user!.uid, isNotEmpty);
      expect(userCredential.user!.uid.length, greaterThan(10));
    });

    test('Cannot create user with invalid email', () async {
      expect(
        () => FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: 'invalid-email',
          password: 'Password123!',
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('Cannot create user with weak password', () async {
      final email = 'weak${DateTime.now().millisecondsSinceEpoch}@test.com';

      expect(
        () => FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: '123', // Too weak
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });
}
