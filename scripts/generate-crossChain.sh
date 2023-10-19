#!/usr/bin/env bash

# Default values
OUTPUT="./contracts/CrossChain.sol"
BSC_CHAIN_ID="0060"
INIT_BATCH_SIZE_FOR_ORACLE="50"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --bscChainId)
        BSC_CHAIN_ID="$2"
        shift
        ;;
    --initBatchSizeForOracle)
        INIT_BATCH_SIZE_FOR_ORACLE="$2"
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
sed -i -e "s/uint256 constant public CROSS_CHAIN_KEY_PREFIX = .*;/uint256 constant public CROSS_CHAIN_KEY_PREFIX = 0x01${BSC_CHAIN_ID}00;/g" "$OUTPUT"
sed -i -e "s/uint256 constant public INIT_BATCH_SIZE = .*;/uint256 constant public INIT_BATCH_SIZE = ${INIT_BATCH_SIZE_FOR_ORACLE};/g" "$OUTPUT"

echo "CrossChain file updated."
