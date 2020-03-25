# bsc-genesis-contracts

#### Prepare

Install dependency:
```bash
$ npm install
``` 

#### unit test

```bash
$  ganache-cli --mnemonic 'clock radar mass judge dismiss just intact mind resemble fringe diary casino' --gasLimit 13000000  -e 10000
$  addr=0x9fB29AAc15b9A4B7F17c3385939b007540f4d791  // the first account of ganache
$  node generate-system.js --system-addr  $addr
$  node generate-validatorset.js --mock true
$  node generate-tokenhub.js --mock true
$  truffle compile
$  truffle migrate
$  truffle test
```

#### how to generate genesis file.
 
1. Edit `init_holders.js` file to alloc the initial BNB holder.
2. Edit `validators.js` file to alloc the initial validator set.
3. Edit `generate-validatorset.js` file to change chain-id.
4. run ` node generate-genesis.js` will generate genesis.json



