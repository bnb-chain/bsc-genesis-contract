#!/usr/bin/env bash

# Default values
OUTPUT="./contracts/RelayerHub.sol"
NETWORK="mainnet"

MAINNET_WHITELIST1="address public constant WHITELIST_1 = 0xb005741528b86F5952469d80A8614591E3c5B632;"
MAINNET_WHITELIST2="address public constant WHITELIST_2 = 0x446AA6E0DC65690403dF3F127750da1322941F3e;"

LOCAL_WHITELIST1="address public constant WHITELIST_1 = 0xA904540818AC9c47f2321F97F1069B9d8746c6DB;"
LOCAL_WHITELIST2="address public constant WHITELIST_2 = 0x316b2Fa7C8a2ab7E21110a4B3f58771C01A71344;"

QA_WHITELIST1="address public constant WHITELIST_1 = 0x88cb4D8F77742c24d647BEf8049D3f3C56067cDD;"
QA_WHITELIST2="address public constant WHITELIST_2 = 0x42D596440775C90db8d9187b47650986E1063493;"

TESTNET_WHITELIST1="address public constant WHITELIST_1 = 0x9fB29AAc15b9A4B7F17c3385939b007540f4d791;"
TESTNET_WHITELIST2="address public constant WHITELIST_2 = 0x37B8516a0F88E65D677229b402ec6C1e0E333004;"

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
    sed -i -e "s/address public constant WHITELIST_1 = .*;/${LOCAL_WHITELIST1}/g" "$OUTPUT"
    sed -i -e "s/address public constant WHITELIST_2 = .*;/${LOCAL_WHITELIST2}/g" "$OUTPUT"
    sed -i -e "s/function whitelistInit() external/function whitelistInit() public/g" "$OUTPUT"
    sed -i -e "s/alreadyInit = true;/whitelistInit();\nalreadyInit = true;/g" "$OUTPUT"
    ;;
QA)
    sed -i -e "s/address public constant WHITELIST_1 = .*;/${QA_WHITELIST1}/g" "$OUTPUT"
    sed -i -e "s/address public constant WHITELIST_2 = .*;/${QA_WHITELIST2}/g" "$OUTPUT"
    ;;
testnet)
    sed -i -e "s/address public constant WHITELIST_1 = .*;/${TESTNET_WHITELIST1}/g" "$OUTPUT"
    sed -i -e "s/address public constant WHITELIST_2 = .*;/${TESTNET_WHITELIST2}/g" "$OUTPUT"
    ;;
mainnet)
    sed -i -e "s/address public constant WHITELIST_1 = .*;/${MAINNET_WHITELIST1}/g" "$OUTPUT"
    sed -i -e "s/address public constant WHITELIST_2 = .*;/${MAINNET_WHITELIST2}/g" "$OUTPUT"
    ;;
*)
    echo "Error: Invalid network."
    exit 1
    ;;
esac

echo "RelayerHub file updated."
