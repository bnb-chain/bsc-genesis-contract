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
forge install --no-git --no-commit foundry-rs/forge-std
```

Please make sure your dependency version is as follows:

Node: v12.18.3 

Truffle: v5.1.31 

Solc: 0.6.4+commit.1dca32f3.Darwin.appleclang 

## Unit test

Edit .env, replace ARCHIVE_NODE with a valid node url which should be in archive mode:
```text
RPC_BSC=${ARCHIVE_NODE}
```

Run forge test:
```shell script
forge test
```

Flatten all system contracts:
```shell script
npm run flatten
```

## How to generate genesis file.
 
1. Edit `init_holders.js` file to alloc the initial BNB holder.
2. Edit `validators.js` file to alloc the initial validator set.
3. Edit `generate-validatorset.js` file to change `fromChainId` and `toChainId`,
4. Edit `generate-tokenhub.js` file to change `refundRelayReward`, `minimumRelayFee` and `maxGasForCallingBEP20`.
5. Edit `generate-tendermintlightclient.js` file to change `chainID` and `initConsensusStateBytes`.
6. run ` node generate-genesis.js` will generate genesis.json

## License

The library is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0),
also included in our repository in the [LICENSE](LICENSE) file.
