// lib/models/app_user.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cold_storage/models/user_role.dart';

/// Model representing a user in the application
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final bool isActive;
  final Timestamp? createdAt;
  final Timestamp? lastLoginAt;
  final String? phoneNumber;
  final String? createdBy;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.isActive = true,
    this.createdAt,
    this.lastLoginAt,
    this.phoneNumber,
    this.createdBy,
  });

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'email_lowercase': email.toLowerCase(),
      'displayName': displayName,
      'role': role.value,
      'isActive': isActive,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'lastLoginAt': lastLoginAt,
      'phoneNumber': phoneNumber,
      'createdBy': createdBy,
    };
  }

  /// Create from Firestore document
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: data['uid'] ?? doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: UserRoleExtension.fromString(data['role'] ?? 'viewer'),
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'],
      lastLoginAt: data['lastLoginAt'],
      phoneNumber: data['phoneNumber'],
      createdBy: data['createdBy'],
    );
  }

  /// Create a copy with updated fields
  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    bool? isActive,
    Timestamp? createdAt,
    Timestamp? lastLoginAt,
    String? phoneNumber,
    String? createdBy,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Get initials from display name
  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  /// Check if user has specific permission
  bool canPerformAction(String action) {
    switch (action) {
      case 'manage_users':
        return role.canManageUsers;
      case 'manage_master_data':
        return role.canManageMasterData;
      case 'create_receipts':
        return role.canCreateReceipts;
      case 'edit_receipts':
        return role.canEditReceipts;
      case 'delete_receipts':
        return role.canDeleteReceipts;
      case 'create_deliveries':
        return role.canCreateDeliveries;
      case 'edit_deliveries':
        return role.canEditDeliveries;
      case 'delete_deliveries':
        return role.canDeleteDeliveries;
      case 'view_reports':
        return role.canViewReports;
      case 'access_data_maintenance':
        return role.canAccessDataMaintenance;
      default:
        return false;
    }
  }
}
