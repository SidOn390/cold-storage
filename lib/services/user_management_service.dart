// lib/services/user_management_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cold_storage/models/app_user.dart';
import 'package:cold_storage/models/user_role.dart';
import 'package:cold_storage/firebase_options.dart';

class UserManagementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Secondary Firebase app for creating users without affecting current session
  FirebaseApp? _secondaryApp;
  FirebaseAuth? _secondaryAuth;

  // ─── Secondary App Initialization ──────────────────────────────────

  /// Initialize secondary Firebase app for user creation
  Future<void> _initializeSecondaryApp() async {
    if (_secondaryApp != null && _secondaryAuth != null) return;

    try {
      _secondaryApp = await Firebase.initializeApp(
        name: 'UserManagementSecondary',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _secondaryAuth = FirebaseAuth.instanceFor(app: _secondaryApp!);

      // Set persistence to NONE to prevent storage conflicts with primary app
      // This is crucial on web to avoid session interference
      await _secondaryAuth!.setPersistence(Persistence.NONE);
    } catch (e) {
      // App might already exist
      try {
        _secondaryApp = Firebase.app('UserManagementSecondary');
        _secondaryAuth = FirebaseAuth.instanceFor(app: _secondaryApp!);

        // Ensure persistence is set to NONE
        await _secondaryAuth!.setPersistence(Persistence.NONE);
      } catch (e) {
        rethrow;
      }
    }
  }

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
  ///
  /// Uses a secondary Firebase app to create users without affecting the current admin session.
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phoneNumber,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Must be logged in to create users');
    }

    final createdByUid = currentUser.uid;
    final adminEmail = currentUser.email;

    try {
      // Initialize secondary app for user creation
      await _initializeSecondaryApp();

      if (_secondaryAuth == null) {
        throw Exception('Failed to initialize secondary authentication');
      }

      // Create Firebase Auth user using secondary app
      final userCredential = await _secondaryAuth!.createUserWithEmailAndPassword(
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
        createdBy: createdByUid,
        createdAt: Timestamp.now(),
      );

      await _db.collection('users').doc(newUser.uid).set(appUser.toJson());

      // Sign out the newly created user from secondary app only
      await _secondaryAuth!.signOut();

      // Verify admin is still logged in
      final stillLoggedIn = _auth.currentUser != null;
      if (!stillLoggedIn) {
        throw Exception('Admin session was lost. Please log in again.');
      }

      return appUser;
    } catch (e) {
      // If admin was signed out, provide helpful error message
      if (_auth.currentUser == null && adminEmail != null) {
        throw Exception('Admin session ended. This can happen on web browsers. Please log back in as $adminEmail');
      }
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
  ///
  /// Smart deletion that works with or without Cloud Functions:
  /// - If Cloud Functions deployed: Deletes from both Auth and Firestore
  /// - If Cloud Functions not deployed: Deletes from Firestore only
  ///
  /// Returns a map with:
  /// - 'success': bool - whether operation succeeded
  /// - 'fullDeletion': bool - whether deleted from both Auth and Firestore
  /// - 'message': String - user-friendly message
  Future<Map<String, dynamic>> deleteUser(String uid) async {
    try {
      // Try Cloud Function first (best option - deletes from both)
      final callable = _functions.httpsCallable('deleteUser');
      final result = await callable.call({'uid': uid});

      if (result.data['success'] == true) {
        return {
          'success': true,
          'fullDeletion': true,
          'message': 'User deleted successfully from both Authentication and Database.',
        };
      } else {
        throw Exception(result.data['message'] ?? 'Failed to delete user');
      }
    } on FirebaseFunctionsException catch (e) {
      // Handle specific Cloud Functions errors
      if (e.code == 'not-found' || e.message?.contains('not find function') == true) {
        // Cloud Function not deployed - fall back to Firestore-only deletion
        return await _fallbackDeleteUser(uid);
      }

      switch (e.code) {
        case 'unauthenticated':
          throw Exception('You must be logged in to delete users.');
        case 'permission-denied':
          throw Exception('Only super admins can delete users.');
        case 'invalid-argument':
          throw Exception(e.message ?? 'Invalid user ID provided.');
        default:
          // For other errors, try fallback deletion
          return await _fallbackDeleteUser(uid);
      }
    } catch (e) {
      // If Cloud Function fails for any reason, try fallback
      if (e.toString().contains('not find function') ||
          e.toString().contains('PERMISSION_DENIED') ||
          e.toString().contains('UNAVAILABLE')) {
        return await _fallbackDeleteUser(uid);
      }
      throw Exception('Failed to delete user: $e');
    }
  }

  /// Fallback deletion when Cloud Functions are not available
  /// Deletes from Firestore only and returns partial success
  Future<Map<String, dynamic>> _fallbackDeleteUser(String uid) async {
    try {
      // Delete from Firestore only
      await _db.collection('users').doc(uid).delete();

      return {
        'success': true,
        'fullDeletion': false,
        'message': 'User deleted from app database.\n\n'
            '⚠️ Note: User still exists in Firebase Authentication.\n\n'
            'To fully delete the user:\n'
            '1. Deploy Cloud Functions, OR\n'
            '2. Manually delete from Firebase Console:\n'
            '   Authentication → Users → Delete user\n\n'
            'The user cannot access the app anymore, but can still '
            'log in with their credentials until removed from Authentication.',
      };
    } catch (e) {
      throw Exception('Failed to delete user from database: $e');
    }
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
