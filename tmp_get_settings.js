
const admin = require('firebase-admin');
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function getSettings() {
  const doc = await db.collection('app_settings').doc('general').get();
  if (doc.exists) {
    console.log(JSON.stringify(doc.data(), null, 2));
  } else {
    console.log('No settings found');
  }
}

getSettings().then(() => process.exit(0)).catch(err => {
  console.error(err);
  process.exit(1);
});
