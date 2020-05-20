# bsc-genesis-contracts

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



