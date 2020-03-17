const HeaderRelayerIncentivize = artifacts.require("HeaderRelayerIncentivize");
const TransferRelayerIncentivize = artifacts.require("TransferRelayerIncentivize");
const TendermintLightClient = artifacts.require("TendermintLightClient");
const TokenHub = artifacts.require("TokenHub");

const crypto = require('crypto');
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

contract('TokenHub', (accounts) => {
    it('Init TokenHub', async () => {
        const tokenHub = await TokenHub.deployed();
        tx = await tokenHub.initTokenHub(TendermintLightClient.address, HeaderRelayerIncentivize.address, TransferRelayerIncentivize.address, 0x3, 0xf, 1000000000000, {from: accounts[0], value: 10e18 });

        let balance_wei = await web3.eth.getBalance(tokenHub.address);
        assert.equal(balance_wei, 10e18, "wrong balance");
        const _lightClientContract = await tokenHub._lightClientContract.call();
        assert.equal(_lightClientContract, TendermintLightClient.address, "wrong tendermint light client contract address");
    });
});
