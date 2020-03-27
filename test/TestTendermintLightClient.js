const SystemReward = artifacts.require("SystemReward");
const HeaderRelayerIncentivize = artifacts.require("HeaderRelayerIncentivize");
const TransferRelayerIncentivize = artifacts.require("TransferRelayerIncentivize");
const TendermintLightClient = artifacts.require("TendermintLightClient");

const crypto = require('crypto');
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

contract('TendermintLightClient', (accounts) => {
    it('Init consensus state', async () => {
        const lightClient = await TendermintLightClient.deployed();

        await lightClient.init({from: accounts[0]});
        await lightClient.initSystemRewardContract(SystemReward.address, {from: accounts[0]});

        let _initialHeight = await lightClient._initialHeight.call();
        assert.equal(_initialHeight.toNumber(), 2, "mismatched initial consensus height");
        let _chainID = await lightClient._chainID.call();
        assert.equal(_chainID, "Binance-Chain-Nile", "mismatched initial consensus height");
    });
});
