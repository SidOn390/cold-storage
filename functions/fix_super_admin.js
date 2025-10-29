// scripts/fix_super_admin.js
//
// This script fixes or creates the Firestore user document for the super admin.
// Run this if you're getting "permission-denied" errors when accessing collections.
//
// Prerequisites:
//   npm install firebase-admin
//
// Usage:
//   node scripts/fix_super_admin.js
//
// Or set custom Firebase project:
//   FIREBASE_PROJECT_ID=cold-storage-inventory node scripts/fix_super_admin.js

const admin = require('firebase-admin');
const readline = require('readline');

// Initialize Firebase Admin SDK
const projectId = process.env.FIREBASE_PROJECT_ID || 'cold-storage-inventory';

console.log('=== Super Admin User Document Fix Script ===\n');

// Check if service account key exists
const fs = require('fs');
const serviceAccountPaths = [
  'service-account-key.json',
  'serviceAccountKey.json',
  '../service-account-key.json',
];

let serviceAccountPath = null;
for (const path of serviceAccountPaths) {
  if (fs.existsSync(path)) {
    serviceAccountPath = path;
    break;
  }
}

if (!serviceAccountPath) {
  console.log('⚠️  No service account key found.');
  console.log('This script will use Application Default Credentials.');
  console.log('Make sure you are authenticated with Firebase CLI:');
  console.log('  firebase login\n');

  admin.initializeApp({
    projectId: projectId,
  });
} else {
  console.log(`✅ Using service account key: ${serviceAccountPath}\n`);
  const serviceAccount = require(`./${serviceAccountPath}`);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: projectId,
  });
}

const auth = admin.auth();
const firestore = admin.firestore();

// Super admin credentials (matching create_super_admin_helper.dart)
const EMAIL = 'admin@coldapp.com';
const DISPLAY_NAME = 'Siddharth Shah';
const ROLE = 'super_admin';

async function fixSuperAdminUser() {
  try {
    console.log('Checking for super admin user...');
    console.log(`Email: ${EMAIL}`);
    console.log(`Display Name: ${DISPLAY_NAME}\n`);

    // Get user by email from Firebase Auth
    let userRecord;
    try {
      userRecord = await auth.getUserByEmail(EMAIL);
      console.log(`✅ Firebase Auth user found`);
      console.log(`   UID: ${userRecord.uid}`);
      console.log(`   Email: ${userRecord.email}\n`);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.log('❌ Firebase Auth user not found!');
        console.log('\nThe user needs to be created first.');
        console.log('Options:');
        console.log('1. Create via Firebase Console: Authentication > Users > Add user');
        console.log(`   Email: ${EMAIL}`);
        console.log('   Password: Admin123 (or your choice)');
        console.log('\n2. Or run: dart run lib/utils/create_super_admin_helper.dart');
        process.exit(1);
      }
      throw error;
    }

    const uid = userRecord.uid;

    // Check if Firestore document exists
    const docRef = firestore.collection('users').doc(uid);
    const docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      console.log('✅ User document exists in Firestore');

      const data = docSnapshot.data();
      console.log('\nCurrent document data:');
      console.log(`  - role: ${data.role}`);
      console.log(`  - isActive: ${data.isActive}`);
      console.log(`  - displayName: ${data.displayName}`);
      console.log(`  - email: ${data.email}`);

      // Check if required fields are present and correct
      let needsUpdate = false;
      const updates = {};

      if (data.role !== ROLE) {
        console.log(`\n⚠️  Role is incorrect (${data.role} !== ${ROLE})`);
        updates.role = ROLE;
        needsUpdate = true;
      }

      if (data.isActive !== true) {
        console.log('\n⚠️  isActive is not true');
        updates.isActive = true;
        needsUpdate = true;
      }

      if (data.displayName !== DISPLAY_NAME) {
        console.log('\n⚠️  displayName is incorrect');
        updates.displayName = DISPLAY_NAME;
        needsUpdate = true;
      }

      if (data.email !== EMAIL) {
        console.log('\n⚠️  email is incorrect');
        updates.email = EMAIL;
        needsUpdate = true;
      }

      if (!data.uid) {
        updates.uid = uid;
        needsUpdate = true;
      }

      if (!data.email_lowercase) {
        updates.email_lowercase = EMAIL.toLowerCase();
        needsUpdate = true;
      }

      if (needsUpdate) {
        console.log('\n📝 Updating user document...');
        updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await docRef.update(updates);
        console.log('✅ User document updated successfully!');
      } else {
        console.log('\n✅ All fields are correct. No update needed.');
      }
    } else {
      console.log('⚠️  User document does NOT exist in Firestore');
      console.log('\n📝 Creating user document...');

      await docRef.set({
        uid: uid,
        email: EMAIL,
        email_lowercase: EMAIL.toLowerCase(),
        displayName: DISPLAY_NAME,
        role: ROLE,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
        phoneNumber: null,
        createdBy: uid, // Self-created
      });

      console.log('✅ User document created successfully!');
    }

    console.log('\n=== Summary ===');
    console.log('✅ Super admin user is now properly configured');
    console.log(`✅ Email: ${EMAIL}`);
    console.log(`✅ Role: ${ROLE}`);
    console.log(`✅ UID: ${uid}`);
    console.log('\nYou should now be able to access rent rates and all other collections.');
    console.log('Please log out and log back in to the app to apply changes.');

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    if (error.stack) {
      console.error('\nStack trace:', error.stack);
    }
    process.exit(1);
  }
}

// Run the script
fixSuperAdminUser()
  .then(() => {
    console.log('\n✅ Script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Script failed:', error);
    process.exit(1);
  });
