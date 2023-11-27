#!/usr/bin/env bash

# Default values
OUTPUT="./contracts/BC_fusion/AirDrop.sol"
SOURCE_CHAIN_ID=""
APPROVAL_ADDRESS="0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa"
MERKLE_ROOT="0x0000000000000000000000000000000000000000000000000000000000000000"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --sourceChainId)
        SOURCE_CHAIN_ID="$2"
        shift
        ;;
    --approvalAddress)
        APPROVAL_ADDRESS="$2"
        shift
        ;;
    --merkleRoot)
        MERKLE_ROOT="$2"
        shift
        ;;
    *)
        echo "Unknown parameter passed: $1"
        exit 1
        ;;
    esac
    shift
done

basedir=$(
    cd $(dirname $0)
    pwd
)

# Replace the specific line
sed -i -e "s/string public constant sourceChainID = .*;/string public constant sourceChainID = \"${SOURCE_CHAIN_ID}\";/g" "$OUTPUT"
sed -i -e "s/address public approvalAddress = .*;/address public approvalAddress = ${APPROVAL_ADDRESS};/g" "$OUTPUT"
sed -i -e "s/bytes32 public constant override merkleRoot = .*;/bytes32 public constant override merkleRoot = ${MERKLE_ROOT};/g" "$OUTPUT"

echo "AirDrop file updated."
