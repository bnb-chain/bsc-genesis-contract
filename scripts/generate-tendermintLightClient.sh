#!/usr/bin/env bash

# Default values
OUTPUT="./contracts/TendermintLightClient.sol"
NETWORK=""
INIT_CONSENSUS_STATE_BYTES="696e616e63652d436861696e2d4e696c650000000000000000000000000000000000000000000229eca254b3859bffefaf85f4c95da9fbd26527766b784272789c30ec56b380b6eb96442aaab207bc59978ba3dd477690f5c5872334fc39e627723daa97e441e88ba4515150ec3182bc82593df36f8abb25a619187fcfab7e552b94e64ed2deed000000e8d4a51000"
REWARD_FOR_VALIDATOR_SET_CHANGE="1e16"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --network)
        NETWORK="$2"
        shift
        ;;
    --initConsensusStateBytes)
        INIT_CONSENSUS_STATE_BYTES="$2"
        shift
        ;;
    --rewardForValidatorSetChange)
        REWARD_FOR_VALIDATOR_SET_CHANGE="$2"
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
sed -i -e "s/bytes constant public INIT_CONSENSUS_STATE_BYTES = .*;/bytes constant public INIT_CONSENSUS_STATE_BYTES = hex\"${INIT_CONSENSUS_STATE_BYTES}\";/g" "$OUTPUT"
sed -i -e "s/uint256 constant public INIT_REWARD_FOR_VALIDATOR_SER_CHANGE  = .*;/uint256 constant public INIT_REWARD_FOR_VALIDATOR_SER_CHANGE  = ${REWARD_FOR_VALIDATOR_SET_CHANGE};/g" "$OUTPUT"

case $NETWORK in
local)
    sed -i -e "s/alreadyInit = true;/ISystemReward(SYSTEM_REWARD_ADDR).claimRewards(payable(address(this)), 0);\n\t\talreadyInit = true;/g" "$OUTPUT" # just to init SystemReward
    ;;
*)
    ;;
esac

echo "TendermintLightClient file updated."
