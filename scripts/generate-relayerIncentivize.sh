#!/usr/bin/env bash

# Default values
OUTPUT="./contracts/RelayerIncentivize.sol"
ROUND_SIZE="100"
MAXIMUM_WEIGHT="40"
HEADER_RELAYER_REWARD_RATE_MOLECULE="1"
HEADER_RELAYER_REWARD_RATE_DENOMINATOR="5"
CALLER_COMPENSATION_MOLECULE="1"
CALLER_COMPENSATION_DENOMINATOR="80"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --roundSize)
        ROUND_SIZE="$2"
        shift
        ;;
    --maximumWeight)
        MAXIMUM_WEIGHT="$2"
        shift
        ;;
    --headerRelayerRewardRateMolecule)
        HEADER_RELAYER_REWARD_RATE_MOLECULE="$2"
        shift
        ;;
    --headerRelayerRewardRateDenominator)
        HEADER_RELAYER_REWARD_RATE_DENOMINATOR="$2"
        shift
        ;;
    --callerCompensationMolecule)
        CALLER_COMPENSATION_MOLECULE="$2"
        shift
        ;;
    --callerCompensationDenominator)
        CALLER_COMPENSATION_DENOMINATOR="$2"
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
sed -i -e "s/uint256 public constant ROUND_SIZE=.*;/uint256 public constant ROUND_SIZE = ${ROUND_SIZE};/g" "$OUTPUT"
sed -i -e "s/uint256 public constant MAXIMUM_WEIGHT=.*;/uint256 public constant MAXIMUM_WEIGHT = ${MAXIMUM_WEIGHT};/g" "$OUTPUT"
sed -i -e "s/uint256 public constant HEADER_RELAYER_REWARD_RATE_MOLECULE = .*;/uint256 public constant HEADER_RELAYER_REWARD_RATE_MOLECULE = ${HEADER_RELAYER_REWARD_RATE_MOLECULE};/g" "$OUTPUT"
sed -i -e "s/uint256 public constant HEADER_RELAYER_REWARD_RATE_DENOMINATOR = .*;/uint256 public constant HEADER_RELAYER_REWARD_RATE_DENOMINATOR = ${HEADER_RELAYER_REWARD_RATE_DENOMINATOR};/g" "$OUTPUT"
sed -i -e "s/uint256 public constant CALLER_COMPENSATION_MOLECULE = .*;/uint256 public constant CALLER_COMPENSATION_MOLECULE = ${CALLER_COMPENSATION_MOLECULE};/g" "$OUTPUT"
sed -i -e "s/uint256 public constant CALLER_COMPENSATION_DENOMINATOR = .*;/uint256 public constant CALLER_COMPENSATION_DENOMINATOR = ${CALLER_COMPENSATION_DENOMINATOR};/g" "$OUTPUT"

echo "RelayerIncentivize file updated."
