// test/services/user_management_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cold_storage/services/user_management_service.dart';
import 'package:cold_storage/models/app_user.dart';
import 'package:cold_storage/models/user_role.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Initialize Firebase for testing - using actual Firebase, not emulator
    // Note: These tests will run against your production Firebase
    // Make sure to clean up test data after running
  });

  tearDownAll(() async {
    // Cleanup will be done in individual test tearDown methods
  });

  group('UserManagementService CRUD Tests', () {
    late UserManagementService service;
    late FirebaseAuth auth;
    late FirebaseFirestore firestore;
    String? testUserId;

    setUp(() async {
      service = UserManagementService();
      auth = FirebaseAuth.instance;
      firestore = FirebaseFirestore.instance;

      // Clear all users before each test
      final users = await firestore.collection('users').get();
      for (var doc in users.docs) {
        await doc.reference.delete();
      }

      // Note: Firebase Auth doesn't provide a way to list/delete all users from client SDK
      // In production, you'd use Firebase Admin SDK for this
    });

    tearDown(() async {
      // Clean up test user if created
      if (testUserId != null) {
        try {
          await service.deleteUser(testUserId!);
        } catch (_) {
          // Ignore errors during cleanup
        }
        testUserId = null;
      }

      // Clear all test data
      final users = await firestore.collection('users').get();
      for (var doc in users.docs) {
        await doc.reference.delete();
      }
    });

    test('CREATE - Can create a new user', () async {
      final user = await service.createUser(
        email: 'testuser@example.com',
        password: 'Password123',
        displayName: 'Test User',
        role: UserRole.viewer,
      );

      testUserId = user.uid;

      expect(user.email, 'testuser@example.com');
      expect(user.displayName, 'Test User');
      expect(user.role, UserRole.viewer);
      expect(user.isActive, true);

      // Verify user exists in Firestore
      final doc = await firestore.collection('users').doc(user.uid).get();
      expect(doc.exists, true);
      expect(doc.data()?['email'], 'testuser@example.com');
    });

    test('CREATE - Can create user with phone number', () async {
      final user = await service.createUser(
        email: 'testphone@example.com',
        password: 'Password123',
        displayName: 'Test Phone User',
        role: UserRole.operator,
        phoneNumber: '+1234567890',
      );

      testUserId = user.uid;

      expect(user.phoneNumber, '+1234567890');
      expect(user.role, UserRole.operator);
    });

    test('CREATE - Throws error when creating duplicate email', () async {
      // Create first user
      final user1 = await service.createUser(
        email: 'duplicate@example.com',
        password: 'Password123',
        displayName: 'First User',
        role: UserRole.viewer,
      );

      testUserId = user1.uid;

      // Try to create duplicate
      expect(
        () async => await service.createUser(
          email: 'duplicate@example.com',
          password: 'Password123',
          displayName: 'Duplicate User',
          role: UserRole.viewer,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('READ - Can get user by UID', () async {
      final createdUser = await service.createUser(
        email: 'getbyuid@example.com',
        password: 'Password123',
        displayName: 'Get By UID Test',
        role: UserRole.manager,
      );

      testUserId = createdUser.uid;

      final fetchedUser = await service.getUserByUid(createdUser.uid);

      expect(fetchedUser, isNotNull);
      expect(fetchedUser!.uid, createdUser.uid);
      expect(fetchedUser.email, 'getbyuid@example.com');
      expect(fetchedUser.displayName, 'Get By UID Test');
      expect(fetchedUser.role, UserRole.manager);
    });

    test('READ - Returns null for non-existent user', () async {
      final user = await service.getUserByUid('nonexistent-uid');
      expect(user, isNull);
    });

    test('READ - Can stream all users', () async {
      // Create multiple users
      final user1 = await service.createUser(
        email: 'stream1@example.com',
        password: 'Password123',
        displayName: 'Stream User 1',
        role: UserRole.viewer,
      );

      final user2 = await service.createUser(
        email: 'stream2@example.com',
        password: 'Password123',
        displayName: 'Stream User 2',
        role: UserRole.operator,
      );

      final user3 = await service.createUser(
        email: 'stream3@example.com',
        password: 'Password123',
        displayName: 'Stream User 3',
        role: UserRole.manager,
      );

      // Clean up all three users
      testUserId = user3.uid; // Will clean up the last one

      // Get users stream
      final stream = service.getUsers();
      final users = await stream.first;

      expect(users.length, 3);
      expect(users.any((u) => u.email == 'stream1@example.com'), true);
      expect(users.any((u) => u.email == 'stream2@example.com'), true);
      expect(users.any((u) => u.email == 'stream3@example.com'), true);

      // Clean up
      await service.deleteUser(user1.uid);
      await service.deleteUser(user2.uid);
    });

    test('READ - Can search users by name', () async {
      // Create test users
      final user1 = await service.createUser(
        email: 'john.doe@example.com',
        password: 'Password123',
        displayName: 'John Doe',
        role: UserRole.viewer,
      );

      final user2 = await service.createUser(
        email: 'jane.smith@example.com',
        password: 'Password123',
        displayName: 'Jane Smith',
        role: UserRole.operator,
      );

      final user3 = await service.createUser(
        email: 'johnny.bravo@example.com',
        password: 'Password123',
        displayName: 'Johnny Bravo',
        role: UserRole.manager,
      );

      testUserId = user3.uid;

      // Search for "John"
      final results = await service.searchUsers('John');

      expect(results.length, 2);
      expect(results.any((u) => u.displayName == 'John Doe'), true);
      expect(results.any((u) => u.displayName == 'Johnny Bravo'), true);
      expect(results.any((u) => u.displayName == 'Jane Smith'), false);

      // Clean up
      await service.deleteUser(user1.uid);
      await service.deleteUser(user2.uid);
    });

    test('READ - Can search users by email', () async {
      final user = await service.createUser(
        email: 'searchable@example.com',
        password: 'Password123',
        displayName: 'Searchable User',
        role: UserRole.viewer,
      );

      testUserId = user.uid;

      final results = await service.searchUsers('searchable');

      expect(results.length, 1);
      expect(results.first.email, 'searchable@example.com');
    });

    test('UPDATE - Can update user profile', () async {
      final user = await service.createUser(
        email: 'updatetest@example.com',
        password: 'Password123',
        displayName: 'Original Name',
        role: UserRole.viewer,
      );

      testUserId = user.uid;

      // Update user
      final updatedUser = AppUser(
        uid: user.uid,
        email: user.email,
        displayName: 'Updated Name',
        role: user.role,
        isActive: user.isActive,
        createdAt: user.createdAt,
        createdBy: user.createdBy,
        phoneNumber: '+9876543210',
      );

      await service.updateUser(updatedUser);

      // Verify update
      final fetchedUser = await service.getUserByUid(user.uid);
      expect(fetchedUser, isNotNull);
      expect(fetchedUser!.displayName, 'Updated Name');
      expect(fetchedUser.phoneNumber, '+9876543210');
    });

    test('UPDATE - Can update user role', () async {
      final user = await service.createUser(
        email: 'roletest@example.com',
        password: 'Password123',
        displayName: 'Role Test User',
        role: UserRole.viewer,
      );

      testUserId = user.uid;

      expect(user.role, UserRole.viewer);

      // Update role
      await service.updateUserRole(user.uid, UserRole.manager);

      // Verify update
      final fetchedUser = await service.getUserByUid(user.uid);
      expect(fetchedUser, isNotNull);
      expect(fetchedUser!.role, UserRole.manager);
    });

    test('UPDATE - Can deactivate user', () async {
      final user = await service.createUser(
        email: 'deactivate@example.com',
        password: 'Password123',
        displayName: 'Deactivate Test',
        role: UserRole.viewer,
      );

      testUserId = user.uid;

      expect(user.isActive, true);

      // Deactivate user
      await service.deactivateUser(user.uid);

      // Verify deactivation
      final fetchedUser = await service.getUserByUid(user.uid);
      expect(fetchedUser, isNotNull);
      expect(fetchedUser!.isActive, false);
    });

    test('UPDATE - Can reactivate user', () async {
      final user = await service.createUser(
        email: 'reactivate@example.com',
        password: 'Password123',
        displayName: 'Reactivate Test',
        role: UserRole.viewer,
      );

      testUserId = user.uid;

      // Deactivate then reactivate
      await service.deactivateUser(user.uid);
      await service.toggleUserStatus(user.uid, true);

      // Verify reactivation
      final fetchedUser = await service.getUserByUid(user.uid);
      expect(fetchedUser, isNotNull);
      expect(fetchedUser!.isActive, true);
    });

    test('DELETE - Can delete user', () async {
      final user = await service.createUser(
        email: 'deletetest@example.com',
        password: 'Password123',
        displayName: 'Delete Test',
        role: UserRole.viewer,
      );

      final uid = user.uid;

      // Verify user exists
      var fetchedUser = await service.getUserByUid(uid);
      expect(fetchedUser, isNotNull);

      // Delete user
      await service.deleteUser(uid);

      // Verify user is deleted from Firestore
      fetchedUser = await service.getUserByUid(uid);
      expect(fetchedUser, isNull);

      testUserId = null; // Already deleted
    });

    test('DELETE - Deleting non-existent user does not throw error', () async {
      // This should not throw an error
      await service.deleteUser('nonexistent-uid-12345');
    });

    test('GET STATISTICS - Returns correct user statistics', () async {
      // Create users with different roles
      final user1 = await service.createUser(
        email: 'stats1@example.com',
        password: 'Password123',
        displayName: 'Stats User 1',
        role: UserRole.superAdmin,
      );

      final user2 = await service.createUser(
        email: 'stats2@example.com',
        password: 'Password123',
        displayName: 'Stats User 2',
        role: UserRole.admin,
      );

      final user3 = await service.createUser(
        email: 'stats3@example.com',
        password: 'Password123',
        displayName: 'Stats User 3',
        role: UserRole.manager,
      );

      final user4 = await service.createUser(
        email: 'stats4@example.com',
        password: 'Password123',
        displayName: 'Stats User 4',
        role: UserRole.viewer,
      );

      testUserId = user4.uid;

      // Deactivate one user
      await service.deactivateUser(user4.uid);

      // Get statistics
      final stats = await service.getUserStats();

      expect(stats['total'], 4);
      expect(stats['active'], 3);
      expect(stats['inactive'], 1);
      expect(stats['byRole']?['superAdmin'], 1);
      expect(stats['byRole']?['admin'], 1);
      expect(stats['byRole']?['manager'], 1);
      expect(stats['byRole']?['viewer'], 1);

      // Clean up
      await service.deleteUser(user1.uid);
      await service.deleteUser(user2.uid);
      await service.deleteUser(user3.uid);
    });

    test('PERMISSIONS - User has correct role permissions', () async {
      final superAdmin = await service.createUser(
        email: 'superadmin@example.com',
        password: 'Password123',
        displayName: 'Super Admin',
        role: UserRole.superAdmin,
      );

      final manager = await service.createUser(
        email: 'manager@example.com',
        password: 'Password123',
        displayName: 'Manager',
        role: UserRole.manager,
      );

      final viewer = await service.createUser(
        email: 'viewer@example.com',
        password: 'Password123',
        displayName: 'Viewer',
        role: UserRole.viewer,
      );

      testUserId = viewer.uid;

      // Test permissions (permissions are on UserRole extension)
      expect(superAdmin.role.canManageUsers, true);
      expect(superAdmin.role.canEditReceipts, true);
      expect(superAdmin.role.canCreateReceipts, true);
      expect(superAdmin.role.canViewReports, true);

      expect(manager.role.canManageUsers, false);
      expect(manager.role.canEditReceipts, true);
      expect(manager.role.canCreateReceipts, true);
      expect(manager.role.canViewReports, true);

      expect(viewer.role.canManageUsers, false);
      expect(viewer.role.canEditReceipts, false);
      expect(viewer.role.canCreateReceipts, false);
      expect(viewer.role.canViewReports, true);

      // Clean up
      await service.deleteUser(superAdmin.uid);
      await service.deleteUser(manager.uid);
    });

    test('ROLE HIERARCHY - Roles have correct privilege levels', () async {
      final superAdmin = await service.createUser(
        email: 'hierarchy1@example.com',
        password: 'Password123',
        displayName: 'Super Admin',
        role: UserRole.superAdmin,
      );

      final admin = await service.createUser(
        email: 'hierarchy2@example.com',
        password: 'Password123',
        displayName: 'Admin',
        role: UserRole.admin,
      );

      final manager = await service.createUser(
        email: 'hierarchy3@example.com',
        password: 'Password123',
        displayName: 'Manager',
        role: UserRole.manager,
      );

      testUserId = manager.uid;

      // Test privilege hierarchy
      expect(superAdmin.role.hasPrivilegeOver(admin.role), true);
      expect(superAdmin.role.hasPrivilegeOver(manager.role), true);
      expect(admin.role.hasPrivilegeOver(manager.role), true);
      expect(manager.role.hasPrivilegeOver(admin.role), false);

      // Clean up
      await service.deleteUser(superAdmin.uid);
      await service.deleteUser(admin.uid);
    });
  });
}
