# bsc-genesis-contracts

This repo hold all the genesis contracts on Binance Smart chain. More details in [doc-site](https://docs.bnbchain.org/docs/learn/system-contract).

## Prepare

Install node.js dependency:
```shell script
npm install
```

Install foundry:
```shell script
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge install --no-git --no-commit foundry-rs/forge-std@v1.1.1
```

Please make sure your dependency version is as follows:

Node: v12.18.3 

Truffle: v5.1.31 

Solc: 0.6.4+commit.1dca32f3

Tips: You can manage multi version of Solc and Node:
```Shell
## Install solc-select and solc
pip3 install solc-select
solc-select install 0.6.4 && solc-select use 0.6.4

## Install nvm and node
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash
nvm install  12.18.3 && nvm use 12.18.3
```

## Unit test

Add follow line to .env file in project dir, replace `archive_node` with a valid bsc mainnet node url which should be in archive mode:

```text
RPC_BSC=${archive_node}
```

You can get a free archive node endpoint from https://nodereal.io/.

Run forge test:
```shell script
forge test
```

## Flatten all system contracts

```shell script
forge flatten contracts/BSCValidatorSet.sol > contracts/flattened/BSCValidatorSet.sol \
&& forge flatten contracts/GovHub.sol > contracts/flattened/GovHub.sol \
&& forge flatten contracts/RelayerHub.sol > contracts/flattened/RelayerHub.sol \
&& forge flatten contracts/RelayerIncentivize.sol > contracts/flattened/RelayerIncentivize.sol \
&& forge flatten contracts/SlashIndicator.sol > contracts/flattened/SlashIndicator.sol \
&& forge flatten contracts/SystemReward.sol > contracts/flattened/SystemReward.sol \
&& forge flatten contracts/TendermintLightClient.sol > contracts/flattened/TendermintLightClient.sol \
&& forge flatten contracts/TokenHub.sol > contracts/flattened/TokenHub.sol \
&& forge flatten contracts/CrossChain.sol > contracts/flattened/CrossChain.sol \
&& forge flatten contracts/TokenManager.sol > contracts/flattened/TokenManager.sol \
&& forge flatten contracts/Staking.sol > contracts/flattened/Staking.sol
```

All system contracts will be flattened and output into `${workspace}/contracts/flattened/`.

## How to generate genesis file

1. Edit `init_holders.js` file to alloc the initial BNB holder.
2. Edit `validators.js` file to alloc the initial validator set.
3. Edit `generate-validatorset.js` file to change `fromChainId` and `toChainId`,
4. Edit `generate-tokenhub.js` file to change `refundRelayReward`, `minimumRelayFee` and `maxGasForCallingBEP20`.
5. Edit `generate-tendermintlightclient.js` file to change `chainID` and `initConsensusStateBytes`.
6. run ` node generate-genesis.js` will generate genesis.json

## How to generate mainnet/testnet/QA genesis file

```shell 
npm run generate-mainnet
npm run generate-testnet
npm run generate-QA
```
Check the `genesis.json` file and you can get the exact compiled bytecode for different network.

## How to update contract interface for test

```shell script
// get metadata
forge build

// generate interface
cast interface ${workspace}/out/{contract_name}.sol/${contract_name}.json -p ^0.8.10 -n ${contract_name} > ${workspace}/test/utils/interface/I${contract_name}.sol
```

## License

The library is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0),
also included in our repository in the [LICENSE](LICENSE) file.
