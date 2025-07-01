import {execSync} from 'child_process';
import https from 'https';

const TRACKER_CANISTER_ID = 'jcmga-jqaaa-aaaao-a4lha-cai';

const sleep = () => new Promise(resolve => setTimeout(resolve, 5000));

let newCanisterIds = new Set();

const push = async () => {
    const principalList = Array.from(newCanisterIds).map(id => `principal \\"${id}\\"`).join('; ');
    console.log(`Pushing ${newCanisterIds.size} new canister IDs`);
    while (true) {
        try {
            execSync(`dfx canister call ${TRACKER_CANISTER_ID} trackMany "(null, vec { ${principalList} })" --ic`, {
                stdio: 'inherit',
            });
            break;
        } catch (err) {
            console.error('Error pushing new canister IDs:', err.message);
            await sleep();
        }
    }
    newCanisterIds.clear();
};
const onNewCanisterFound = async (canisterId) => {
    newCanisterIds.add(canisterId);
    if (newCanisterIds.size === 100) {
        await push();
    }
};

setTimeout(async () => {

    console.log('Loading deleted canister IDs');
    let deletedCanisterIds = new Set();
    try {
        deletedCanisterIds = new Set(execSync('cat deleted_canister_ids.txt', {encoding: 'utf8'}).split('\n').filter(x => !!x));
    } catch (err) {
        console.error('Error loading deleted canister IDs:', err.message);
    }
    console.log(deletedCanisterIds.size, 'deleted canister IDs found');

    let registeredCanisterIds = new Set();
    console.log('Loading canister IDs from history tracker canister');
    let skip = 0;
    let LIMIT = 1000;
    while (true) {
        console.log('Fetching batch with offset:', skip);
        try {
            const response = execSync(`dfx canister call ${TRACKER_CANISTER_ID} tracked_canisters "(${LIMIT} : nat, ${skip} : nat)" --ic`, {
                encoding: 'utf8',
            });
            let principals = Array.from(response.matchAll(/"([^"]+)"/g), m => m[1]);
            if (principals.length === 0) {
                console.log('No more results.');
                break;
            }
            for (const p of principals) {
                registeredCanisterIds.add(p);
            }
            skip += LIMIT;
        } catch (err) {
            console.error('Error calling canister:', err.message);
            await sleep();
        }
    }
    console.log(registeredCanisterIds.size, 'registered canister IDs found');

    console.log('Syncing IC canister ids...');
    LIMIT = 100;
    skip = 0;
    const API_BASE_URL = 'https://ic-api.internetcomputer.org/api/v3/canisters';

    const fetchCanisters = (limit, offset) => {
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
    };

    while (true) {
        try {
            console.log('Fetching batch with offset:', skip);
            const response = await fetchCanisters(LIMIT, skip);
            if (!response.data || !Array.isArray(response.data)) {
                console.error('Unexpected API response format');
                await sleep();
                continue;
            }
            const batch = response.data;
            if (batch.length === 0) {
                break;
            }
            const principals = batch.map(item => item.canister_id)
                .filter(a => !!a && !deletedCanisterIds.has(a) && !registeredCanisterIds.has(a));
            if (principals.length > 0) {
                console.log(`Found ${principals.length} new canisters`);
                for (const p of principals) {
                    await onNewCanisterFound(p);
                }
            }
            skip += batch.length;
        } catch (err) {
            console.error('Error:', err.message);
            await sleep();
        }
    }
    if (newCanisterIds.size > 0) {
        await push();
    }
});