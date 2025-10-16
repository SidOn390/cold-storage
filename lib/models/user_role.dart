// lib/models/user_role.dart

/// Enum representing different user roles in the system
enum UserRole {
  /// Super admin with full system access
  superAdmin,

  /// Admin with most privileges
  admin,

  /// Manager with operational access
  manager,

  /// Operator with limited write access
  operator,

  /// Viewer with read-only access
  viewer,
}

/// Extension to provide utility methods for UserRole
extension UserRoleExtension on UserRole {
  /// Get display name for the role
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.operator:
        return 'Operator';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  /// Get role description
  String get description {
    switch (this) {
      case UserRole.superAdmin:
        return 'Full system access including user management';
      case UserRole.admin:
        return 'Manage data, reports, and settings';
      case UserRole.manager:
        return 'Create and manage receipts and deliveries';
      case UserRole.operator:
        return 'Create receipts and deliveries';
      case UserRole.viewer:
        return 'View-only access to data';
    }
  }

  /// Get string value for storage
  String get value {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.manager:
        return 'manager';
      case UserRole.operator:
        return 'operator';
      case UserRole.viewer:
        return 'viewer';
    }
  }

  /// Parse role from string
  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'operator':
        return UserRole.operator;
      case 'viewer':
        return UserRole.viewer;
      default:
        return UserRole.viewer; // Default to most restrictive
    }
  }

  /// Check if role can manage users
  bool get canManageUsers {
    return this == UserRole.superAdmin;
  }

  /// Check if role can manage master data
  bool get canManageMasterData {
    return this == UserRole.superAdmin ||
           this == UserRole.admin;
  }

  /// Check if role can create receipts
  bool get canCreateReceipts {
    return this != UserRole.viewer;
  }

  /// Check if role can edit receipts
  bool get canEditReceipts {
    return this == UserRole.superAdmin ||
           this == UserRole.admin ||
           this == UserRole.manager;
  }

  /// Check if role can delete receipts
  bool get canDeleteReceipts {
    return this == UserRole.superAdmin ||
           this == UserRole.admin;
  }

  /// Check if role can create deliveries
  bool get canCreateDeliveries {
    return this != UserRole.viewer;
  }

  /// Check if role can edit deliveries
  bool get canEditDeliveries {
    return this == UserRole.superAdmin ||
           this == UserRole.admin ||
           this == UserRole.manager;
  }

  /// Check if role can delete deliveries
  bool get canDeleteDeliveries {
    return this == UserRole.superAdmin ||
           this == UserRole.admin;
  }

  /// Check if role can view reports
  bool get canViewReports {
    return true; // All roles can view reports
  }

  /// Check if role can access data maintenance
  bool get canAccessDataMaintenance {
    return this == UserRole.superAdmin ||
           this == UserRole.admin;
  }

  /// Check if role has higher or equal privilege than another role
  bool hasPrivilegeOver(UserRole other) {
    final privileges = {
      UserRole.superAdmin: 5,
      UserRole.admin: 4,
      UserRole.manager: 3,
      UserRole.operator: 2,
      UserRole.viewer: 1,
    };

    return (privileges[this] ?? 0) >= (privileges[other] ?? 0);
  }
}
