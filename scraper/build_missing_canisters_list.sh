#!/bin/bash
sort -u ic_canister_ids.txt > "ic_canister_ids.sorted.txt"
sort -u tracker_canister_ids.txt > "tracker_canister_ids.sorted.txt"
sort -u deleted_canister_ids.txt > "deleted_canister_ids.sorted.txt"
comm -23 "ic_canister_ids.sorted.txt" "tracker_canister_ids.sorted.txt" > new_canister_ids.0.txt
comm -23 "new_canister_ids.0.txt" "deleted_canister_ids.sorted.txt" > new_canister_ids.txt
rm -f "ic_canister_ids.sorted.txt" "tracker_canister_ids.sorted.txt" "deleted_canister_ids.sorted.txt" "new_canister_ids.0.txt"