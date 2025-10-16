// test/models/app_user_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cold_storage/models/app_user.dart';
import 'package:cold_storage/models/user_role.dart';

void main() {
  group('AppUser Model Tests', () {
    final testTimestamp = Timestamp.fromDate(DateTime(2025, 1, 16));

    test('AppUser constructor creates instance with required fields', () {
      final user = AppUser(
        uid: 'user123',
        email: 'test@example.com',
        displayName: 'Test User',
        role: UserRole.admin,
      );

      expect(user.uid, 'user123');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.role, UserRole.admin);
      expect(user.isActive, true); // default value
      expect(user.createdAt, isNull);
      expect(user.lastLoginAt, isNull);
      expect(user.phoneNumber, isNull);
      expect(user.createdBy, isNull);
    });

    test('AppUser constructor accepts optional fields', () {
      final user = AppUser(
        uid: 'user456',
        email: 'admin@example.com',
        displayName: 'Admin User',
        role: UserRole.superAdmin,
        isActive: false,
        createdAt: testTimestamp,
        lastLoginAt: testTimestamp,
        phoneNumber: '+1234567890',
        createdBy: 'creator123',
      );

      expect(user.uid, 'user456');
      expect(user.isActive, false);
      expect(user.createdAt, testTimestamp);
      expect(user.lastLoginAt, testTimestamp);
      expect(user.phoneNumber, '+1234567890');
      expect(user.createdBy, 'creator123');
    });

    test('toJson converts AppUser to Map correctly', () {
      final user = AppUser(
        uid: 'user789',
        email: 'manager@example.com',
        displayName: 'Manager User',
        role: UserRole.manager,
        isActive: true,
        phoneNumber: '+9876543210',
        createdBy: 'admin123',
        createdAt: testTimestamp,
      );

      final json = user.toJson();

      expect(json['uid'], 'user789');
      expect(json['email'], 'manager@example.com');
      expect(json['email_lowercase'], 'manager@example.com');
      expect(json['displayName'], 'Manager User');
      expect(json['role'], 'manager');
      expect(json['isActive'], true);
      expect(json['phoneNumber'], '+9876543210');
      expect(json['createdBy'], 'admin123');
      expect(json['createdAt'], testTimestamp);
    });

    test('toJson uses FieldValue.serverTimestamp when createdAt is null', () {
      final user = AppUser(
        uid: 'user999',
        email: 'operator@example.com',
        displayName: 'Operator User',
        role: UserRole.operator,
      );

      final json = user.toJson();

      // createdAt should be FieldValue.serverTimestamp() when null
      expect(json['createdAt'], isA<FieldValue>());
    });

    test('toJson includes email_lowercase for case-insensitive queries', () {
      final user = AppUser(
        uid: 'user111',
        email: 'TestUser@Example.COM',
        displayName: 'Test User',
        role: UserRole.viewer,
      );

      final json = user.toJson();

      expect(json['email_lowercase'], 'testuser@example.com');
    });

    test('copyWith creates new instance with updated fields', () {
      final original = AppUser(
        uid: 'user222',
        email: 'original@example.com',
        displayName: 'Original Name',
        role: UserRole.operator,
        isActive: true,
      );

      final updated = original.copyWith(
        displayName: 'Updated Name',
        role: UserRole.manager,
        isActive: false,
      );

      // Updated fields should change
      expect(updated.displayName, 'Updated Name');
      expect(updated.role, UserRole.manager);
      expect(updated.isActive, false);

      // Other fields should remain the same
      expect(updated.uid, 'user222');
      expect(updated.email, 'original@example.com');
    });

    test('copyWith without parameters returns identical copy', () {
      final original = AppUser(
        uid: 'user333',
        email: 'test@example.com',
        displayName: 'Test User',
        role: UserRole.admin,
        phoneNumber: '+1234567890',
      );

      final copy = original.copyWith();

      expect(copy.uid, original.uid);
      expect(copy.email, original.email);
      expect(copy.displayName, original.displayName);
      expect(copy.role, original.role);
      expect(copy.phoneNumber, original.phoneNumber);
    });

    group('Initials Tests', () {
      test('Get initials from single name', () {
        final user = AppUser(
          uid: 'user444',
          email: 'test@example.com',
          displayName: 'John',
          role: UserRole.viewer,
        );

        expect(user.initials, 'J');
      });

      test('Get initials from full name', () {
        final user = AppUser(
          uid: 'user555',
          email: 'test@example.com',
          displayName: 'John Doe',
          role: UserRole.viewer,
        );

        expect(user.initials, 'JD');
      });

      test('Get initials from three-part name', () {
        final user = AppUser(
          uid: 'user666',
          email: 'test@example.com',
          displayName: 'John William Doe',
          role: UserRole.viewer,
        );

        expect(user.initials, 'JD'); // First and last
      });

      test('Get initials handles empty name', () {
        final user = AppUser(
          uid: 'user777',
          email: 'test@example.com',
          displayName: '',
          role: UserRole.viewer,
        );

        expect(user.initials, '?');
      });

      test('Initials are uppercase', () {
        final user = AppUser(
          uid: 'user888',
          email: 'test@example.com',
          displayName: 'john doe',
          role: UserRole.viewer,
        );

        expect(user.initials, 'JD');
      });
    });

    group('Permission Tests', () {
      test('SuperAdmin can manage users', () {
        final user = AppUser(
          uid: 'superadmin',
          email: 'super@example.com',
          displayName: 'Super Admin',
          role: UserRole.superAdmin,
        );

        expect(user.canPerformAction('manage_users'), true);
      });

      test('Admin can manage master data', () {
        final user = AppUser(
          uid: 'admin',
          email: 'admin@example.com',
          displayName: 'Admin',
          role: UserRole.admin,
        );

        expect(user.canPerformAction('manage_master_data'), true);
      });

      test('Viewer cannot create receipts', () {
        final user = AppUser(
          uid: 'viewer',
          email: 'viewer@example.com',
          displayName: 'Viewer',
          role: UserRole.viewer,
        );

        expect(user.canPerformAction('create_receipts'), false);
      });

      test('Operator can create deliveries', () {
        final user = AppUser(
          uid: 'operator',
          email: 'operator@example.com',
          displayName: 'Operator',
          role: UserRole.operator,
        );

        expect(user.canPerformAction('create_deliveries'), true);
      });

      test('Manager can edit receipts', () {
        final user = AppUser(
          uid: 'manager',
          email: 'manager@example.com',
          displayName: 'Manager',
          role: UserRole.manager,
        );

        expect(user.canPerformAction('edit_receipts'), true);
      });

      test('All roles can view reports', () {
        for (final role in UserRole.values) {
          final user = AppUser(
            uid: 'user',
            email: 'user@example.com',
            displayName: 'User',
            role: role,
          );

          expect(user.canPerformAction('view_reports'), true);
        }
      });

      test('Unknown action returns false', () {
        final user = AppUser(
          uid: 'user',
          email: 'user@example.com',
          displayName: 'User',
          role: UserRole.admin,
        );

        expect(user.canPerformAction('unknown_action'), false);
      });
    });

    group('User Status Tests', () {
      test('Active user has isActive true', () {
        final user = AppUser(
          uid: 'user',
          email: 'user@example.com',
          displayName: 'Active User',
          role: UserRole.operator,
          isActive: true,
        );

        expect(user.isActive, true);
      });

      test('Inactive user has isActive false', () {
        final user = AppUser(
          uid: 'user',
          email: 'user@example.com',
          displayName: 'Inactive User',
          role: UserRole.operator,
          isActive: false,
        );

        expect(user.isActive, false);
      });
    });

    group('Different Roles Tests', () {
      test('Create users with all role types', () {
        final roles = UserRole.values;

        for (final role in roles) {
          final user = AppUser(
            uid: 'user_${role.value}',
            email: '${role.value}@example.com',
            displayName: '${role.displayName} User',
            role: role,
          );

          expect(user.role, role);
          expect(user.email, contains(role.value));
        }
      });
    });
  });
}
