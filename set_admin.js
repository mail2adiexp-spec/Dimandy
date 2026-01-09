// Firebase Admin SDK script to set admin claim
// Save this as set_admin.js and run with: node set_admin.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // You need to download this from Firebase Console

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function setAdminClaim(email) {
  try {
    // Get user by email
    const user = await admin.auth().getUserByEmail(email);
    
    // Set custom claim
    await admin.auth().setCustomUserClaims(user.uid, {
      admin: true
    });
    
    console.log(`✅ Successfully set admin claim for: ${email}`);
    console.log(`   User ID: ${user.uid}`);
    console.log('   The user needs to sign out and sign in again for the claim to take effect.');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error setting admin claim:', error.message);
    process.exit(1);
  }
}

// Set the email here
const ADMIN_EMAIL = 'mail2adiexp@gmail.com';
setAdminClaim(ADMIN_EMAIL);
