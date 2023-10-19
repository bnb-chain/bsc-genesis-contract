# bsc-genesis-contracts

This repo hold all the genesis contracts on BNB Smart chain. More details in [doc-site](https://docs.bnbchain.org/docs/learn/system-contract).

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


Tips: You can manage multi version of Node:
```Shell
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
bash flatten.sh
```

All system contracts will be flattened and output into `${workspace}/contracts/flattened/`.

## How to generate genesis file

1. Edit `init_holders.js` file to alloc the initial BNB holder.
2. Edit `validators.js` file to alloc the initial validator set.
3. Run `bash scripts/generate-*.sh` to change system contracts setting.
4. Run `node scripts/generate-genesis.js` will generate genesis.json

## How to generate mainnet/testnet/QA genesis file

```shell 
bash scripts/generate.sh mainnet
bash scripts/generate.sh testnet
bash scripts/generate.sh QA
bash scripts/generate.sh local
```
Check the `genesis.json` file, and you can get the exact compiled bytecode for different network.

## How to update contract interface for test

```shell script
// get metadata
forge build

// generate interface
cast interface ${workspace}/out/{contract_name}.sol/${contract_name}.json -p ^0.8.0 -n ${contract_name} > ${workspace}/test/utils/interface/I${contract_name}.sol
```

## BEP-171 unlock bot
```shell script
npm install ts-node -g

cp .env.example .env
# set UNLOCK_RECEIVER, OPERATOR_PRIVATE_KEY to .env

ts-node scripts/bep171-unlock-bot.ts 
```

## License

The library is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0),
also included in our repository in the [LICENSE](LICENSE) file.
