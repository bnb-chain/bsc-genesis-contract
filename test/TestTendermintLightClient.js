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

        await lightClient.initConsensusState("0x746573742d636861696e00000000000000000000000000000000000000000000000000000000000" +
            "229eca254b3859bffefaf85f4c95da9fbd26527766b784272789c30ec56b380b6eb96442aaab207bc59978ba3dd477690f5c5872334f" +
            "c39e627723daa97e441e88ba4515150ec3182bc82593df36f8abb25a619187fcfab7e552b94e64ed2deed000000e8d4a51000",
            "test-chain", SystemReward.address, {from: accounts[0]});

        let _initialHeight = await lightClient._initialHeight.call();
        assert.equal(_initialHeight.toNumber(), 2, "mismatched initial consensus height");
        let _chainID = await lightClient._chainID.call();
        assert.equal(_chainID, "test-chain", "mismatched initial consensus height");
    });
});
