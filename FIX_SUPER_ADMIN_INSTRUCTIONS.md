# Fix Super Admin User Document - Instructions

## Problem
You're getting "permission-denied" errors because your Firebase Auth user exists, but the Firestore user document is missing or incomplete.

## Solution: Create User Document via Firebase Console

### Step 1: Get Your User UID

1. Go to Firebase Console: https://console.firebase.google.com/project/cold-storage-inventory/authentication/users
2. Find the user with email `admin@coldapp.com`
3. Click on the user to see details
4. **Copy the User UID** (it looks like: `abc123xyz456...`)

### Step 2: Create the User Document

1. Go to Firestore Database: https://console.firebase.google.com/project/cold-storage-inventory/firestore
2. Navigate to the `users` collection (or create it if it doesn't exist)
3. Click "Add document"
4. Set **Document ID** to the UID you copied in Step 1
5. Add the following fields:

| Field Name | Type | Value |
|------------|------|-------|
| `uid` | string | [Your UID from Step 1] |
| `email` | string | `admin@coldapp.com` |
| `email_lowercase` | string | `admin@coldapp.com` |
| `displayName` | string | `Siddharth Shah` (or your name) |
| `role` | string | `super_admin` |
| `isActive` | boolean | `true` |
| `createdAt` | timestamp | [Click "insert current time"] |
| `updatedAt` | timestamp | [Click "insert current time"] |
| `lastLoginAt` | timestamp | [Click "insert current time"] |
| `phoneNumber` | null | `null` |
| `createdBy` | string | [Your UID from Step 1] |

6. Click "Save"

### Step 3: Verify

1. Log out from your Cold Storage app
2. Log back in as "Admin" or "admin"
3. Try accessing "Rent Rate Master" - it should work now!

---

## Alternative: Quick Fix Script (If Firebase CLI is authenticated)

If you prefer using a script and Firebase CLI is properly authenticated:

```bash
# Install firebase-admin if not already installed
cd functions
npm install

# Run the fix script
cd ..
node functions/fix_super_admin.js
```

---

## Credentials Reference

- **Username**: `Admin` or `admin`
- **Email**: `admin@coldapp.com`
- **Password**: `Admin123` (default, change if different)

---

## What This Fixes

The Firestore security rules check if a user has:
- `role` field set to `super_admin`, `admin`, or `manager`
- `isActive` field set to `true`

Without these fields in your Firestore user document, ALL Firestore operations will fail with "permission-denied" errors.

---

## Need Help?

If you still get errors after following these steps:

1. Check that the Firestore rules were deployed:
   ```bash
   firebase deploy --only firestore:rules
   ```

2. Verify the user document exists:
   - Go to Firestore console
   - Navigate to `users` collection
   - Find your UID
   - Verify all required fields are present

3. Check browser console for additional error messages

4. Try logging out completely and logging back in
