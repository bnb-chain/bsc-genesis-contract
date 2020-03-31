const RelayerIncentivize = artifacts.require("RelayerIncentivize");

const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

contract('RelayerIncentivize', (accounts) => {
    it('HeaderRelayerIncentivize', async () => {
        const relayerIncentivize = await RelayerIncentivize.deployed();

        const initialAccount1Balance = await web3.eth.getBalance(accounts[1]);
        const initialAccount2Balance = await web3.eth.getBalance(accounts[2]);
        const initialAccount3Balance = await web3.eth.getBalance(accounts[3]);
        const initialAccount4Balance = await web3.eth.getBalance(accounts[4]);
        const initialAccount5Balance = await web3.eth.getBalance(accounts[5]);

        for(let i=0; i<4; i++){
            await relayerIncentivize.addReward(accounts[1], accounts[0], {from: accounts[0], value: web3.utils.toBN(1e16)});
        }
        for(let i=0; i<5; i++){
            await relayerIncentivize.addReward(accounts[2], accounts[0], {from: accounts[0], value: web3.utils.toBN(1e16)});
        }
        for(let i=0; i<6; i++){
            await relayerIncentivize.addReward(accounts[3], accounts[0], {from: accounts[0], value: web3.utils.toBN(1e16)});
        }
        for(let i=0; i<7; i++){
            await relayerIncentivize.addReward(accounts[4], accounts[0], {from: accounts[0], value: web3.utils.toBN(1e16)});
        }
        let _roundSequence = await headerRelayerIncentivize._roundSequence.call();
        assert.equal(_roundSequence.toNumber(), 1, "wrong round sequence");

        const newAccount1Balance = await web3.eth.getBalance(accounts[1]);
        const newAccount2Balance = await web3.eth.getBalance(accounts[2]);
        const newAccount3Balance = await web3.eth.getBalance(accounts[3]);
        const newAccount4Balance = await web3.eth.getBalance(accounts[4]);
        const newAccount5Balance = await web3.eth.getBalance(accounts[5]);

        //TODO improve the balance change verification
        console.log("Reward for account 1: "+web3.utils.toBN(newAccount1Balance).sub(web3.utils.toBN(initialAccount1Balance)));
        console.log("Reward for account 2: "+web3.utils.toBN(newAccount2Balance).sub(web3.utils.toBN(initialAccount2Balance)));
        console.log("Reward for account 3: "+web3.utils.toBN(newAccount3Balance).sub(web3.utils.toBN(initialAccount3Balance)));
        console.log("Reward for account 4: "+web3.utils.toBN(newAccount4Balance).sub(web3.utils.toBN(initialAccount4Balance)));
        console.log("Reward for account 5: "+web3.utils.toBN(newAccount5Balance).sub(web3.utils.toBN(initialAccount5Balance)));
    });
});