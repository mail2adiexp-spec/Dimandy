const fs = require('fs');
const path = require('path');
const osmRead = require('osm-read');

// Input and Output Paths
const pbfPath = 'c:\\Users\\souna\\Downloads\\eastern-zone-260121.osm (1).pbf';
const outputDir = path.join(__dirname, '..', '..', 'assets', 'locations');
const outputFile = path.join(outputDir, 'wb_places.json');

// Ensure output directory exists
if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

console.log(`Starting extraction from: ${pbfPath}`);
console.log(`Output will be saved to: ${outputFile}`);

const places = [];
let count = 0;

osmRead.parse({
    filePath: pbfPath,
    format: 'pbf',
    node: (node) => {
        if (node.tags.place && (node.tags.place === 'city' || node.tags.place === 'town' || node.tags.place === 'village' || node.tags.place === 'suburb')) {
            // Check for State filter
            // Tags for state can vary: 
            // is_in:state, addr:state, or just implied by location (but PBF covers whole Eastern Zone)
            // We'll check multiple common state tags

            const state = node.tags['is_in:state'] || node.tags['addr:state'] || node.tags['state'] || '';
            const isIn = node.tags['is_in'] || '';

            const isWestBengal =
                state.toLowerCase().includes('west bengal') ||
                state.toLowerCase().includes('wb') ||
                isIn.toLowerCase().includes('west bengal');

            // If state tag is missing, we might include it and filter later by lat/lon box, 
            // but for now let's rely on tags + bounding box check as backup?
            // West Bengal Approx Bounding Box: 
            // Lat: 21.5 to 27.3
            // Lon: 85.8 to 89.9

            let passedFilter = isWestBengal;

            // If no state tag, check bounding box as a fallback (rough check)
            if (!passedFilter && !state) {
                if (node.lat >= 21.5 && node.lat <= 27.3 && node.lon >= 85.8 && node.lon <= 89.9) {
                    passedFilter = true;
                }
            }

            if (passedFilter) {
                places.push({
                    name: node.tags.name || node.tags['name:en'] || 'Unknown',
                    lat: node.lat,
                    lng: node.lon,
                    type: node.tags.place,
                    state: 'West Bengal'
                });
                count++;
                if (count % 1000 === 0) {
                    process.stdout.write(`Found ${count} places... \r`);
                }
            }
        }
    },
    error: (msg) => {
        console.error('error: ' + msg);
    },
    endDocument: function () { // Fix for pbfParser issue
        this.end();
    },
    end: () => {
        console.log('\nExtraction complete.');
        console.log(`Total places found: ${places.length}`);

        // Remove duplicates based on name (simple distinct)
        const uniquePlaces = [];
        const seenNames = new Set();

        for (const p of places) {
            const key = `${p.name.toLowerCase()}`;
            if (!seenNames.has(key) && p.name !== 'Unknown') {
                seenNames.add(key);
                uniquePlaces.push(p);
            }
        }

        console.log(`Unique places after filtering: ${uniquePlaces.length}`);

        fs.writeFileSync(outputFile, JSON.stringify(uniquePlaces, null, 2));
        console.log(`Data saved to ${outputFile}`);
    }
});
