#!/usr/bin/env bash

# Default values
OUTPUT="./contracts/SystemReward.sol"
NETWORK=""

ADD_OPERATOR_VALIDATORSET="operators[INCENTIVIZE_ADDR] = true;\n      operators[VALIDATOR_CONTRACT_ADDR] = true;"
ADD_OPERATOR_SLASH_INDICATOR="operators[INCENTIVIZE_ADDR] = true;\n      operators[SLASH_CONTRACT_ADDR] = true;"

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
    sed -i -e "s/operators\[INCENTIVIZE_ADDR\] = true;/${ADD_OPERATOR_SLASH_INDICATOR}/" "$OUTPUT"
    sed -i -e "s/operators\[INCENTIVIZE_ADDR\] = true;/${ADD_OPERATOR_VALIDATORSET}/g" "$OUTPUT"
    sed -i -e "s/numOperator = 2/numOperator = 4/g" "$OUTPUT"
    ;;
*) ;;
esac

echo "SystemReward file updated."
