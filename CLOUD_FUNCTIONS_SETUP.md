# Cloud Functions Setup Guide

This guide explains how to set up and deploy Firebase Cloud Functions for the Cold Storage Management App.

## Overview

The app uses Firebase Cloud Functions to handle operations that require Firebase Admin SDK privileges, such as:
- **deleteUser**: Deletes a user from both Firebase Auth and Firestore
- **updateUserEmail**: Updates a user's email in both Auth and Firestore

## Prerequisites

1. **Node.js**: Install Node.js 18 or later
   - Download from: https://nodejs.org/
   - Verify installation: `node --version` (should be 18.x or higher)

2. **Firebase CLI**: Install Firebase CLI globally
   ```bash
   npm install -g firebase-tools
   ```

3. **Firebase Project**: You must have a Firebase project set up
   - Project ID: `cold-storage-inventory`

## Initial Setup

### 1. Install Cloud Functions Dependencies

Navigate to the functions directory and install dependencies:

```bash
cd functions
npm install
cd ..
```

### 2. Login to Firebase

Login to Firebase using the CLI:

```bash
firebase login
```

This will open a browser window for authentication.

### 3. Verify Project Configuration

Make sure you're connected to the correct Firebase project:

```bash
firebase use cold-storage-inventory
```

If the project isn't set up, add it:

```bash
firebase use --add
# Select your project from the list
# Enter "cold-storage-inventory" as the alias
```

## Deployment

### Deploy All Functions

To deploy all Cloud Functions to production:

```bash
firebase deploy --only functions
```

### Deploy a Specific Function

To deploy only one function:

```bash
firebase deploy --only functions:deleteUser
firebase deploy --only functions:updateUserEmail
```

### First-Time Deployment

On first deployment, you may be prompted to:
1. Enable Cloud Functions API for your project (accept)
2. Grant necessary IAM permissions (accept)
3. Choose a region (select the closest to your users)

## Local Testing with Emulators

### 1. Start the Firebase Emulators

To test Cloud Functions locally without deploying:

```bash
firebase emulators:start
```

This starts:
- Functions Emulator on port 5001
- Auth Emulator on port 9099
- Firestore Emulator on port 8080
- Emulator UI on port 4000

### 2. Configure Flutter App for Emulators

When testing locally, you need to point your Flutter app to use the emulators.

Add this code in your `main.dart` after `Firebase.initializeApp()`:

```dart
// For local testing only - comment out in production
Future<void> _connectToEmulators() async {
  if (kDebugMode) {
    // Use localhost for emulators
    const host = 'localhost';

    // Connect to Functions emulator
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);

    // Connect to Auth emulator
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);

    // Connect to Firestore emulator
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  }
}
```

### 3. Test in the Emulator UI

Open http://localhost:4000 to:
- View function logs
- Inspect Firestore data
- View Auth users
- Trigger functions manually

## Function Details

### deleteUser Function

**Purpose**: Deletes a user from both Firebase Auth and Firestore

**Security**:
- Only callable by authenticated users
- Only super admins can delete users
- Users cannot delete their own account
- Validates user exists before deletion

**Parameters**:
```javascript
{
  uid: "user-uid-to-delete"
}
```

**Returns**:
```javascript
{
  success: true,
  message: "User {uid} deleted successfully from both Auth and Firestore."
}
```

**Errors**:
- `unauthenticated`: User not logged in
- `permission-denied`: User is not a super admin
- `invalid-argument`: Missing or invalid UID
- `internal`: Server error

### updateUserEmail Function

**Purpose**: Updates a user's email in both Firebase Auth and Firestore

**Security**:
- Only callable by authenticated users
- Only super admins can update other users' emails
- Users can update their own email

**Parameters**:
```javascript
{
  uid: "user-uid",
  newEmail: "new-email@example.com"
}
```

**Returns**:
```javascript
{
  success: true,
  message: "Email updated successfully to {newEmail}."
}
```

## Firestore Security Rules

Ensure your Firestore security rules allow the Cloud Functions to access user data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      // Allow read if authenticated
      allow read: if request.auth != null;

      // Allow write only from Cloud Functions or super admins
      allow write: if request.auth != null && (
        // Allow Cloud Functions (has custom claims)
        request.auth.token.admin == true ||
        // Allow super admins
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'super_admin'
      );
    }
  }
}
```

## Monitoring and Logs

### View Function Logs

To view logs from deployed functions:

```bash
firebase functions:log
```

To follow logs in real-time:

```bash
firebase functions:log --follow
```

### View Logs in Firebase Console

1. Go to https://console.firebase.google.com/
2. Select your project
3. Navigate to "Functions" in the left sidebar
4. Click on a function to view its logs and metrics

## Troubleshooting

### Error: "Cloud Functions deployment requires billing account"

Cloud Functions require the Blaze (pay-as-you-go) plan. The free tier includes:
- 2M invocations/month
- 400,000 GB-seconds/month
- 200,000 CPU-seconds/month
- 5GB egress/month

To upgrade:
1. Go to Firebase Console
2. Select your project
3. Click "Upgrade" in the bottom left
4. Choose the Blaze plan

### Error: "CORS policy blocking function calls"

If you get CORS errors on web, ensure your function handles CORS:

The current implementation uses `firebase-functions` v5 which handles CORS automatically for `onCall` functions.

### Error: "Permission denied calling function"

Check:
1. User is authenticated
2. User has super admin role in Firestore
3. Firestore security rules allow access
4. Function is deployed (not just in emulator)

### Functions not updating after deployment

Sometimes cached versions persist. Force update:

```bash
firebase deploy --only functions --force
```

## Cost Considerations

### Free Tier Limits

The Spark (free) plan includes:
- **NOT AVAILABLE** - Cloud Functions require Blaze plan

The Blaze (pay-as-you-go) plan includes generous free tier:
- 2M invocations per month FREE
- Beyond free tier: $0.40 per million invocations

### Typical Costs for This App

With moderate usage (100 users, 10 deletions/month):
- Monthly invocations: ~100
- Estimated cost: $0.00 (within free tier)

## Best Practices

1. **Error Handling**: Always use try-catch blocks when calling functions from Flutter
2. **Timeout Handling**: Set appropriate timeouts for function calls
3. **Retry Logic**: Implement retry logic for transient failures
4. **Logging**: Use console.log() in functions for debugging
5. **Testing**: Test in emulator before deploying to production
6. **Monitoring**: Regularly check function logs for errors

## Next Steps

After deployment:

1. Test user deletion in your app
2. Verify users are deleted from both Auth and Firestore
3. Check function logs for any errors
4. Monitor function usage in Firebase Console
5. Set up alerts for function errors (optional)

## Additional Resources

- [Firebase Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Cloud Functions Pricing](https://firebase.google.com/pricing)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
- [Cloud Functions Best Practices](https://firebase.google.com/docs/functions/best-practices)
