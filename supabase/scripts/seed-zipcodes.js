// Script to seed US ZIP code data
// Run with: node scripts/seed-zipcodes.js

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Sample ZIP codes - in production, use a full dataset like from census.gov
// Full dataset: https://www.census.gov/geographies/reference-files/time-series/geo/gazetteer-files.html
const sampleZipCodes = [
  { zip_code: '10001', city: 'New York', state_code: 'NY', lat: 40.7484, lon: -73.9967, population: 21102, is_inhabited: true },
  { zip_code: '90210', city: 'Beverly Hills', state_code: 'CA', lat: 34.0901, lon: -118.4065, population: 21741, is_inhabited: true },
  { zip_code: '60601', city: 'Chicago', state_code: 'IL', lat: 41.8819, lon: -87.6278, population: 2714, is_inhabited: true },
  { zip_code: '77001', city: 'Houston', state_code: 'TX', lat: 29.7545, lon: -95.3536, population: 0, is_inhabited: true },
  { zip_code: '85001', city: 'Phoenix', state_code: 'AZ', lat: 33.4484, lon: -112.0740, population: 5061, is_inhabited: true },
  { zip_code: '19101', city: 'Philadelphia', state_code: 'PA', lat: 39.9526, lon: -75.1652, population: 0, is_inhabited: true },
  { zip_code: '78201', city: 'San Antonio', state_code: 'TX', lat: 29.4693, lon: -98.5254, population: 29959, is_inhabited: true },
  { zip_code: '92101', city: 'San Diego', state_code: 'CA', lat: 32.7197, lon: -117.1628, population: 34386, is_inhabited: true },
  { zip_code: '75201', city: 'Dallas', state_code: 'TX', lat: 32.7887, lon: -96.7988, population: 8342, is_inhabited: true },
  { zip_code: '95101', city: 'San Jose', state_code: 'CA', lat: 37.3382, lon: -121.8863, population: 0, is_inhabited: true },
  // Add more ZIP codes as needed...
];

async function seedZipCodes() {
  console.log('Seeding ZIP codes...');

  // Check if we have a CSV file with full data
  const csvPath = path.join(__dirname, 'us-zip-codes.csv');

  let zipCodes = sampleZipCodes;

  if (fs.existsSync(csvPath)) {
    console.log('Found ZIP codes CSV file, loading...');
    const csvData = fs.readFileSync(csvPath, 'utf-8');
    const lines = csvData.split('\n').slice(1); // Skip header

    zipCodes = lines
      .filter(line => line.trim())
      .map(line => {
        const [zip_code, city, state_code, lat, lon, population] = line.split(',');
        return {
          zip_code: zip_code.trim(),
          city: city.trim(),
          state_code: state_code.trim(),
          lat: parseFloat(lat),
          lon: parseFloat(lon),
          population: parseInt(population) || 0,
          is_inhabited: parseInt(population) > 0
        };
      });
  }

  // Insert in batches of 1000
  const batchSize = 1000;
  for (let i = 0; i < zipCodes.length; i += batchSize) {
    const batch = zipCodes.slice(i, i + batchSize);

    const { error } = await supabase
      .from('zip_codes')
      .upsert(batch, { onConflict: 'zip_code' });

    if (error) {
      console.error(`Error inserting batch ${i / batchSize + 1}:`, error);
    } else {
      console.log(`Inserted batch ${i / batchSize + 1} (${batch.length} records)`);
    }
  }

  console.log(`Seeded ${zipCodes.length} ZIP codes`);
}

seedZipCodes()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err);
    process.exit(1);
  });
