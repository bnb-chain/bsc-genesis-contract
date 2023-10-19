#!/usr/bin/env bash

# Default values
OUTPUT="./contracts/System.sol"
BSC_CHAIN_ID="0060"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --bscChainId)
        BSC_CHAIN_ID="$2"
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
sed -i -e "s/uint16 constant public bscChainID = .*;/uint16 constant public bscChainID = 0x${BSC_CHAIN_ID};/g" "$OUTPUT"

echo "System file updated."
