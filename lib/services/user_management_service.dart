// lib/services/user_management_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cold_storage/models/app_user.dart';
import 'package:cold_storage/models/user_role.dart';

class UserManagementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── User CRUD Operations ──────────────────────────────────────────

  /// Get stream of all users
  Stream<List<AppUser>> getUsers() {
    return _db
        .collection('users')
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromFirestore(doc))
            .toList());
  }

  /// Get a specific user by UID
  Future<AppUser?> getUserByUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Get current user's profile
  Future<AppUser?> getCurrentUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    return getUserByUid(currentUser.uid);
  }

  /// Create a new user with authentication and profile
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Must be logged in to create users');
      }

      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final newUser = userCredential.user!;

      // Create user profile in Firestore
      final appUser = AppUser(
        uid: newUser.uid,
        email: email,
        displayName: displayName,
        role: role,
        isActive: true,
        phoneNumber: phoneNumber,
        createdBy: currentUser.uid,
        createdAt: Timestamp.now(),
      );

      await _db.collection('users').doc(newUser.uid).set(appUser.toJson());

      // Sign out the newly created user and sign back in as admin
      await _auth.signOut();
      // Note: In production, you'd use Firebase Admin SDK for this

      return appUser;
    } catch (e) {
      rethrow;
    }
  }

  /// Update user profile (not auth details)
  Future<void> updateUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).update({
      'displayName': user.displayName,
      'role': user.role.value,
      'isActive': user.isActive,
      'phoneNumber': user.phoneNumber,
    });
  }

  /// Update user role
  Future<void> updateUserRole(String uid, UserRole newRole) async {
    await _db.collection('users').doc(uid).update({
      'role': newRole.value,
    });
  }

  /// Toggle user active status
  Future<void> toggleUserStatus(String uid, bool isActive) async {
    await _db.collection('users').doc(uid).update({
      'isActive': isActive,
    });
  }

  /// Delete user (soft delete by deactivating)
  Future<void> deactivateUser(String uid) async {
    await _db.collection('users').doc(uid).update({
      'isActive': false,
    });
  }

  /// Hard delete user (removes from Firestore and Auth)
  /// Note: Requires Firebase Admin SDK in production
  Future<void> deleteUser(String uid) async {
    // Delete from Firestore
    await _db.collection('users').doc(uid).delete();

    // Note: Deleting from Firebase Auth requires Admin SDK
    // In production, this would be done via Cloud Function
  }

  /// Update last login time
  Future<void> updateLastLogin(String uid) async {
    await _db.collection('users').doc(uid).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── User Query Operations ─────────────────────────────────────────

  /// Get users by role
  Future<List<AppUser>> getUsersByRole(UserRole role) async {
    final snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: role.value)
        .get();

    return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
  }

  /// Get active users
  Future<List<AppUser>> getActiveUsers() async {
    final snapshot = await _db
        .collection('users')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
  }

  /// Search users by email or name
  Future<List<AppUser>> searchUsers(String query) async {
    final lowercaseQuery = query.toLowerCase();

    final snapshot = await _db.collection('users').get();

    return snapshot.docs
        .map((doc) => AppUser.fromFirestore(doc))
        .where((user) =>
            user.email.toLowerCase().contains(lowercaseQuery) ||
            user.displayName.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStats() async {
    final snapshot = await _db.collection('users').get();
    final users = snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();

    final roleCount = <UserRole, int>{};
    int activeCount = 0;

    for (final user in users) {
      roleCount[user.role] = (roleCount[user.role] ?? 0) + 1;
      if (user.isActive) activeCount++;
    }

    return {
      'total': users.length,
      'active': activeCount,
      'inactive': users.length - activeCount,
      'byRole': {
        'superAdmin': roleCount[UserRole.superAdmin] ?? 0,
        'admin': roleCount[UserRole.admin] ?? 0,
        'manager': roleCount[UserRole.manager] ?? 0,
        'operator': roleCount[UserRole.operator] ?? 0,
        'viewer': roleCount[UserRole.viewer] ?? 0,
      },
    };
  }

  // ─── Permission Checking ───────────────────────────────────────────

  /// Check if current user has permission
  Future<bool> hasPermission(String permission) async {
    final user = await getCurrentUser();
    if (user == null) return false;

    return user.canPerformAction(permission);
  }

  /// Check if current user can manage another user
  Future<bool> canManageUser(String targetUid) async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) return false;

    // Super admins can manage anyone
    if (currentUser.role == UserRole.superAdmin) return true;

    final targetUser = await getUserByUid(targetUid);
    if (targetUser == null) return false;

    // Users cannot manage users with equal or higher privileges
    return currentUser.role.hasPrivilegeOver(targetUser.role) &&
           currentUser.uid != targetUid;
  }

  // ─── Initialization ────────────────────────────────────────────────

  /// Initialize user profile after authentication
  Future<void> initializeUserProfile(User firebaseUser) async {
    final existingUser = await getUserByUid(firebaseUser.uid);

    if (existingUser == null) {
      // Create default user profile
      final appUser = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? firebaseUser.email ?? 'User',
        role: UserRole.viewer, // Default role
        isActive: true,
        createdAt: Timestamp.now(),
      );

      await _db.collection('users').doc(firebaseUser.uid).set(appUser.toJson());
    }

    // Update last login
    await updateLastLogin(firebaseUser.uid);
  }

  /// Check if email already exists
  Future<bool> emailExists(String email) async {
    final snapshot = await _db
        .collection('users')
        .where('email_lowercase', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}
