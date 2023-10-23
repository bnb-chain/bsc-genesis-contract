#!/usr/bin/env bash

# Default values
OUTPUT1="./contracts/System.sol"
OUTPUT2="./contracts/BC_fusion/System.sol"
HEX_CHAIN_ID="0060"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --hexChainId)
        HEX_CHAIN_ID="$2"
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
sed -i -e "s/uint16 constant public bscChainID = .*;/uint16 constant public bscChainID = 0x${HEX_CHAIN_ID};/g" "$OUTPUT1"
sed -i -e "s/uint16 public constant bscChainID = .*;/uint16 constant public bscChainID = 0x${HEX_CHAIN_ID};/g" "$OUTPUT2"

echo "System file updated."
