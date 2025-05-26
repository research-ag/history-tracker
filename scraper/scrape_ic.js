#!/usr/bin/env node
import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const API_BASE_URL = 'https://ic-api.internetcomputer.org/api/v3/canisters';
const OUTPUT_FILE = path.join(__dirname, 'canister_ids.txt');
const BATCH_SIZE = 100;

const args = process.argv.slice(2);
let skip = 0;

if (args.length > 0) {
  const skipArg = parseInt(args[0]);
  if (!isNaN(skipArg) && skipArg >= 0) {
    skip = skipArg;
    console.log(`Starting from skip value: ${skip}`);
  } else {
    console.error('Invalid skip value. Using default: 0');
  }
}

function fetchCanisters(limit, offset) {
  return new Promise((resolve, reject) => {
    const url = `${API_BASE_URL}?limit=${limit}&offset=${offset}`;

    https.get(url, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          const parsedData = JSON.parse(data);
          resolve(parsedData);
        } catch (e) {
          reject(new Error(`Failed to parse API response: ${e.message}`));
        }
      });
    }).on('error', (err) => {
      reject(new Error(`API request failed: ${err.message}`));
    });
  });
}

async function scrapeCanisterIds() {
  let hasMore = true;
  let currentSkip = skip;
  let canisterIds = [];

  if (currentSkip === 0) {
    fs.writeFileSync(OUTPUT_FILE, '');
    console.log(`Created empty file: ${OUTPUT_FILE}`);
  }
  console.log('Starting to scrape canister IDs...');
  while (hasMore) {
    try {
      console.log(`Fetching batch with offset: ${currentSkip}`);
      const response = await fetchCanisters(BATCH_SIZE, currentSkip);
      if (!response.data || !Array.isArray(response.data)) {
        console.error('Unexpected API response format');
        break;
      }
      const batch = response.data;
      if (batch.length === 0) {
        hasMore = false;
        console.log('No more canisters to fetch.');
        break;
      }
      const batchIds = batch.map(item => item.canister_id).filter(Boolean);
      if (batchIds.length > 0) {
        fs.appendFileSync(OUTPUT_FILE, batchIds.join('\n') + '\n');
        canisterIds = canisterIds.concat(batchIds);
      }
      currentSkip += batch.length;
    } catch (error) {
      console.error(`Error occurred: ${error.message}`);
      break;
    }
  }

  console.log(`Scraping completed. Total canister IDs collected: ${canisterIds.length}`);
}

// Run the scraper
scrapeCanisterIds().catch(err => {
  console.error(`Fatal error: ${err.message}`);
  process.exit(1);
});
