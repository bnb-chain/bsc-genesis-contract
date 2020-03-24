const BN = require('bn.js');
const sleep = require("await-sleep");

const HeaderRelayerIncentivize = artifacts.require("HeaderRelayerIncentivize");
const TransferRelayerIncentivize = artifacts.require("TransferRelayerIncentivize");

const crypto = require('crypto');
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

const sourceChainID = 0x3;
const destChainID = 0xf;

contract('RelayerIncentivize', (accounts) => {
    it('HeaderRelayerIncentivize', async () => {
        const headerRelayerIncentivize = await HeaderRelayerIncentivize.deployed();

        const initialAccount1Balance = await web3.eth.getBalance(accounts[1]);
        const initialAccount2Balance = await web3.eth.getBalance(accounts[2]);
        const initialAccount3Balance = await web3.eth.getBalance(accounts[3]);
        const initialAccount4Balance = await web3.eth.getBalance(accounts[4]);
        const initialAccount5Balance = await web3.eth.getBalance(accounts[5]);

        for(let i=0; i<4; i++){
            await headerRelayerIncentivize.addReward(accounts[1], {from: accounts[0], value: web3.utils.toBN(1e16)});
        }
        for(let i=0; i<5; i++){
            await headerRelayerIncentivize.addReward(accounts[2], {from: accounts[0], value: web3.utils.toBN(1e16)});
        }
        for(let i=0; i<6; i++){
            await headerRelayerIncentivize.addReward(accounts[3], {from: accounts[0], value: web3.utils.toBN(1e16)});
        }
        for(let i=0; i<7; i++){
            await headerRelayerIncentivize.addReward(accounts[4], {from: accounts[0], value: web3.utils.toBN(1e16)});
        }
        let _roundSequence = await headerRelayerIncentivize._roundSequence.call();
        assert.equal(_roundSequence.toNumber(), 1, "wrong round sequence");

        let isMature = await headerRelayerIncentivize._matureRound.call(0);
        assert.equal(isMature, true, "round");

        const gasPrice = await web3.eth.getGasPrice();
        const tx = await headerRelayerIncentivize.withdrawReward(0, {from: accounts[5]});

        const newAccount1Balance = await web3.eth.getBalance(accounts[1]);
        const newAccount2Balance = await web3.eth.getBalance(accounts[2]);
        const newAccount3Balance = await web3.eth.getBalance(accounts[3]);
        const newAccount4Balance = await web3.eth.getBalance(accounts[4]);
        const newAccount5Balance = await web3.eth.getBalance(accounts[5]);

        const txFee = gasPrice*tx.receipt.gasUsed;

        console.log("Reward for account 1: "+web3.utils.toBN(newAccount1Balance).sub(web3.utils.toBN(initialAccount1Balance)));
        console.log("Reward for account 2: "+web3.utils.toBN(newAccount2Balance).sub(web3.utils.toBN(initialAccount2Balance)));
        console.log("Reward for account 3: "+web3.utils.toBN(newAccount3Balance).sub(web3.utils.toBN(initialAccount3Balance)));
        console.log("Reward for account 4: "+web3.utils.toBN(newAccount4Balance).sub(web3.utils.toBN(initialAccount4Balance)));
        console.log("Reward for account 5: "+web3.utils.toBN(newAccount5Balance).sub(web3.utils.toBN(initialAccount5Balance)));
        console.log("Withdraw reward cost: "+txFee);
        console.log("Pure reward         : "+web3.utils.toBN(newAccount5Balance).sub(web3.utils.toBN(initialAccount5Balance)).add(web3.utils.toBN(txFee)));
    });
    it('TransferRelayerIncentivize', async () => {
        const transferRelayerIncentivize = await TransferRelayerIncentivize.deployed();

        const initialAccount5Balance = await web3.eth.getBalance(accounts[5]);
        const initialAccount6Balance = await web3.eth.getBalance(accounts[6]);
        const initialAccount7Balance = await web3.eth.getBalance(accounts[7]);
        const initialAccount8Balance = await web3.eth.getBalance(accounts[8]);
        const initialAccount9Balance = await web3.eth.getBalance(accounts[9]);

        for(let i=0; i<4; i++){
            await transferRelayerIncentivize.addReward(accounts[6], {from: accounts[0], value: web3.utils.toBN(1e16)});
        }
        for(let i=0; i<5; i++){
            await transferRelayerIncentivize.addReward(accounts[7], {from: accounts[0], value: web3.utils.toBN(1e16)});
        }
        for(let i=0; i<6; i++){
            await transferRelayerIncentivize.addReward(accounts[8], {from: accounts[0], value: web3.utils.toBN(1e16)});
        }
        for(let i=0; i<7; i++){
            await transferRelayerIncentivize.addReward(accounts[9], {from: accounts[0], value: web3.utils.toBN(1e16)});
        }
        let _roundSequence = await transferRelayerIncentivize._roundSequence.call();
        assert.equal(_roundSequence.toNumber(), 1, "wrong round sequence");

        let isMature = await transferRelayerIncentivize._matureRound.call(0);
        assert.equal(isMature, true, "round");

        const gasPrice = await web3.eth.getGasPrice();

        const tx = await transferRelayerIncentivize.withdrawReward(0, {from: accounts[5]});

        const newAccount5Balance = await web3.eth.getBalance(accounts[5]);
        const newAccount6Balance = await web3.eth.getBalance(accounts[6]);
        const newAccount7Balance = await web3.eth.getBalance(accounts[7]);
        const newAccount8Balance = await web3.eth.getBalance(accounts[8]);
        const newAccount9Balance = await web3.eth.getBalance(accounts[9]);

        const txFee = gasPrice*tx.receipt.gasUsed;


        console.log("Reward for account 6: "+web3.utils.toBN(newAccount6Balance).sub(web3.utils.toBN(initialAccount6Balance)));
        console.log("Reward for account 7: "+web3.utils.toBN(newAccount7Balance).sub(web3.utils.toBN(initialAccount7Balance)));
        console.log("Reward for account 8: "+web3.utils.toBN(newAccount8Balance).sub(web3.utils.toBN(initialAccount8Balance)));
        console.log("Reward for account 9: "+web3.utils.toBN(newAccount9Balance).sub(web3.utils.toBN(initialAccount9Balance)));
        console.log("Reward for account 5: "+web3.utils.toBN(newAccount5Balance).sub(web3.utils.toBN(initialAccount5Balance)));
        console.log("Withdraw reward cost: "+txFee);
        console.log("Pure reward         : "+web3.utils.toBN(newAccount5Balance).sub(web3.utils.toBN(initialAccount5Balance)).add(web3.utils.toBN(txFee)));
    });
});