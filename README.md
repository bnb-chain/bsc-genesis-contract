# bsc-genesis-contracts

This repo hold all the genesis contracts on Binance Smart chain. More details in [doc-site](https://github.com/binance-chain/docs-site/blob/add-bsc/docs/smart-chain/guides/concepts/system-contract.md).

#### Disclaimer
**The software and related documentation are under active development, 
all subjected to potential future change without notification and not ready for production use. 
The code and security audit have not been fully completed and not ready for any bug bounty.**

#### Prepare

Install dependency:
```shell script
npm install
``` 

#### unit test

Generate contracts for testing:
```shell script
# the first account of ganache
node generate-system.js --mock true
node generate-systemReward.js --mock true
node generate-validatorset.js --mock true
node generate-system.js --mock true
node generate-govhub.js --mock true
node generate-tokenhub.js --mock true
node generate-tendermintlightclient.js --mock true
node generate-relayerincentivizecontract.js --roundSize 30 --maximumWeight 3 --mock true
```

Start ganache:
```shell script
ganache-cli --mnemonic 'clock radar mass judge dismiss just intact mind resemble fringe diary casino' --gasLimit 13000000  -e 10000
```

Run truffle test:
```shell script
truffle compile
truffle migrate
truffle test
```

Flatten all system contracts:
```shell script
npm run flatten
```

#### how to generate genesis file.
 
1. Edit `init_holders.js` file to alloc the initial BNB holder.
2. Edit `validators.js` file to alloc the initial validator set.
3. Edit `generate-validatorset.js` file to change `fromChainId` and `toChainId`,
4. Edit `generate-tokenhub.js` file to change `refundRelayReward`, `minimumRelayFee` and `maxGasForCallingBEP2E`.
5. Edit `generate-tendermintlightclient.js` file to change `chainID` and `initConsensusStateBytes`.
6. run ` node generate-genesis.js` will generate genesis.json

#### License

The library is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0),
also included in our repository in the [LICENSE](LICENSE) file.
