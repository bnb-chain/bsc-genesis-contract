# bsc-genesis-contracts

#### Prepare

Install dependency:
```shell script
npm install
``` 

#### unit test

```shell script
ganache-cli --mnemonic 'clock radar mass judge dismiss just intact mind resemble fringe diary casino' --gasLimit 13000000  -e 10000
addr=0x9fB29AAc15b9A4B7F17c3385939b007540f4d791  // the first account of ganache
node generate-system.js --system-addr  $addr
node generate-validatorset.js --mock true
node generate-tokenhub.js --mock true
node generate-slash.js --mock true
node generate-tendermintlightclient.js --mock true
node generate-headerrelayercontract.js --roundSize 20 --maximumWeight 10
node generate-tranferrelayercontract.js --roundSize 20 --maximumWeight 10
truffle compile
truffle migrate
truffle test
```

#### how to generate genesis file.
 
1. Edit `init_holders.js` file to alloc the initial BNB holder.
2. Edit `validators.js` file to alloc the initial validator set.
3. Edit `generate-validatorset.js` file to change `fromChainId` and `toChainId`,
4. Edit `generate-tokenhub.js` file to change `fromChainId`, `toChainId`, `refundRelayReward` and `minimumRelayFee`.
5. Edit `generate-tendermintlightclient.js` file to change `chainID` and `initConsensusStateBytes`.
6. run ` node generate-genesis.js` will generate genesis.json



