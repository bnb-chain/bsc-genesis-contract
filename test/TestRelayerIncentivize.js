const RelayerIncentivize = artifacts.require("RelayerIncentivize");
const SystemReward = artifacts.require("SystemReward");
const TendermintLightClient = artifacts.require("TendermintLightClient");
const MockLightClient = artifacts.require("mock/MockLightClient");
const TokenHub = artifacts.require("TokenHub");
const TokenManager = artifacts.require("TokenManager");
const CrossChain = artifacts.require("CrossChain");
const ABCToken = artifacts.require("ABCToken");
const DEFToken = artifacts.require("DEFToken");
const XYZToken = artifacts.require("test/XYZToken");
const MiniToken = artifacts.require("test/MiniToken");
const MaliciousToken = artifacts.require("test/MaliciousToken");
const RelayerHub = artifacts.require("RelayerHub");
const GovHub = artifacts.require("GovHub");
const BSCValidatorSet = artifacts.require("BSCValidatorSet");
const SlashIndicator = artifacts.require("SlashIndicator");

const Web3 = require('web3');
const RLP = require('rlp');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

const GOV_CHANNEL_ID = 0x09;
const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
const merkleHeight = 100;

function serialize(key,value, target,extra) {
    let pkg = [];
    pkg.push(key);
    pkg.push(value);
    pkg.push(target);
    if(extra != null){
        pkg.push(extra);
    }
    return RLP.encode(pkg);
}

function toBytes32String(input) {
    let initialInputHexStr = web3.utils.toBN(input).toString(16);
    const initialInputHexStrLength = initialInputHexStr.length;

    let inputHexStr = initialInputHexStr;
    for (var i = 0; i < 64 - initialInputHexStrLength; i++) {
        inputHexStr = '0' + inputHexStr;
    }
    return inputHexStr;
}

function buildSyncPackagePrefix(syncRelayFee) {
    return Buffer.from(web3.utils.hexToBytes(
        "0x00" + toBytes32String(syncRelayFee)
    ));
}

contract('RelayerIncentivize', (accounts) => {
    it('init incentivize', async () => {
        const relayerIncentivize = await RelayerIncentivize.deployed();
        const systemReward = await SystemReward.deployed();
        let uselessAddr = web3.eth.accounts.create().address;

        const systemRewardContract = await relayerIncentivize.SYSTEM_REWARD_ADDR.call();
        assert.equal(systemRewardContract, systemReward.address, "wrong system reward contract address");
    });
    it('header relayer incentivize', async () => {
        const relayerIncentivize = await RelayerIncentivize.deployed();

        const initialAccount1Balance = await web3.eth.getBalance(accounts[1]);
        const initialAccount2Balance = await web3.eth.getBalance(accounts[2]);
        const initialAccount3Balance = await web3.eth.getBalance(accounts[3]);
        const initialAccount4Balance = await web3.eth.getBalance(accounts[4]);
        const initialAccount5Balance = await web3.eth.getBalance(accounts[5]);
        const initialAccount6Balance = await web3.eth.getBalance(accounts[6]);
        const initialAccount7Balance = await web3.eth.getBalance(accounts[7]);
        const initialAccount8Balance = await web3.eth.getBalance(accounts[8]);

        const roundSize = await relayerIncentivize.ROUND_SIZE.call();
        assert.equal(roundSize.toNumber(), 30, "wrong round size");
        const maximumWeight = await relayerIncentivize.MAXIMUM_WEIGHT.call();
        assert.equal(maximumWeight.toNumber(), 3, "wrong maximum weight");

        for(let i=0; i<1; i++){
            await relayerIncentivize.addReward(accounts[1], accounts[0], web3.utils.toBN(1e16), false, {from: accounts[0]});
        }
        for(let i=0; i<2; i++){
            await relayerIncentivize.addReward(accounts[2], accounts[0], web3.utils.toBN(1e16), false, {from: accounts[0]});
        }
        for(let i=0; i<3; i++){
            await relayerIncentivize.addReward(accounts[3], accounts[0], web3.utils.toBN(1e16), false, {from: accounts[0]});
        }
        for(let i=0; i<4; i++){
            await relayerIncentivize.addReward(accounts[4], accounts[0], web3.utils.toBN(1e16), false, {from: accounts[0]});
        }
        for(let i=0; i<5; i++){
            await relayerIncentivize.addReward(accounts[5], accounts[0], web3.utils.toBN(1e16), false, {from: accounts[0]});
        }
        for(let i=0; i<6; i++){
            await relayerIncentivize.addReward(accounts[6], accounts[0], web3.utils.toBN(1e16), false, {from: accounts[0]});
        }
        for(let i=0; i<7; i++){
            await relayerIncentivize.addReward(accounts[7], accounts[0], web3.utils.toBN(1e16), false, {from: accounts[0]});
        }
        for(let i=0; i<2; i++){
            await relayerIncentivize.addReward(accounts[8], accounts[0], web3.utils.toBN(1e16), false, {from: accounts[0]});
        }

        let roundSequence = await relayerIncentivize.roundSequence.call();
        assert.equal(roundSequence.toNumber(), 1, "wrong round sequence");

        await relayerIncentivize.claimRelayerReward(accounts[1], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[2], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[3], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[4], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[5], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[6], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[7], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[8], {from: accounts[0]});

        const newAccount1Balance = await web3.eth.getBalance(accounts[1]);
        const newAccount2Balance = await web3.eth.getBalance(accounts[2]);
        const newAccount3Balance = await web3.eth.getBalance(accounts[3]);
        const newAccount4Balance = await web3.eth.getBalance(accounts[4]);
        const newAccount5Balance = await web3.eth.getBalance(accounts[5]);
        const newAccount6Balance = await web3.eth.getBalance(accounts[6]);
        const newAccount7Balance = await web3.eth.getBalance(accounts[7]);
        const newAccount8Balance = await web3.eth.getBalance(accounts[8]);

        const rewardAccount1 = web3.utils.toBN(newAccount1Balance).sub(web3.utils.toBN(initialAccount1Balance));
        const rewardAccount2 = web3.utils.toBN(newAccount2Balance).sub(web3.utils.toBN(initialAccount2Balance));
        const rewardAccount3 = web3.utils.toBN(newAccount3Balance).sub(web3.utils.toBN(initialAccount3Balance));
        const rewardAccount4 = web3.utils.toBN(newAccount4Balance).sub(web3.utils.toBN(initialAccount4Balance));
        const rewardAccount5 = web3.utils.toBN(newAccount5Balance).sub(web3.utils.toBN(initialAccount5Balance));
        const rewardAccount6 = web3.utils.toBN(newAccount6Balance).sub(web3.utils.toBN(initialAccount6Balance));
        const rewardAccount7 = web3.utils.toBN(newAccount7Balance).sub(web3.utils.toBN(initialAccount7Balance));
        const rewardAccount8 = web3.utils.toBN(newAccount8Balance).sub(web3.utils.toBN(initialAccount8Balance));

        assert.equal(rewardAccount1.lt(rewardAccount2), true, "wrong reward");
        assert.equal(rewardAccount2.lt(rewardAccount3), true, "wrong reward");
        assert.equal(rewardAccount3.eq(rewardAccount4), true, "wrong reward");
        assert.equal(rewardAccount4.eq(rewardAccount5), true, "wrong reward");
        assert.equal(rewardAccount5.eq(rewardAccount6), true, "wrong reward");
        assert.equal(rewardAccount6.eq(rewardAccount7), true, "wrong reward");
        assert.equal(rewardAccount8.eq(rewardAccount2), true, "wrong reward");

    });
    it('transfer relayer Incentivize', async () => {
        const relayerIncentivize = await RelayerIncentivize.deployed();

        const initialAccount1Balance = await web3.eth.getBalance(accounts[1]);
        const initialAccount2Balance = await web3.eth.getBalance(accounts[2]);
        const initialAccount3Balance = await web3.eth.getBalance(accounts[3]);
        const initialAccount4Balance = await web3.eth.getBalance(accounts[4]);
        const initialAccount5Balance = await web3.eth.getBalance(accounts[5]);
        const initialAccount6Balance = await web3.eth.getBalance(accounts[6]);
        const initialAccount7Balance = await web3.eth.getBalance(accounts[7]);
        const initialAccount8Balance = await web3.eth.getBalance(accounts[8]);

        const gasPriceStr = await web3.eth.getGasPrice();
        const gasPrice = web3.utils.toBN(gasPriceStr);

        let account1TxFee = web3.utils.toBN(0);
        let account2TxFee = web3.utils.toBN(0);
        let account3TxFee = web3.utils.toBN(0);
        let account4TxFee = web3.utils.toBN(0);
        let account5TxFee = web3.utils.toBN(0);
        let account6TxFee = web3.utils.toBN(0);
        let account7TxFee = web3.utils.toBN(0);
        let account8TxFee = web3.utils.toBN(0);

        const tokenHub = accounts[9];

        for(let i=0; i<1; i++){
            let tx = await relayerIncentivize.addReward(accounts[0], accounts[1], web3.utils.toBN(1e16), false, {from: tokenHub});
            const txFee = web3.utils.toBN(tx.receipt.gasUsed).mul(gasPrice);
            account1TxFee = account1TxFee.add(txFee)
        }
        for(let i=0; i<2; i++){
            let tx = await relayerIncentivize.addReward(accounts[0], accounts[2], web3.utils.toBN(1e16), false, {from: tokenHub});
            const txFee = web3.utils.toBN(tx.receipt.gasUsed).mul(gasPrice);
            account2TxFee = account2TxFee.add(txFee)
        }
        for(let i=0; i<3; i++){
            let tx = await relayerIncentivize.addReward(accounts[0], accounts[3], web3.utils.toBN(1e16), false, {from: tokenHub});
            const txFee = web3.utils.toBN(tx.receipt.gasUsed).mul(gasPrice);
            account3TxFee = account3TxFee.add(txFee)
        }
        for(let i=0; i<4; i++){
            let tx = await relayerIncentivize.addReward(accounts[0], accounts[4], web3.utils.toBN(1e16), false, {from: tokenHub});
            const txFee = web3.utils.toBN(tx.receipt.gasUsed).mul(gasPrice);
            account4TxFee = account4TxFee.add(txFee)
        }
        for(let i=0; i<5; i++){
            let tx = await relayerIncentivize.addReward(accounts[0], accounts[5], web3.utils.toBN(1e16), false, {from: tokenHub});
            const txFee = web3.utils.toBN(tx.receipt.gasUsed).mul(gasPrice);
            account5TxFee = account5TxFee.add(txFee)
        }
        for(let i=0; i<6; i++){
            let tx = await relayerIncentivize.addReward(accounts[0], accounts[6], web3.utils.toBN(1e16), false, {from: tokenHub});
            const txFee = web3.utils.toBN(tx.receipt.gasUsed).mul(gasPrice);
            account6TxFee = account6TxFee.add(txFee)
        }
        for(let i=0; i<7; i++){
            let tx = await relayerIncentivize.addReward(accounts[0], accounts[7], web3.utils.toBN(1e16), false,{from: tokenHub});
            const txFee = web3.utils.toBN(tx.receipt.gasUsed).mul(gasPrice);
            account7TxFee = account7TxFee.add(txFee)
        }
        for(let i=0; i<2; i++){
            let tx = await relayerIncentivize.addReward(accounts[0], accounts[8], web3.utils.toBN(1e16), false, {from: tokenHub});
            const txFee = web3.utils.toBN(tx.receipt.gasUsed).mul(gasPrice);
            account8TxFee = account8TxFee.add(txFee)
        }
        let roundSequence = await relayerIncentivize.roundSequence.call();
        assert.equal(roundSequence.toNumber(), 2, "wrong round sequence");

        await relayerIncentivize.claimRelayerReward(accounts[1], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[2], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[3], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[4], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[5], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[6], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[7], {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(accounts[8], {from: accounts[0]});

        const newAccount1Balance = await web3.eth.getBalance(accounts[1]);
        const newAccount2Balance = await web3.eth.getBalance(accounts[2]);
        const newAccount3Balance = await web3.eth.getBalance(accounts[3]);
        const newAccount4Balance = await web3.eth.getBalance(accounts[4]);
        const newAccount5Balance = await web3.eth.getBalance(accounts[5]);
        const newAccount6Balance = await web3.eth.getBalance(accounts[6]);
        const newAccount7Balance = await web3.eth.getBalance(accounts[7]);
        const newAccount8Balance = await web3.eth.getBalance(accounts[8]);

        const pureRewardAccount1 = web3.utils.toBN(newAccount1Balance).sub(web3.utils.toBN(initialAccount1Balance)).sub(account1TxFee);
        const pureRewardAccount2 = web3.utils.toBN(newAccount2Balance).sub(web3.utils.toBN(initialAccount2Balance)).sub(account2TxFee);
        const pureRewardAccount3 = web3.utils.toBN(newAccount3Balance).sub(web3.utils.toBN(initialAccount3Balance)).sub(account3TxFee);
        const pureRewardAccount4 = web3.utils.toBN(newAccount4Balance).sub(web3.utils.toBN(initialAccount4Balance)).sub(account4TxFee);
        const pureRewardAccount5 = web3.utils.toBN(newAccount5Balance).sub(web3.utils.toBN(initialAccount5Balance)).sub(account5TxFee);
        const pureRewardAccount6 = web3.utils.toBN(newAccount6Balance).sub(web3.utils.toBN(initialAccount6Balance)).sub(account6TxFee);
        const pureRewardAccount7 = web3.utils.toBN(newAccount7Balance).sub(web3.utils.toBN(initialAccount7Balance)).sub(account7TxFee);
        const pureRewardAccount8 = web3.utils.toBN(newAccount8Balance).sub(web3.utils.toBN(initialAccount8Balance)).sub(account8TxFee);

        assert.equal(pureRewardAccount1.lt(pureRewardAccount2), true, "wrong reward");
        assert.equal(pureRewardAccount2.lt(pureRewardAccount3), true, "wrong reward");
        assert.equal(pureRewardAccount3.gt(pureRewardAccount4), true, "wrong reward");
        assert.equal(pureRewardAccount4.gt(pureRewardAccount5), true, "wrong reward");
        assert.equal(pureRewardAccount5.gt(pureRewardAccount6), true, "wrong reward");
        assert.equal(pureRewardAccount6.gt(pureRewardAccount7), true, "wrong reward");
        assert.equal(pureRewardAccount8.gt(pureRewardAccount2), true, "wrong reward"); // get extra 1/80 of total reward
        assert.equal(pureRewardAccount8.lt(pureRewardAccount3), true, "wrong reward"); // get extra 1/80 of total reward
    });
    it('non-payable address', async () => {
        const relayerIncentivize = await RelayerIncentivize.deployed();
        const tendermintLightClient = await TendermintLightClient.deployed();

        const tokenHub = accounts[9];
        const relayer = accounts[0];

        for(let i=0; i<15; i++){
            await relayerIncentivize.addReward(tendermintLightClient.address, relayer, web3.utils.toBN(1e16), false, {from: tokenHub});
        }

        for(let i=0; i<14; i++){
            await relayerIncentivize.addReward(relayer, tendermintLightClient.address, web3.utils.toBN(1e16), false, {from: tokenHub});
        }

        const systemReward = await SystemReward.deployed();
        const originSystemRewardBalance = await web3.eth.getBalance(systemReward.address);

        await relayerIncentivize.addReward(relayer, tendermintLightClient.address, web3.utils.toBN(1e16), true, {from: tokenHub});

        await relayerIncentivize.claimRelayerReward(relayer, {from: accounts[0]});
        await relayerIncentivize.claimRelayerReward(tendermintLightClient.address, {from: accounts[0]});

        const newSystemRewardBalance = await web3.eth.getBalance(systemReward.address);
        assert.equal(web3.utils.toBN(newSystemRewardBalance).sub(web3.utils.toBN(originSystemRewardBalance)).eq(web3.utils.toBN(146812500000000000)), true, "wrong amount to systemReward contract");

        let roundSequence = await relayerIncentivize.roundSequence.call();
        assert.equal(roundSequence.toNumber(), 3, "wrong round sequence");
    });
    it('dynamic extra incentive', async () => {
        const relayerIncentivize = await RelayerIncentivize.deployed();
        const crossChain = await CrossChain.deployed();
        const govHub = await GovHub.deployed();
        const relayer = accounts[2];

        const relayerInstance = await RelayerHub.deployed();
        await relayerInstance.register({from: relayer, value: 1e20});

        const initialAccount1Balance = await web3.eth.getBalance(relayer);

        const roundSize = await relayerIncentivize.ROUND_SIZE.call();
        assert.equal(roundSize.toNumber(), 30, "wrong round size");
        const maximumWeight = await relayerIncentivize.MAXIMUM_WEIGHT.call();
        assert.equal(maximumWeight.toNumber(), 3, "wrong maximum weight");

        for(let i=0; i<30; i++){
            await relayerIncentivize.addReward(relayer, accounts[0], web3.utils.toBN(1e16), false, {from: accounts[0]});
        }

        await relayerIncentivize.claimRelayerReward(relayer, {from: accounts[0]});

        let roundSequence = await relayerIncentivize.roundSequence.call();
        assert.equal(roundSequence.toNumber(), 4, "wrong round sequence");

        const newRelayerBalance1 = await web3.eth.getBalance(relayer);

        const relayerReward1 = web3.utils.toBN(newRelayerBalance1).sub(web3.utils.toBN(initialAccount1Balance));


        for(let i=0; i<30; i++){
            await relayerIncentivize.addReward(relayer, accounts[0], web3.utils.toBN(2e16), false, {from: accounts[0]});
        }

        await relayerIncentivize.claimRelayerReward(relayer, {from: accounts[0]});

        roundSequence = await relayerIncentivize.roundSequence.call();
        assert.equal(roundSequence.toNumber(), 5, "wrong round sequence");

        const newRelayerBalance2 = await web3.eth.getBalance(relayer);

        const relayerReward2 = web3.utils.toBN(newRelayerBalance2).sub(web3.utils.toBN(newRelayerBalance1));
        assert.equal(relayerReward2.gt(relayerReward1), true, "relayerReward2 should be larger than relayerReward1");

        let dynamicExtraIncentiveAmount = await relayerIncentivize.dynamicExtraIncentiveAmount.call();
        assert.equal(web3.utils.toBN(dynamicExtraIncentiveAmount).eq(web3.utils.toBN(0)), true, "wrong dynamicExtraIncentiveAmount");

        await govHub.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address, MockLightClient.address, TokenHub.address, RelayerIncentivize.address, RelayerHub.address, GovHub.address, TokenManager.address, CrossChain.address);

        await web3.eth.sendTransaction({to:SystemReward.address, from:accounts[3], value: web3.utils.toWei("10", "ether")});

        let govChannelSeq = await crossChain.channelReceiveSequenceMap(GOV_CHANNEL_ID);
        let govValue = "0x000000000000000000000000000000000000000000000000002386F26FC10000";// 1e16;
        let govPackageBytes = serialize("dynamicExtraIncentiveAmount", govValue, RelayerIncentivize.address);
        await crossChain.handlePackage(Buffer.concat([buildSyncPackagePrefix(2e16), (govPackageBytes)]), proof, merkleHeight, govChannelSeq, GOV_CHANNEL_ID, {from: relayer});

        await govHub.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address, MockLightClient.address, TokenHub.address, RelayerIncentivize.address, RelayerHub.address, GovHub.address, TokenManager.address, accounts[8]);

        dynamicExtraIncentiveAmount = await relayerIncentivize.dynamicExtraIncentiveAmount.call();
        assert.equal(web3.utils.toBN(dynamicExtraIncentiveAmount).eq(web3.utils.toBN(1e16)), true, "wrong dynamicExtraIncentiveAmount");

        for(let i=0; i<29; i++){
            await relayerIncentivize.addReward(relayer, accounts[0], web3.utils.toBN(1e16), false, {from: accounts[0]});
        }

        roundSequence = await relayerIncentivize.roundSequence.call();
        assert.equal(roundSequence.toNumber(), 6, "wrong round sequence");

        await relayerIncentivize.claimRelayerReward(relayer, {from: accounts[0]});

        const relayerBalanceBeforeReward3 = await web3.eth.getBalance(relayer);

        for(let i=0; i<30; i++){
            await relayerIncentivize.addReward(relayer, accounts[0], web3.utils.toBN(1e16), false, {from: accounts[0]});
        }

        await relayerIncentivize.claimRelayerReward(relayer, {from: accounts[0]});

        roundSequence = await relayerIncentivize.roundSequence.call();
        assert.equal(roundSequence.toNumber(), 7, "wrong round sequence");

        const newRelayerBalance3 = await web3.eth.getBalance(relayer);

        const relayerReward3 = web3.utils.toBN(newRelayerBalance3).sub(web3.utils.toBN(relayerBalanceBeforeReward3));
        assert.equal(relayerReward3.eq(relayerReward2), true, "relayerReward3 should equal to relayerReward2");
    });
});
