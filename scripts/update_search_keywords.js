const admin = require('firebase-admin');

// Initialize Firebase Admin (Update with your project ID)
admin.initializeApp({
  projectId: 'bong-bazar-3659f'
});

const db = admin.firestore();

// Function to generate keywords (must match the logic in ProductProvider)
function generateSearchKeywords(name) {
  const keywords = new Set();
  const lowerName = name.toLowerCase();
  
  keywords.add(lowerName);
  
  const words = lowerName.split(/[\s\-_,.]+/).filter(w => w.length > 0);
  
  for (const word of words) {
    keywords.add(word);
    for (let i = 1; i <= word.length; i++) {
      keywords.add(word.substring(0, i));
    }
  }
  
  return Array.from(keywords);
}

async function updateAllProducts() {
  console.log('Fetching all products...');
  const snapshot = await db.collection('products').get();
  
  console.log(`Found ${snapshot.size} products. Updating...`);
  
  const batch = db.batch();
  let count = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const name = data.name || '';
    const keywords = generateSearchKeywords(name);
    
    batch.update(doc.ref, { searchKeywords: keywords });
    count++;
    
    // Commit in batches of 500 (Firestore limit)
    if (count % 500 === 0) {
      await batch.commit();
      console.log(`Committed ${count} updates...`);
    }
  }

  if (count % 500 !== 0) {
    await batch.commit();
  }

  console.log(`Successfully updated ${count} products with search keywords!`);
}

updateAllProducts().catch(console.error);
