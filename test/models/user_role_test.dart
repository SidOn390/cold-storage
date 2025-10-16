// test/models/user_role_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cold_storage/models/user_role.dart';

void main() {
  group('UserRole Tests', () {
    test('UserRole enum has all expected values', () {
      expect(UserRole.values.length, 5);
      expect(UserRole.values, contains(UserRole.superAdmin));
      expect(UserRole.values, contains(UserRole.admin));
      expect(UserRole.values, contains(UserRole.manager));
      expect(UserRole.values, contains(UserRole.operator));
      expect(UserRole.values, contains(UserRole.viewer));
    });

    test('Display names are correct', () {
      expect(UserRole.superAdmin.displayName, 'Super Admin');
      expect(UserRole.admin.displayName, 'Admin');
      expect(UserRole.manager.displayName, 'Manager');
      expect(UserRole.operator.displayName, 'Operator');
      expect(UserRole.viewer.displayName, 'Viewer');
    });

    test('Descriptions are not empty', () {
      for (final role in UserRole.values) {
        expect(role.description, isNotEmpty);
      }
    });

    test('Value strings are correct', () {
      expect(UserRole.superAdmin.value, 'super_admin');
      expect(UserRole.admin.value, 'admin');
      expect(UserRole.manager.value, 'manager');
      expect(UserRole.operator.value, 'operator');
      expect(UserRole.viewer.value, 'viewer');
    });

    test('fromString parses correctly', () {
      expect(UserRoleExtension.fromString('super_admin'), UserRole.superAdmin);
      expect(UserRoleExtension.fromString('superadmin'), UserRole.superAdmin);
      expect(UserRoleExtension.fromString('admin'), UserRole.admin);
      expect(UserRoleExtension.fromString('ADMIN'), UserRole.admin);
      expect(UserRoleExtension.fromString('manager'), UserRole.manager);
      expect(UserRoleExtension.fromString('operator'), UserRole.operator);
      expect(UserRoleExtension.fromString('viewer'), UserRole.viewer);
    });

    test('fromString defaults to viewer for unknown values', () {
      expect(UserRoleExtension.fromString('unknown'), UserRole.viewer);
      expect(UserRoleExtension.fromString(''), UserRole.viewer);
      expect(UserRoleExtension.fromString('invalid'), UserRole.viewer);
    });

    group('Permission Tests', () {
      test('canManageUsers permission', () {
        expect(UserRole.superAdmin.canManageUsers, true);
        expect(UserRole.admin.canManageUsers, false);
        expect(UserRole.manager.canManageUsers, false);
        expect(UserRole.operator.canManageUsers, false);
        expect(UserRole.viewer.canManageUsers, false);
      });

      test('canManageMasterData permission', () {
        expect(UserRole.superAdmin.canManageMasterData, true);
        expect(UserRole.admin.canManageMasterData, true);
        expect(UserRole.manager.canManageMasterData, false);
        expect(UserRole.operator.canManageMasterData, false);
        expect(UserRole.viewer.canManageMasterData, false);
      });

      test('canCreateReceipts permission', () {
        expect(UserRole.superAdmin.canCreateReceipts, true);
        expect(UserRole.admin.canCreateReceipts, true);
        expect(UserRole.manager.canCreateReceipts, true);
        expect(UserRole.operator.canCreateReceipts, true);
        expect(UserRole.viewer.canCreateReceipts, false);
      });

      test('canEditReceipts permission', () {
        expect(UserRole.superAdmin.canEditReceipts, true);
        expect(UserRole.admin.canEditReceipts, true);
        expect(UserRole.manager.canEditReceipts, true);
        expect(UserRole.operator.canEditReceipts, false);
        expect(UserRole.viewer.canEditReceipts, false);
      });

      test('canDeleteReceipts permission', () {
        expect(UserRole.superAdmin.canDeleteReceipts, true);
        expect(UserRole.admin.canDeleteReceipts, true);
        expect(UserRole.manager.canDeleteReceipts, false);
        expect(UserRole.operator.canDeleteReceipts, false);
        expect(UserRole.viewer.canDeleteReceipts, false);
      });

      test('canCreateDeliveries permission', () {
        expect(UserRole.superAdmin.canCreateDeliveries, true);
        expect(UserRole.admin.canCreateDeliveries, true);
        expect(UserRole.manager.canCreateDeliveries, true);
        expect(UserRole.operator.canCreateDeliveries, true);
        expect(UserRole.viewer.canCreateDeliveries, false);
      });

      test('canEditDeliveries permission', () {
        expect(UserRole.superAdmin.canEditDeliveries, true);
        expect(UserRole.admin.canEditDeliveries, true);
        expect(UserRole.manager.canEditDeliveries, true);
        expect(UserRole.operator.canEditDeliveries, false);
        expect(UserRole.viewer.canEditDeliveries, false);
      });

      test('canDeleteDeliveries permission', () {
        expect(UserRole.superAdmin.canDeleteDeliveries, true);
        expect(UserRole.admin.canDeleteDeliveries, true);
        expect(UserRole.manager.canDeleteDeliveries, false);
        expect(UserRole.operator.canDeleteDeliveries, false);
        expect(UserRole.viewer.canDeleteDeliveries, false);
      });

      test('canViewReports permission - all roles', () {
        for (final role in UserRole.values) {
          expect(role.canViewReports, true);
        }
      });

      test('canAccessDataMaintenance permission', () {
        expect(UserRole.superAdmin.canAccessDataMaintenance, true);
        expect(UserRole.admin.canAccessDataMaintenance, true);
        expect(UserRole.manager.canAccessDataMaintenance, false);
        expect(UserRole.operator.canAccessDataMaintenance, false);
        expect(UserRole.viewer.canAccessDataMaintenance, false);
      });
    });

    group('Privilege Hierarchy Tests', () {
      test('SuperAdmin has privilege over all roles', () {
        expect(UserRole.superAdmin.hasPrivilegeOver(UserRole.superAdmin), true);
        expect(UserRole.superAdmin.hasPrivilegeOver(UserRole.admin), true);
        expect(UserRole.superAdmin.hasPrivilegeOver(UserRole.manager), true);
        expect(UserRole.superAdmin.hasPrivilegeOver(UserRole.operator), true);
        expect(UserRole.superAdmin.hasPrivilegeOver(UserRole.viewer), true);
      });

      test('Admin privilege hierarchy', () {
        expect(UserRole.admin.hasPrivilegeOver(UserRole.superAdmin), false);
        expect(UserRole.admin.hasPrivilegeOver(UserRole.admin), true);
        expect(UserRole.admin.hasPrivilegeOver(UserRole.manager), true);
        expect(UserRole.admin.hasPrivilegeOver(UserRole.operator), true);
        expect(UserRole.admin.hasPrivilegeOver(UserRole.viewer), true);
      });

      test('Manager privilege hierarchy', () {
        expect(UserRole.manager.hasPrivilegeOver(UserRole.superAdmin), false);
        expect(UserRole.manager.hasPrivilegeOver(UserRole.admin), false);
        expect(UserRole.manager.hasPrivilegeOver(UserRole.manager), true);
        expect(UserRole.manager.hasPrivilegeOver(UserRole.operator), true);
        expect(UserRole.manager.hasPrivilegeOver(UserRole.viewer), true);
      });

      test('Operator privilege hierarchy', () {
        expect(UserRole.operator.hasPrivilegeOver(UserRole.superAdmin), false);
        expect(UserRole.operator.hasPrivilegeOver(UserRole.admin), false);
        expect(UserRole.operator.hasPrivilegeOver(UserRole.manager), false);
        expect(UserRole.operator.hasPrivilegeOver(UserRole.operator), true);
        expect(UserRole.operator.hasPrivilegeOver(UserRole.viewer), true);
      });

      test('Viewer has lowest privilege', () {
        expect(UserRole.viewer.hasPrivilegeOver(UserRole.superAdmin), false);
        expect(UserRole.viewer.hasPrivilegeOver(UserRole.admin), false);
        expect(UserRole.viewer.hasPrivilegeOver(UserRole.manager), false);
        expect(UserRole.viewer.hasPrivilegeOver(UserRole.operator), false);
        expect(UserRole.viewer.hasPrivilegeOver(UserRole.viewer), true);
      });
    });

    group('Role Comparison Tests', () {
      test('Roles have correct privilege levels', () {
        expect(
          UserRole.superAdmin.hasPrivilegeOver(UserRole.admin),
          true,
        );

        expect(
          UserRole.admin.hasPrivilegeOver(UserRole.manager),
          true,
        );

        expect(
          UserRole.manager.hasPrivilegeOver(UserRole.operator),
          true,
        );

        expect(
          UserRole.operator.hasPrivilegeOver(UserRole.viewer),
          true,
        );
      });

      test('Same role has privilege over itself', () {
        for (final role in UserRole.values) {
          expect(role.hasPrivilegeOver(role), true);
        }
      });

      test('Lower roles do not have privilege over higher roles', () {
        expect(UserRole.viewer.hasPrivilegeOver(UserRole.operator), false);
        expect(UserRole.operator.hasPrivilegeOver(UserRole.manager), false);
        expect(UserRole.manager.hasPrivilegeOver(UserRole.admin), false);
        expect(UserRole.admin.hasPrivilegeOver(UserRole.superAdmin), false);
      });
    });
  });
}
