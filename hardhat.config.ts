import '@typechain/hardhat';
import 'hardhat-watcher'
import 'hardhat-gas-reporter';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
export default {
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
        hardhat: {
            accounts: {
                mnemonic: "clock radar mass judge dismiss just intact mind resemble fringe diary casino",
                count: 100
            },
            allowUnlimitedContractSize: true,
        },
        development: {
            url: "http://127.0.0.1:8545",     // Localhost (default: none)
            accounts: {
                mnemonic: "clock radar mass judge dismiss just intact mind resemble fringe diary casino",
                count: 100
            }
        },
        'bsc': {
            url: "https://bsc-dataseed1.ninicoin.io",
            accounts: {
                mnemonic: "clock radar mass judge dismiss just intact mind resemble fringe diary casino",
            }
        }
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
    },
    paths: {
        sources: "./contracts",
        tests: "./test/test-maintenance",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    gasReporter: {
        enabled: (process.env.REPORT_GAS) ? true : false
    }
};

