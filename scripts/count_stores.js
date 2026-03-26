const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // This might not exist, but let's try to find it or initialize differently

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function countAdminStores() {
  // 1. Physical Stores
  const physicalStores = await db.collection('stores').get();
  console.log(`Physical Stores (Warehouses/Admin Stores): ${physicalStores.size}`);

  // 2. Admin Seller Accounts
  const adminUsers = await db.collection('users')
    .where('role', 'in', ['admin', 'administrator'])
    .get();
  
  let adminSellerCount = 0;
  adminUsers.forEach(doc => {
    if (doc.data().isSeller === true || doc.data().businessName) {
      adminSellerCount++;
    }
  });

  console.log(`Admin Users with Seller capabilities: ${adminSellerCount}`);
  
  // 3. Total Sellers
  const allSellers = await db.collection('users')
    .where('role', '==', 'seller')
    .get();
  console.log(`Private Sellers: ${allSellers.size}`);
}

countAdminStores().catch(err => console.error(err));
