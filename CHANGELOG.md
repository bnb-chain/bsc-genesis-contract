# Changelog

## v1.0.0-beta.0

BUG FIXES
* [\#9](https://github.com/binance-chain/bsc-genesis-contract/pull/9) Fix gov hub do not well handle when the target account is not contract

FEATURES
* [\#7](https://github.com/binance-chain/bsc-genesis-contract/pull/7) Implement governance mechanism to update parameters in build-in system contract
* [\#12](https://github.com/binance-chain/bsc-genesis-contract/pull/12) Implement token unbind mechanism
* [\#21](https://github.com/binance-chain/bsc-genesis-contract/pull/21) Support miniToken cross chain transfer
* [\#28](https://github.com/binance-chain/bsc-genesis-contract/pull/28) Add more events about token bind and transfer to facilitate reconciliation
* [\#29](https://github.com/binance-chain/bsc-genesis-contract/pull/29) Implement a mechanism enable or disable channel through governance

IMPROVEMENTS
* [\#3](https://github.com/binance-chain/bsc-genesis-contract/pull/3) Check sequence first to save gas for relayers
* [\#13](https://github.com/binance-chain/bsc-genesis-contract/pull/13) Refactor cross chain architecture, communication layer: verify proof and manage sequence, application layer: focus on detailed application scenario
* [\#14](https://github.com/binance-chain/bsc-genesis-contract/pull/14) Gov/Validator/Slash modification for refactor of cross chain mechanism
* [\#19](https://github.com/binance-chain/bsc-genesis-contract/pull/19) Optimize rlp decoding and encoding library to save gas
* [\#22](https://github.com/binance-chain/bsc-genesis-contract/pull/22) Add fail ack handler for transferOut
* [\#24](https://github.com/binance-chain/bsc-genesis-contract/pull/24) Split tokenhub contract into tokenhub(for cross chain transfer) and tokenManager(for token bind and unbind)
