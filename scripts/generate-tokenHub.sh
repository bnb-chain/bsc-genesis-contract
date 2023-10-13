#!/usr/bin/env bash

# Default values
OUTPUT="./contracts/TokenHub.sol"
INIT_RELAY_FEE="2e15"
REWARD_UPPER_LIMIT="1e18"
MAX_GAS_FOR_CALLING_BEP20="50000"
MAX_GAS_FOR_TRANSFERRING_BNB="10000"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --initRelayFee)
        INIT_RELAY_FEE="$2"
        shift
        ;;
    --rewardUpperLimit)
        REWARD_UPPER_LIMIT="$2"
        shift
        ;;
    --maxGasForCallingBEP20)
        MAX_GAS_FOR_CALLING_BEP20="$2"
        shift
        ;;
    --maxGasForTransferringBNB)
        MAX_GAS_FOR_TRANSFERRING_BNB="$2"
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
sed -i -e "s/uint256 constant public INIT_MINIMUM_RELAY_FEE =.*;/uint256 constant public INIT_MINIMUM_RELAY_FEE = ${INIT_RELAY_FEE};/g" "$OUTPUT"
sed -i -e "s/uint256 constant public REWARD_UPPER_LIMIT =.*;/uint256 constant public REWARD_UPPER_LIMIT = ${REWARD_UPPER_LIMIT};/g" "$OUTPUT"
sed -i -e "s/uint256 constant public MAX_GAS_FOR_CALLING_BEP20=.*;/uint256 constant public MAX_GAS_FOR_CALLING_BEP20 = ${MAX_GAS_FOR_CALLING_BEP20};/g" "$OUTPUT"
sed -i -e "s/uint256 constant public MAX_GAS_FOR_TRANSFER_BNB=.*;/uint256 constant public MAX_GAS_FOR_TRANSFER_BNB = ${MAX_GAS_FOR_TRANSFER_BNB};/g" "$OUTPUT"

echo "TokenHub file updated."
