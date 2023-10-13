#!/usr/bin/env bash

# Default values
OUTPUT="./contracts/SlashIndicator.sol"
NETWORK=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --network)
        NETWORK="$2"
        shift
        ;;
    *)
        echo "Unknown parameter passed: $1"
        exit 1
        ;;
    esac
    shift
done

# Replace the specific line
case $NETWORK in
local)
    sed -i -e "s/alreadyInit = true;/enableMaliciousVoteSlash = true;\nalreadyInit = true;/g" "$OUTPUT"
    ;;
*)
    ;;
esac

echo "SlashIndicator file updated."
