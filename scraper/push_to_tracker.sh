#!/bin/bash

# Usage: ./push_to_tracker.sh <skip>
# Reads lines from canister_ids.txt starting at line index <skip> and processes in chunks of 100 lines
# until the end of the file is reached. Outputs the last successfully processed skip value.

SKIP="$1"
LIMIT=100
FILE="new_canister_ids.txt"
TOTAL_LINES=$(wc -l < "$FILE")

if [[ -z "$SKIP" ]]; then
  echo "Usage: $0 <skip>"
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "Error: File $FILE not found"
  exit 1
fi

CURRENT_SKIP=$SKIP
LAST_SUCCESSFUL_SKIP=$SKIP

while true; do
  # Check if we've processed all lines
  if [[ $CURRENT_SKIP -ge $TOTAL_LINES ]]; then
    echo "Reached end of file. Last successful skip: $LAST_SUCCESSFUL_SKIP"
    break
  fi

  # Get the next chunk of lines
  LINES=$(tail -n +"$((CURRENT_SKIP + 1))" "$FILE" | head -n "$LIMIT")

  # If no lines were returned, we've reached the end of the file
  if [[ -z "$LINES" ]]; then
    echo "Reached end of file. Last successful skip: $LAST_SUCCESSFUL_SKIP"
    break
  fi

  # Build the principal list
  PRINCIPAL_LIST=""
  while IFS= read -r line; do
    PRINCIPAL_LIST+="principal \"$line\"; "
  done <<< "$LINES"
  PRINCIPAL_LIST=$(echo "$PRINCIPAL_LIST" | sed 's/; $//')

  # Call the canister
  echo "Processing chunk starting at skip=$CURRENT_SKIP..."
  if dfx canister call history_be_2 trackMany "(null, vec { $PRINCIPAL_LIST })" --ic; then
    LAST_SUCCESSFUL_SKIP=$CURRENT_SKIP
    echo "Successfully processed chunk. Last successful skip: $LAST_SUCCESSFUL_SKIP"
  else
    echo "Error processing chunk starting at skip=$CURRENT_SKIP"
    echo "Last successful skip: $LAST_SUCCESSFUL_SKIP"
    exit 1
  fi

  # Update skip for next iteration
  CURRENT_SKIP=$((CURRENT_SKIP + LIMIT))

done
