/**
 * Cloud Functions for Cold Storage Management App (v2 API)
 *
 * These functions handle operations that require Firebase Admin SDK,
 * such as deleting users from Firebase Authentication.
 */

const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');

// Initialize Firebase Admin
initializeApp();

/**
 * Callable Cloud Function to delete a user from Firebase Auth
 *
 * This function can only be called by authenticated super admins.
 * It deletes the user from both Firebase Auth and Firestore.
 */
exports.deleteUser = onCall(async (request) => {
  // Check if the request is made by an authenticated user
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'User must be authenticated to delete users.'
    );
  }

  const callerId = request.auth.uid;
  const targetUid = request.data.uid;

  if (!targetUid) {
    throw new HttpsError(
      'invalid-argument',
      'User UID is required.'
    );
  }

  try {
    // Get caller's user document to check if they're a super admin
    const db = getFirestore();
    const callerDoc = await db.collection('users').doc(callerId).get();

    if (!callerDoc.exists) {
      throw new HttpsError(
        'permission-denied',
        'Caller user profile not found.'
      );
    }

    const callerData = callerDoc.data();

    // Check if caller is a super admin
    if (callerData.role !== 'super_admin') {
      throw new HttpsError(
        'permission-denied',
        'Only super admins can delete users.'
      );
    }

    // Prevent users from deleting themselves
    if (callerId === targetUid) {
      throw new HttpsError(
        'invalid-argument',
        'Users cannot delete their own account.'
      );
    }

    const auth = getAuth();

    // Delete from Firebase Auth
    await auth.deleteUser(targetUid);

    // Delete from Firestore
    await db.collection('users').doc(targetUid).delete();

    return {
      success: true,
      message: `User ${targetUid} deleted successfully from both Auth and Firestore.`
    };

  } catch (error) {
    console.error('Error deleting user:', error);

    // If it's already an HttpsError, rethrow it
    if (error instanceof HttpsError) {
      throw error;
    }

    // Handle specific Firebase Auth errors
    if (error.code === 'auth/user-not-found') {
      // User doesn't exist in Auth, just delete from Firestore
      const db = getFirestore();
      await db.collection('users').doc(targetUid).delete();

      return {
        success: true,
        message: `User ${targetUid} deleted from Firestore (not found in Auth).`
      };
    }

    // Other errors
    throw new HttpsError(
      'internal',
      `Failed to delete user: ${error.message}`
    );
  }
});

/**
 * Callable Cloud Function to update a user's email
 */
exports.updateUserEmail = onCall(async (request) => {
  // Check if the request is made by an authenticated user
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'User must be authenticated.'
    );
  }

  const callerId = request.auth.uid;
  const {uid, newEmail} = request.data;

  if (!uid || !newEmail) {
    throw new HttpsError(
      'invalid-argument',
      'Both uid and newEmail are required.'
    );
  }

  try {
    const db = getFirestore();

    // Get caller's user document to check permissions
    const callerDoc = await db.collection('users').doc(callerId).get();

    if (!callerDoc.exists) {
      throw new HttpsError(
        'permission-denied',
        'Caller user profile not found.'
      );
    }

    const callerData = callerDoc.data();

    // Only super admins can update other users' emails
    if (callerData.role !== 'super_admin' && callerId !== uid) {
      throw new HttpsError(
        'permission-denied',
        'Only super admins can update other users\' emails.'
      );
    }

    const auth = getAuth();

    // Update email in Firebase Auth
    await auth.updateUser(uid, {
      email: newEmail
    });

    // Update email in Firestore
    await db.collection('users').doc(uid).update({
      email: newEmail,
      email_lowercase: newEmail.toLowerCase()
    });

    return {
      success: true,
      message: `Email updated successfully to ${newEmail}.`
    };

  } catch (error) {
    console.error('Error updating user email:', error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      'internal',
      `Failed to update email: ${error.message}`
    );
  }
});
