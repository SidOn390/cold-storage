# Firestore Security Rules

This document explains the Firestore security rules for the Cold Storage Inventory Management app and how to deploy them.

## Overview

The security rules implement role-based access control (RBAC) with 5 user roles:
1. **Super Admin** - Full system access + user management
2. **Admin** - Full access except user management
3. **Manager** - Create/edit receipts & deliveries
4. **Operator** - Create receipts & deliveries only
5. **Viewer** - Read-only access

## Security Rules File

The security rules are defined in `firestore.rules` at the root of the project.

## Deploying Security Rules

### Option 1: Using Firebase Console (Recommended for First Time)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **cold-storage-inventory**
3. Navigate to **Firestore Database** → **Rules**
4. Copy the entire contents of `firestore.rules`
5. Paste into the Firebase Console rules editor
6. Click **Publish**

### Option 2: Using Firebase CLI

If you have Firebase CLI installed:

```bash
# Install Firebase CLI (if not installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not done)
firebase init firestore

# Deploy the rules
firebase deploy --only firestore:rules
```

## Initial Super Admin Setup

The security rules allow creating the first super admin user with these conditions:

1. The user must be authenticated with Firebase Auth
2. The user is creating their own profile (uid matches)
3. OR the user has role 'super_admin'

### Steps to Create Initial Super Admin:

1. **Deploy the security rules** (see above)
2. **Run your app** on Windows or your preferred device
3. **Click "First Time Setup"** button on the login screen
4. **Click "Create Super Admin User"** button
5. The super admin will be created with:
   - Email: admin@coldstorage.com
   - Password: Admin123
   - Display Name: Siddharth Shah
   - Role: Super Admin

### Troubleshooting

If you get "permission-denied" error when creating the super admin:

**Quick Fix (Temporary):**
1. Go to Firebase Console → Firestore Database → Rules
2. Temporarily use these rules:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if true;
    }
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```
3. Publish the rules
4. Create the super admin user in your app
5. **IMPORTANT:** Replace with the proper rules from `firestore.rules`

## Rule Details

### Users Collection (`/users/{userId}`)

- **Read**: Any authenticated user
- **Create**:
  - User creating their own profile after Firebase Auth registration
  - Super admin creating another user
  - First super admin being created
- **Update**:
  - Super admin can update any user
  - Users can update their own profile (except role and isActive)
- **Delete**: Only super admin

### Master Data Collections

Collections: `cold_storages`, `brands`, `items`, `parties`

- **Read**: Any active authenticated user
- **Write**: Manager, Admin, or Super Admin only

### Transaction Collections

Collections: `receipts`, `deliveries`

- **Read**: Any active authenticated user
- **Create**: Manager, Admin, or Super Admin only
- **Update/Delete**: Manager, Admin, or Super Admin only

### Settings Collection

- **Read**: Any active authenticated user
- **Write**: Super Admin only

### Helper Functions

The rules use several helper functions:

- `isSignedIn()` - Check if user is authenticated
- `getUserData()` - Get current user's Firestore profile
- `isSuperAdmin()` - Check if user is super admin
- `isAdmin()` - Check if user is admin or super admin
- `isManager()` - Check if user has at least manager role
- `isActiveUser()` - Check if user is active
- `noUsersExist()` - Check if this is the first user

## Testing Rules

You can test the rules in the Firebase Console:

1. Go to **Firestore Database** → **Rules** → **Rules Playground**
2. Simulate different scenarios:
   - Authenticated user reading data
   - Super admin creating a user
   - Manager creating a receipt
   - Viewer trying to edit data (should fail)

## Security Best Practices

1. **Never use `allow read, write: if true;` in production** - This allows anyone to access your data
2. **Always validate user roles** before allowing write operations
3. **Use `isActive` flag** to prevent deactivated users from accessing data
4. **Audit user actions** by checking `getUserData()` in rules
5. **Deploy rules before deploying app updates** to prevent security gaps

## Emulator Testing

When using Firebase Emulator for local testing, the rules are automatically loaded from `firestore.rules`.

To start the emulator with rules:

```bash
firebase emulators:start
```

The emulator will:
- Load `firestore.rules` automatically
- Apply the same security rules as production
- Allow you to test without affecting production data

## Common Issues

### Issue 1: "Missing or insufficient permissions"

**Cause**: Security rules are blocking the operation

**Solution**:
1. Check if user is authenticated
2. Verify user has the correct role
3. Ensure user's `isActive` is `true`
4. Check if the operation is allowed by the rules

### Issue 2: "Error updating rules"

**Cause**: Syntax error in `firestore.rules`

**Solution**:
1. Validate the rules syntax in Firebase Console
2. Check for missing semicolons or braces
3. Ensure all helper functions are defined

### Issue 3: "Cannot create first super admin"

**Cause**: Rules not deployed or incorrect

**Solution**:
1. Use the temporary open rules (see "Troubleshooting" above)
2. Create the super admin
3. Deploy proper rules immediately after

## Monitoring

Monitor rule denials in Firebase Console:

1. Go to **Firestore Database** → **Usage**
2. Check for spike in "Denied Reads" or "Denied Writes"
3. Review logs to identify unauthorized access attempts

## Updates

When updating security rules:

1. Test in Firebase Emulator first
2. Deploy to production during low-traffic hours
3. Monitor for increased denials after deployment
4. Have rollback plan ready

## Support

If you encounter issues with security rules:

1. Check Firebase Console logs
2. Use Rules Playground to test specific scenarios
3. Review the helper functions in `firestore.rules`
4. Ensure user profiles have correct `role` and `isActive` values
