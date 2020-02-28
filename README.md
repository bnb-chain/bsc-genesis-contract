# bsc-genesis-contracts

#### Prepare
```bash
docker pull  ethereum/solc:0.5.14
``` 

#### unit test

```bash
$  ganache-cli --mnemonic 'clock radar mass judge dismiss just intact mind resemble fringe diary casino' --gasLimit 13000000  -e 10000
$  addr=0x9fB29AAc15b9A4B7F17c3385939b007540f4d791  // the first account of ganache
$  node generate-system.js --system-addr  $addr
$  node generate-validatorset.js
$  truffle compile
$  truffle migrate
$  truffle test
```
