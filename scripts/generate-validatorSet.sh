#!/usr/bin/env bash

# Default values
OUTPUT="./contracts/BSCValidatorSet.sol"
INIT_BURN_RATIO="0"
INIT_VALIDATORSET_BYTES=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --initBurnRatio)
        INIT_BURN_RATIO="$2"
        shift
        ;;
    --initValidatorSetBytes)
        INIT_VALIDATORSET_BYTES="$2"
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

if [ "$INIT_VALIDATORSET_BYTES" = "" ]; then
    INIT_VALIDATORSET_BYTES=$(node ${basedir}/validators.js)
    INIT_VALIDATORSET_BYTES="${INIT_VALIDATORSET_BYTES:2}"
fi

# Replace the specific line
sed -i -e "s/uint256 public constant INIT_BURN_RATIO = .*;/uint256 public constant INIT_BURN_RATIO = ${INIT_BURN_RATIO};/g" "$OUTPUT"
sed -i -e "s/bytes public constant INIT_VALIDATORSET_BYTES = .*;/bytes public constant INIT_VALIDATORSET_BYTES = hex\"${INIT_VALIDATORSET_BYTES}\";/g" "$OUTPUT"

echo "BSCValidatorSet file updated."
