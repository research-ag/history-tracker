#!/bin/sh
LIMIT=1000
SKIP="$1"
OUTPUT="tracker_canister_ids.txt"

if [[ -z "$SKIP" ]]; then
  echo "Usage: $0 <skip>"
  exit 1
fi

while true; do
  echo "Fetching from $SKIP..."
  RESPONSE=$(dfx canister call history_be_2 tracked_canisters "($LIMIT : nat, $SKIP : nat)" --ic)
  PRINCIPALS=$(echo "$RESPONSE" | grep -oE '"[^"]+"' | sed 's/"//g')
  if [ -z "$PRINCIPALS" ]; then
    echo "No more results."
    break
  fi
  echo "$PRINCIPALS" >> "$OUTPUT"
  SKIP=$((SKIP + LIMIT))
done

echo "Done."
