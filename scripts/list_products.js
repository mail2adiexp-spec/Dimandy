const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // This might not exist, but let's try to find it or initialize differently

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function listProducts() {
  const snapshot = await db.collection('products').get();
  snapshot.forEach(doc => {
    console.log(`ID: ${doc.id}, Name: ${doc.data().name}, Price: ${doc.data().price}, SellerID: ${doc.data().sellerId}`);
  });
}

listProducts();
