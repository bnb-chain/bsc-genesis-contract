require('hardhat-watcher');
require("@nomiclabs/hardhat-truffle5");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.6.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
    ]
  },

  networks: {
    development: {
      url: "127.0.0.1:8545",     // Localhost (default: none)
      accounts: {
        mnemonic: "clock radar mass judge dismiss just intact mind resemble fringe diary casino",
        count: 100
      }
    },
    'bsc': {
      // url: process.env.BSC_API || "",
      // url:"https://bsc-dataseed1.defibit.io/",
      url: "https://bsc-dataseed1.ninicoin.io",
      //url:"https://bsc-dataseed2.defibit.io/",
      //url:"https://bsc-dataseed3.defibit.io/",
      //url:"https://bsc-dataseed4.defibit.io/",
      //url:"https://bsc-dataseed2.ninicoin.io",
      //url:"https://bsc-dataseed3.ninicoin.io",
      //url:"https://bsc-dataseed4.ninicoin.io",
      //url:"https://bsc-dataseed1.binance.org",
      //url:"https://bsc-dataseed2.binance.org",
      //url:"https://bsc-dataseed3.binance.org",
      //url:"https://bsc-dataseed4.binance.org",

      accounts: {
        mnemonic: process.env.BSC_TEST_MN ? process.env.BSC_TEST_MN : "",
      }
    },
  },
  watcher: {
    compilation: {
      tasks: ["compile"],
      files: ["./contracts"],
      verbose: true,
    }
  },
  mocha: {
    timeout: 2000000
  }
};

