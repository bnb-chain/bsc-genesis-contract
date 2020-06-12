const BN = require('bn.js');
const sleep = require("await-sleep");
const RLP = require('rlp');

const SystemReward = artifacts.require("SystemReward");
const RelayerIncentivize = artifacts.require("RelayerIncentivize");
//const TendermintLightClient = artifacts.require("TendermintLightClient");
const MockLightClient = artifacts.require("mock/MockLightClient");
const TokenHub = artifacts.require("TokenHub");
const CrossChain = artifacts.require("CrossChain");
const ABCToken = artifacts.require("ABCToken");
const DEFToken = artifacts.require("DEFToken");
const MaliciousToken = artifacts.require("test/MaliciousToken");
const RelayerHub = artifacts.require("RelayerHub");

const crypto = require('crypto');
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

const BIND_CHANNEL_ID = 0x01;
const TRANSFER_IN_CHANNELID = 0x02;
const TRANSFER_OUT_CHANNELID = 0x03;

const merkleHeight = 100;

contract('TokenHub', (accounts) => {
    it('Init TokenHub', async () => {
        const mockLightClient = await MockLightClient.deployed();
        await mockLightClient.setBlockNotSynced(false);

        const tokenHub = await TokenHub.deployed();
        let balance_wei = await web3.eth.getBalance(tokenHub.address);
        assert.equal(balance_wei, 50e18, "wrong balance");
        const _lightClientContract = await tokenHub.LIGHT_CLIENT_ADDR.call();
        assert.equal(_lightClientContract, MockLightClient.address, "wrong tendermint light client contract address");

        const relayer = accounts[1];
        const relayerInstance = await RelayerHub.deployed();
        await relayerInstance.register({from: relayer, value: 1e20});
        let res = await relayerInstance.isRelayer.call(relayer);
        assert.equal(res,true);
    });
    it('Relay expired bind package', async () => {
        const abcToken = await ABCToken.deployed();
        const tokenHub = await TokenHub.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }
        expireTimeStr = "0x" + expireTimeStr;

        const packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x00" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        const packageBytes = RLP.encode([
            "0x00",                                                                //bind type
            "0x4142432d39433700000000000000000000000000000000000000000000000000",  //bep2TokenSymbol
            abcToken.address,                                                      //bep2e contract address
            "0x00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000",  //total supply
            "0x00000000000000000000000000000000000000000051e410c0f93fe543000000",  //peggy amount
            18,                                                                    //decimals
            expireTimeStr]);                                                       //expire time

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        let sequence = 0;

        await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, BIND_CHANNEL_ID, {from: relayer});

        let bindRequenst = await tokenHub.bindPackageRecord.call("0x4142432d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x4142432d39433700000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
        assert.equal(bindRequenst.totalSupply.eq(new BN('52b7d2dcc80cd2e4000000', 16)), true, "wrong total supply");
        assert.equal(bindRequenst.peggyAmount.eq(new BN('51e410c0f93fe543000000', 16)), true, "wrong peggy amount");
        assert.equal(bindRequenst.contractAddr.toString(), abcToken.address.toString(), "wrong contract address");
        assert.equal(bindRequenst.expireTime.eq(web3.utils.toBN(expireTimeStr)), true, "wrong expire time");
        try {
            await tokenHub.approveBind(abcToken.address, "ABC-9C7", {from: relayer});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("only bep2e owner can approve this bind request"));
        }

        try {
            await tokenHub.approveBind("0x0000000000000000000000000000000000000000", "ABC-9C7", {from: relayer});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("contact address doesn't equal to the contract address in bind request"));
        }

        try {
            await tokenHub.approveBind(abcToken.address, "ABC-9C7", {from: owner});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("allowance doesn't equal to (totalSupply - peggyAmount)"));
        }

        await abcToken.approve(tokenHub.address, new BN('1000000000000000000000000', 10), {from: owner});
        await sleep(10 * 1000);
        // approve expired bind request
        await tokenHub.approveBind(abcToken.address, "ABC-9C7", {from: owner, value: web3.utils.toBN('20000000000000000')});
        bindRequenst = await tokenHub.bindPackageRecord.call("0x4142432d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Reject bind', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        expireTimeStr = "0x" + expireTimeStr;

        const packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x00" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        const packageBytes = RLP.encode([
            "0x00",                                                                //bind type
            "0x4142432d39433700000000000000000000000000000000000000000000000000",  //bep2TokenSymbol
            abcToken.address,                                                      //bep2e contract address
            "0x00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000",  //total supply
            "0x00000000000000000000000000000000000000000051e410c0f93fe543000000",  //peggy amount
            18,                                                                    //decimals
            expireTimeStr]);                                                       //expire time

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        let sequence = 1;

        await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, BIND_CHANNEL_ID, {from: relayer});

        try {
            await tokenHub.rejectBind(abcToken.address, "ABC-9C7", {from: relayer, value: web3.utils.toBN('20000000000000000')});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("only bep2e owner can reject"));
        }

        await tokenHub.rejectBind(abcToken.address, "ABC-9C7", {from: owner, value: web3.utils.toBN('20000000000000000')});

        const bindRequenst = await tokenHub.bindPackageRecord.call("0x4142432d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Expire bind', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        expireTimeStr = "0x" + expireTimeStr;

        const packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x00" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        const packageBytes = RLP.encode([
            "0x00",                                                                //bind type
            "0x4142432d39433700000000000000000000000000000000000000000000000000",  //bep2TokenSymbol
            abcToken.address,                                                      //bep2e contract address
            "0x00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000",  //total supply
            "0x00000000000000000000000000000000000000000051e410c0f93fe543000000",  //peggy amount
            18,                                                                    //decimals
            expireTimeStr]);                                                       //expire time

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        let sequence = 2;

        await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, BIND_CHANNEL_ID, {from: relayer});

        try {
            await tokenHub.expireBind("ABC-9C7", {from: accounts[2], value: web3.utils.toBN('20000000000000000')});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("bind request is not expired"));
        }

        await sleep(10 * 1000);

        await tokenHub.expireBind("ABC-9C7", {from: accounts[2], value: web3.utils.toBN('20000000000000000')});

        bindRequenst = await tokenHub.bindPackageRecord.call("0x4142432d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Mismatched token symbol', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        expireTimeStr = "0x" + expireTimeStr;

        const packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x00" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        const packageBytes = RLP.encode([
            "0x00",                                                                //bind type
            "0x4445462d39433700000000000000000000000000000000000000000000000000",  //bep2TokenSymbol
            abcToken.address,                                                      //bep2e contract address
            "0x00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000",  //total supply
            "0x00000000000000000000000000000000000000000051e410c0f93fe543000000",  //peggy amount
            18,                                                                    //decimals
            expireTimeStr]);                                                       //expire time

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        let sequence = 3;

        await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, BIND_CHANNEL_ID, {from: relayer});

        await tokenHub.approveBind(abcToken.address, "DEF-9C7", {from: owner, value: web3.utils.toBN('20000000000000000')});

        bindRequenst = await tokenHub.bindPackageRecord.call("0x4445462d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Success bind', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        expireTimeStr = "0x" + expireTimeStr;

        const packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x00" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        const packageBytes = RLP.encode([
            "0x00",                                                                //bind type
            "0x4142432d39433700000000000000000000000000000000000000000000000000",  //bep2TokenSymbol
            abcToken.address,                                                      //bep2e contract address
            "0x00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000",  //total supply
            "0x00000000000000000000000000000000000000000051e410c0f93fe543000000",  //peggy amount
            18,                                                                    //decimals
            expireTimeStr]);                                                       //expire time

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        let sequence = 4;

        await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, BIND_CHANNEL_ID, {from: relayer});

        const tx = await tokenHub.approveBind(abcToken.address, "ABC-9C7", {from: owner, value: web3.utils.toBN('20000000000000000')});

        const bep2Symbol = await tokenHub.getBoundBep2Symbol.call(abcToken.address);
        assert.equal(bep2Symbol, "ABC-9C7", "wrong symbol");
        const contractAddr = await tokenHub.getBoundContract.call("ABC-9C7");
        assert.equal(contractAddr, abcToken.address, "wrong contract addr");
    });
    it('Relayer transfer from BC to BSC', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireStrLength = initialExpireStr.length;
        let expireTimeStr = initialExpireStr;
        for (var i = 0; i < 16 - initialExpireStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        expireTimeStr = "0x" + expireTimeStr;

        const packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x00" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        const packageBytes = RLP.encode([
            "0x4142432d39433700000000000000000000000000000000000000000000000000",  //bep2TokenSymbol
            abcToken.address,                                                      //bep2e contract address
            "0x000000000000000000000000000000000000000000000000d71b0fe0a28e0000",  //amount
            accounts[2],                                                           //recipient amount
            "0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48",                          //refund address
            expireTimeStr]);                                                       //expire time

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        let sequence = 0;

        let balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.toNumber(), 0, "wrong balance");

        await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, TRANSFER_IN_CHANNELID, {from: relayer});

        balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.eq(web3.utils.toBN(155e17)), true, "wrong balance");
    });
    it('Expired transfer from BC to BSC', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireStrLength = initialExpireStr.length;
        let expireTimeStr = initialExpireStr;
        for (var i = 0; i < 16 - initialExpireStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        expireTimeStr = "0x" + expireTimeStr;

        const packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x00" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        const packageBytes = RLP.encode([
            "0x4142432d39433700000000000000000000000000000000000000000000000000",  //bep2TokenSymbol
            abcToken.address,                                                      //bep2e contract address
            "0x000000000000000000000000000000000000000000000000d71b0fe0a28e0000",  //amount
            accounts[2],                                                           //recipient amount
            "0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48",                          //refund address
            expireTimeStr]);                                                       //expire time

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        let sequence = 1;

        await sleep(10 * 1000);

        await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, TRANSFER_IN_CHANNELID, {from: relayer});

        let balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.eq(web3.utils.toBN(155e17)), true, "wrong balance");
    });
    it('Relayer BNB transfer from BC to BSC', async () => {
        const tokenHub = await TokenHub.deployed();
        const crossChain = await CrossChain.deployed();
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireStrLength = initialExpireStr.length;
        let expireTimeStr = initialExpireStr;
        for (var i = 0; i < 16 - initialExpireStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        expireTimeStr = "0x" + expireTimeStr;

        const packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x00" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        const packageBytes = RLP.encode([
            "0x424E420000000000000000000000000000000000000000000000000000000000",  //bep2TokenSymbol
            "0x0000000000000000000000000000000000000000",                          //bep2e contract address
            "0x0000000000000000000000000000000000000000000000000DE0B6B3A7640000",  //amount
            accounts[2],                                                           //recipient amount
            "0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48",                          //refund address
            expireTimeStr]);                                                       //expire time

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        let sequence = 2;

        const initBalance = await web3.eth.getBalance(accounts[2]);

        await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, TRANSFER_IN_CHANNELID, {from: relayer});

        const newBalance = await web3.eth.getBalance(accounts[2]);

        assert.equal(web3.utils.toBN(newBalance).sub(web3.utils.toBN(initBalance)).eq(web3.utils.toBN(1e18)), true, "wrong balance");
    });
    it('Transfer from BSC to BC', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const defToken = await DEFToken.deployed();

        const sender = accounts[2];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let expireTime = timestamp + 150; // expire at two minutes later
        const recipient = "0xd719dDfA57bb1489A08DF33BDE4D5BA0A9998C60";
        const amount = web3.utils.toBN(1e11);
        const relayFee = web3.utils.toBN(2e16);

        try {
            await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, {from: sender, value: relayFee});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("BEP2E: transfer amount exceeds allowance"));
        }

        try {
            const amount = web3.utils.toBN(1e8);
            await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, {from: sender, value: relayFee});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("invalid transfer amount"));
        }

        try {
            const relayFee = web3.utils.toBN(1e16).add(web3.utils.toBN(1));
            await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, {from: sender, value: relayFee});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("received BNB amount doesn't equal to relayFee"));
        }

        try {
            await tokenHub.transferOut(defToken.address, recipient, amount, expireTime, {from: sender, value: relayFee});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("the contract has not been bound to any bep2 token"));
        }

        await abcToken.approve(tokenHub.address, amount, {from: sender});
        try {
            await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, {from: sender});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("received BNB amount doesn't equal to relayFee"));
        }
        await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, {from: sender, value: relayFee});

        let balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.eq(web3.utils.toBN(155e17).sub(amount)), true, "wrong balance");
    });
    it('Relay refund package', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const relayer = accounts[1];
        const refundAddr = accounts[2];

        const packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x01" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        const packageBytes = RLP.encode([
            abcToken.address,                                                       //bep2e contract address
            ["0x000000000000000000000000000000000000000000000000000000174876E800"], //amount
            [refundAddr],                                                           //refund address
            1]);                                                                    //status

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        let sequence = 0;

        const amount = web3.utils.toBN(1e11);
        let balance = await abcToken.balanceOf.call(refundAddr);
        assert.equal(balance.eq(web3.utils.toBN(155e17).sub(amount)), true, "wrong balance");

        await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, TRANSFER_OUT_CHANNELID, {from: relayer});

        balance = await abcToken.balanceOf.call(refundAddr);
        assert.equal(balance.eq(web3.utils.toBN(155e17)), true, "wrong balance");
    });
    it('Batch transfer out', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const sender = accounts[0];

        const recipientAddrs = ["0x37b8516a0f88e65d677229b402ec6c1e0e333004", "0xfa5e36a04eef3152092099f352ddbe88953bb540"];
        let amounts = [web3.utils.toBN(1e16), web3.utils.toBN(2e16)];
        const refundAddrs = ["0x37b8516a0f88e65d677229b402ec6c1e0e333004", "0xfa5e36a04eef3152092099f352ddbe88953bb540"];

        let timestamp = Math.floor(Date.now() / 1000);
        let expireTime = (timestamp + 150);
        const relayFee = web3.utils.toBN(4e16);

        let tx = await tokenHub.batchTransferOutBNB(recipientAddrs, amounts, refundAddrs, expireTime, {from: sender, value: web3.utils.toBN(7e16)});
        assert.equal(tx.receipt.status, true, "failed transaction");
    });
    it('Bind malicious BEP2E token', async () => {
        const maliciousToken = await MaliciousToken.deployed();
        const tokenHub = await TokenHub.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        let initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        expireTimeStr = "0x" + expireTimeStr;

        let packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x00" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        let packageBytes = RLP.encode([
            "0x00",                                                               //bind type
            "0x4d414c4943494f552d4130390000000000000000000000000000000000000000", //bep2TokenSymbol
            maliciousToken.address,                                               //bep2e contract address
            "0x00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000", //total supply
            "0x00000000000000000000000000000000000000000051e410c0f93fe543000000", //peggy amount
            18,                                                                   //decimals
            expireTimeStr]);

        let proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        let sequence = 5;

        let tx = await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, BIND_CHANNEL_ID, {from: relayer});
        assert.equal(tx.receipt.status, true, "failed transaction");

        await maliciousToken.approve(tokenHub.address, web3.utils.toBN('1000000000000000000000000'), {from: owner});
        await tokenHub.approveBind(maliciousToken.address, "MALICIOU-A09", {from: owner, value: web3.utils.toBN(2e16)});

        const bep2Symbol = await tokenHub.getBoundBep2Symbol.call(maliciousToken.address);
        assert.equal(bep2Symbol, "MALICIOU-A09", "wrong symbol");

        timestamp = Math.floor(Date.now() / 1000); // counted by second
        initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        initialExpireTimeStrLength = initialExpireTimeStr.length;
        expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        expireTimeStr = "0x" + expireTimeStr;

        packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x00" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        packageBytes = RLP.encode([
            "0x4d414c4943494f552d4130390000000000000000000000000000000000000000",  //bep2TokenSymbol
            maliciousToken.address,                                                //bep2e contract address
            "000000000000000000000000000000000000000000000000d71b0fe0a28e0000",    //amount
            accounts[2],                                                           //recipient amount
            "0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48",                          //refund address
            expireTimeStr]);

        proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        sequence = 3;

        let balance = await maliciousToken.balanceOf.call(accounts[2]);
        assert.equal(balance.toNumber(), 0, "wrong balance");

        tx = await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, TRANSFER_IN_CHANNELID, {from: relayer});
        assert.equal(tx.receipt.status, true, "failed transaction");

        packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x01" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        packageBytes = RLP.encode([
            maliciousToken.address,                                                 //bep2TokenSymbol
            ["0x000000000000000000000000000000000000000000000000000000174876E800"], //amount
            ["0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48"],                         //refund address
            1]);                                                                    //refund address

        proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        sequence = 1;

        tx = await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, TRANSFER_OUT_CHANNELID, {from: relayer});
        assert.equal(tx.receipt.status, true, "failed transaction");
    });
    it('Uint256 overflow in transferOut and batchTransferOutBNB', async () => {
        const tokenHub = await TokenHub.deployed();

        const sender = accounts[2];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let expireTime = timestamp + 150; // expire at two minutes later
        let recipient = "0xd719dDfA57bb1489A08DF33BDE4D5BA0A9998C60";
        let amount = web3.utils.toBN("115792089237316195423570985008687907853269984665640564039457584007910000000000");
        let relayFee = web3.utils.toBN("20000000000000000");

        try {
            await tokenHub.transferOut("0x0000000000000000000000000000000000000000", recipient, amount, expireTime, {from: sender, value: web3.utils.toBN("19999996870360064")});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("SafeMath: addition overflow"));
        }

        const recipientAddrs = ["0x37b8516a0f88e65d677229b402ec6c1e0e333004", "0xfa5e36a04eef3152092099f352ddbe88953bb540"];
        let amounts = [web3.utils.toBN("100000000000000000000000000000000000000000000000000000000000000000000000000000"), web3.utils.toBN("15792089237316195423570985008687907853269984665640564039457584007910000000000")];
        const refundAddrs = ["0x37b8516a0f88e65d677229b402ec6c1e0e333004", "0xfa5e36a04eef3152092099f352ddbe88953bb540"];

        timestamp = Math.floor(Date.now() / 1000);
        expireTime = (timestamp + 150);
        relayFee = web3.utils.toBN(4e16);

        try {
            await tokenHub.batchTransferOutBNB(recipientAddrs, amounts, refundAddrs, expireTime, {from: sender, value: web3.utils.toBN("39999996870360064")});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("SafeMath: addition overflow"));
        }
    });
    it('Unbind Token', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const relayer = accounts[1];

        let packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x00" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        let packageBytes = RLP.encode([
            "0x01",                                                                //bind type
            "0x4142432d39433700000000000000000000000000000000000000000000000000",  //bep2TokenSymbol
            "0x0000000000000000000000000000000000000000",                          //bep2e contract address
            "0x0000000000000000000000000000000000000000000000000000000000000000",  //total supply
            "0x0000000000000000000000000000000000000000000000000000000000000000",  //peggy amount
            0,                                                                     //decimals
            0]);                                                                   //expire time

        let proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        let sequence = 6;

        let tx = await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, BIND_CHANNEL_ID, {from: relayer});
        assert.equal(tx.receipt.status, true, "failed transaction");

        const bep2Symbol = await tokenHub.getBoundBep2Symbol.call(abcToken.address);
        assert.equal(bep2Symbol, "", "wrong symbol");
        const contractAddr = await tokenHub.getBoundContract.call("ABC-9C7");
        assert.equal(contractAddr, "0x0000000000000000000000000000000000000000", "wrong contract addr");

        // transferIn should be failed and emit LogTransferInFailureUnboundToken to trigger refund
        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireStrLength = initialExpireStr.length;
        let expireTimeStr = initialExpireStr;
        for (var i = 0; i < 16 - initialExpireStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        expireTimeStr = "0x" + expireTimeStr;

        packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x00" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        packageBytes = RLP.encode([
            "0x4142432d39433700000000000000000000000000000000000000000000000000",  //bep2TokenSymbol
            abcToken.address,                                                      //bep2e contract address
            "0000000000000000000000000000000000000000000000000DE0B6B3A7640000",    //amount
            accounts[2],                                                           //recipient amount
            "0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48",                          //refund address
            expireTimeStr]);                                                       //expire time

        proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        sequence = 4;

        tx = await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, TRANSFER_IN_CHANNELID, {from: relayer});
        assert.equal(tx.receipt.status, true, "failed transaction");

        // refund should be successful
        const refundAddr = accounts[2];

        packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x01" +
            "000000000000000000000000000000000000000000000000002386F26FC10000"
        ));

        packageBytes = RLP.encode([
            abcToken.address,                                                       //bep2TokenSymbol
            ["0x0000000000000000000000000000000000000000000000000DE0B6B3A7640000"], //amount
            [refundAddr],                                                           //refund address
            1]);                                                                    //refund address

        proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        sequence = 2;

        let beforeRefundBalance = await abcToken.balanceOf.call(refundAddr);

        tx = await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, sequence, TRANSFER_OUT_CHANNELID, {from: relayer});
        assert.equal(tx.receipt.status, true, "failed transaction");

        let afterRefundBalance = await abcToken.balanceOf.call(refundAddr);
        assert.equal(afterRefundBalance.sub(beforeRefundBalance).eq(web3.utils.toBN(1e18)), true, "wrong balance");

        // transferOut should be failed
        const sender = accounts[2];
        timestamp = Math.floor(Date.now() / 1000); // counted by second
        let expireTime = timestamp + 150; // expire at two minutes later
        const recipient = "0xd719dDfA57bb1489A08DF33BDE4D5BA0A9998C60";
        const amount = web3.utils.toBN(1e11);
        const relayFee = web3.utils.toBN(2e16);
        await abcToken.approve(tokenHub.address, amount, {from: sender});
        try {
            await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, {from: sender, value: relayFee});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("the contract has not been bound to any bep2 token"));
        }
    });
});
