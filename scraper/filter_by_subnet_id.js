#!/usr/bin/env node

import fs from 'fs';
import process from 'node:process';

if (process.argv.length !== 3) {
    console.error('Usage: node filter_by_subnet_id.js <subnet_id>');
    process.exit(1);
}

const targetSubnetId = process.argv[2];
console.log(`Filtering canisters for subnet ID: ${targetSubnetId}`);

const canisterIdsPath = 'canister_ids.txt';
const subnetIdsPath = 'subnet_ids.txt';
const outputPath = `subnet_canister_ids_${targetSubnetId}.txt`;

async function filterCanistersBySubnet() {
    try {
        const canisterIds = fs.readFileSync(canisterIdsPath, 'utf8').split('\n');
        const subnetIds = fs.readFileSync(subnetIdsPath, 'utf8').split('\n');
        const filteredCanisterIds = [];
        for (let i = 0; i < Math.min(canisterIds.length, subnetIds.length); i++) {
            if (subnetIds[i] === targetSubnetId) {
                filteredCanisterIds.push(canisterIds[i]);
                if (filteredCanisterIds.length >= 1000) {
                    break;
                }
            }
        }
        fs.writeFileSync(outputPath, filteredCanisterIds.join('\n'));
        console.log(`Found ${filteredCanisterIds.length} canisters for subnet ID ${targetSubnetId}`);
        console.log(`Results written to ${outputPath}`);
    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
}

// Run the filter function
filterCanistersBySubnet();
