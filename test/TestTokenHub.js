const BN = require('bn.js');
const sleep = require("await-sleep");
const InputDataDecoder = require('ethereum-input-data-decoder');

const SystemReward = artifacts.require("SystemReward");
const RelayerIncentivize = artifacts.require("RelayerIncentivize");
//const TendermintLightClient = artifacts.require("TendermintLightClient");
const MockLightClient = artifacts.require("mock/MockLightClient");
const TokenHub = artifacts.require("TokenHub");
const ABCToken = artifacts.require("ABCToken");
const DEFToken = artifacts.require("DEFToken");
const MaliciousToken = artifacts.require("test/MaliciousToken");
const RelayerHub = artifacts.require("RelayerHub");

const crypto = require('crypto');
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

const merkleHeight = 100;

contract('TokenHub', (accounts) => {
    it('Init TokenHub', async () => {
        const tokenHub = await TokenHub.deployed();
        let balance_wei = await web3.eth.getBalance(tokenHub.address);
        assert.equal(balance_wei, 10e18, "wrong balance");
        const _lightClientContract = await tokenHub.LIGHT_CLIENT_ADDR.call();
        assert.equal(_lightClientContract, MockLightClient.address, "wrong tendermint light client contract address");

        const systemReward = await SystemReward.deployed();
        const isOperator = await systemReward.isOperator.call(tokenHub.address);
        assert.equal(isOperator, true, "failed to grant system reward authority to tokenhub contract");

        const relayer = accounts[1];
        const relayerInstance = await RelayerHub.deployed();
        await relayerInstance.register({from: relayer, value: 1e20});
        let res = await relayerInstance.isRelayer.call(relayer);
        assert.equal(res,true);
    });
    it('Relay expired bind package', async () => {
        const mockLightClient = await MockLightClient.deployed();
        const abcToken = await ABCToken.deployed();
        const tokenHub = await TokenHub.deployed();

        await mockLightClient.setBlockNotSynced(false);

        const owner = accounts[0];
        const relayer = accounts[1];
        let bindChannelSequence = await tokenHub.bindChannelSequence.call();
        assert.equal(bindChannelSequence.toNumber(), 0, "wrong bind channel sequence");
        
        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4142432d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol
            abcToken.address.toString().replace("0x", "") +      // BEP2E contract address
            "00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000" +        // total supply
            "00000000000000000000000000000000000000000051e410c0f93fe543000000" +        // peggy amount
            "12" +                                                                      // 18 decimals
            expireTimeStr +                                                              // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        await tokenHub.handleBindPackage(value, proof, merkleHeight, 0,  {from: relayer});

        bindChannelSequence = await tokenHub.bindChannelSequence.call();
        assert.equal(bindChannelSequence.toNumber(), 1, "wrong bind channel sequence");

        let bindRequenst = await tokenHub.bindPackageRecord.call("0x4142432d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x4142432d39433700000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
        assert.equal(bindRequenst.totalSupply.eq(new BN('52b7d2dcc80cd2e4000000', 16)), true, "wrong total supply");
        assert.equal(bindRequenst.peggyAmount.eq(new BN('51e410c0f93fe543000000', 16)), true, "wrong peggy amount");
        assert.equal(bindRequenst.contractAddr.toString(), abcToken.address.toString(), "wrong contract address");
        assert.equal(bindRequenst.expireTime.eq(web3.utils.toBN(expireTimeStr)), true, "wrong expire time");
        assert.equal(bindRequenst.relayFee.eq(web3.utils.toBN(1e16)), true, "wrong relayFee");
        try {
            await tokenHub.approveBind(abcToken.address, "ABC-9C7", {from: relayer})
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("only bep2e owner can approve this bind request"));
        }

        try {
            await tokenHub.approveBind("0x0000000000000000000000000000000000000000", "ABC-9C7", {from: relayer})
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("contact address doesn't equal to the contract address in bind request"));
        }

        try {
            await tokenHub.approveBind(abcToken.address, "ABC-9C7", {from: owner})
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("allowance doesn't equal to (totalSupply - peggyAmount)"));
        }

        await abcToken.approve(tokenHub.address, new BN('1000000000000000000000000', 10), {from: owner});
        await sleep(10 * 1000);
        // approve expired bind request
        await tokenHub.approveBind(abcToken.address, "ABC-9C7", {from: owner});
        bindRequenst = await tokenHub.bindPackageRecord.call("0x4142432d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Reject bind', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4142432d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol
            abcToken.address.toString().replace("0x", "") +      // BEP2E contract address
            "00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000" +        // total supply
            "00000000000000000000000000000000000000000051e410c0f93fe543000000" +        // peggy amount
            "12" +                                                                      // 18 decimals
            expireTimeStr +                                                              // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee
        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        await tokenHub.handleBindPackage(value, proof, merkleHeight, 1, {from: relayer});

        const bindChannelSequence = await tokenHub.bindChannelSequence.call();
        assert.equal(bindChannelSequence.toNumber(), 2, "wrong bind channel sequence");

        try {
            await tokenHub.rejectBind(abcToken.address, "ABC-9C7", {from: relayer});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("only bep2e owner can reject"));
        }

        await tokenHub.rejectBind(abcToken.address, "ABC-9C7", {from: owner});

        const bindRequenst = await tokenHub.bindPackageRecord.call("0x4142432d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Expire bind', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4142432d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol
            abcToken.address.toString().replace("0x", "") +      // BEP2E contract address
            "00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000" +        // total supply
            "00000000000000000000000000000000000000000051e410c0f93fe543000000" +        // peggy amount
            "12" +                                                                      // 18 decimals
            expireTimeStr +                                                              // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee
        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        await tokenHub.handleBindPackage(value, proof, merkleHeight, 2, {from: relayer});

        const bindChannelSequence = await tokenHub.bindChannelSequence.call();
        assert.equal(bindChannelSequence.toNumber(), 3, "wrong bind channel sequence");

        try {
            await tokenHub.expireBind("ABC-9C7", {from: accounts[2]});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("bind request is not expired"));
        }

        await sleep(10 * 1000);

        await tokenHub.expireBind("ABC-9C7", {from: accounts[2]});

        bindRequenst = await tokenHub.bindPackageRecord.call("0x4142432d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Mismatched token symbol', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4445462d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol, symbol: DEF-9C7
            abcToken.address.toString().replace("0x", "") +      // BEP2E contract address
            "00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000" +        // total supply
            "00000000000000000000000000000000000000000051e410c0f93fe543000000" +        // peggy amount
            "12" +                                                                      // 18 decimals
            expireTimeStr +                                                              // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee
        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        await tokenHub.handleBindPackage(value, proof, merkleHeight, 3, {from: relayer});

        const bindChannelSequence = await tokenHub.bindChannelSequence.call();
        assert.equal(bindChannelSequence.toNumber(), 4, "wrong bind channel sequence");

        let tx = await tokenHub.approveBind(abcToken.address, "DEF-9C7", {from: owner});
        truffleAssert.eventEmitted(tx, "LogBindInvalidParameter", (ev) => {
            return ev.bep2TokenSymbol === "0x4445462d39433700000000000000000000000000000000000000000000000000";
        });

        bindRequenst = await tokenHub.bindPackageRecord.call("0x4445462d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Success bind', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4142432d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol
            abcToken.address.toString().replace("0x", "") +      // BEP2E contract address
            "00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000" +        // total supply
            "00000000000000000000000000000000000000000051e410c0f93fe543000000" +        // peggy amount
            "12" +                                                                      // 18 decimals
            expireTimeStr +                                                              // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        await tokenHub.handleBindPackage(value, proof, merkleHeight, 4, {from: relayer});

        const bindChannelSequence = await tokenHub.bindChannelSequence.call();
        assert.equal(bindChannelSequence.toNumber(), 5, "wrong bind channel sequence");

        await tokenHub.approveBind(abcToken.address, "ABC-9C7", {from: owner});

        const bep2Symbol = await tokenHub.getBoundBep2Symbol.call(abcToken.address);
        assert.equal(bep2Symbol, "ABC-9C7", "wrong symbol");
        const contractAddr = await tokenHub.getBoundContract.call("ABC-9C7");
        assert.equal(contractAddr, abcToken.address, "wrong contract addr");
    });
    it('Relayer transfer from BC to BSC', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireStrLength = initialExpireStr.length;
        let expireTimeStr = initialExpireStr;
        for (var i = 0; i < 16 - initialExpireStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }
        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4142432d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol
            abcToken.address.toString().replace("0x", "") +      // BEP2E contract address
            "35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48" +                                // refund address
            accounts[2].toString().replace("0x", "") +                                  // recipient amount
            "000000000000000000000000000000000000000000000000d71b0fe0a28e0000" +        // amount
            expireTimeStr +                                                             // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        let balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.toNumber(), 0, "wrong balance");

        await tokenHub.handleTransferInPackage(value, proof, merkleHeight, 0, {from: relayer});

        const transferInChannelSequence = await tokenHub.transferInChannelSequence.call();
        assert.equal(transferInChannelSequence.toNumber(), 1, "wrong transfer in channel sequence");

        balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.eq(web3.utils.toBN(155e17)), true, "wrong balance");
    });
    it('Expired transfer from BC to BSC', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireStrLength = initialExpireStr.length;
        let expireTimeStr = initialExpireStr;
        for (var i = 0; i < 16 - initialExpireStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }
        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4142432d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol
            abcToken.address.toString().replace("0x", "") +      // BEP2E contract address
            "35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48" +                                // refund address
            accounts[2].toString().replace("0x", "") +                                  // recipient amount
            "000000000000000000000000000000000000000000000000d71b0fe0a28e0000" +        // amount
            expireTimeStr +                                                             // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        await sleep(10 * 1000);
        const tx = await tokenHub.handleTransferInPackage(value, proof, merkleHeight, 1, {from: relayer});
        truffleAssert.eventEmitted(tx, "LogTransferInFailureTimeout", (ev) => {
            return ev.bep2TokenSymbol === "0x4142432d39433700000000000000000000000000000000000000000000000000" && ev.bep2TokenAmount.toNumber() === 1550000000;
        });
        const transferInChannelSequence = await tokenHub.transferInChannelSequence.call();
        assert.equal(transferInChannelSequence.toNumber(), 2, "wrong transfer in channel sequence");

        let balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.eq(web3.utils.toBN(155e17)), true, "wrong balance");
    });
    it('Relayer BNB transfer from BC to BSC', async () => {
        const tokenHub = await TokenHub.deployed();

        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireStrLength = initialExpireStr.length;
        let expireTimeStr = initialExpireStr;
        for (var i = 0; i < 16 - initialExpireStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }
        const value = Buffer.from(web3.utils.hexToBytes(
            "0x424E420000000000000000000000000000000000000000000000000000000000" + // native token BNB
            "0000000000000000000000000000000000000000" +                                // zero contract address
            "35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48" +                                // refund address
            accounts[2].toString().replace("0x", "") +                                  // recipient amount
            "0000000000000000000000000000000000000000000000000DE0B6B3A7640000" +        // amount 1e18
            expireTimeStr +                                                             // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        const initBalance = await web3.eth.getBalance(accounts[2]);
        const tx = await tokenHub.handleTransferInPackage(value, proof, merkleHeight, 2, {from: relayer});
        const newBalance = await web3.eth.getBalance(accounts[2]);

        const transferInChannelSequence = await tokenHub.transferInChannelSequence.call();
        assert.equal(transferInChannelSequence.toNumber(), 3, "wrong transfer in channel sequence");
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
        const relayFee = web3.utils.toBN(1e16);

        try {
            await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, relayFee, {from: sender, value: relayFee});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("BEP2E: transfer amount exceeds allowance"));
        }

        try {
            const amount = web3.utils.toBN(1e8);
            await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, relayFee, {from: sender, value: relayFee});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("invalid transfer amount"));
        }

        try {
            const relayFee = web3.utils.toBN(1e16).add(web3.utils.toBN(1));
            await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, relayFee, {from: sender, value: relayFee});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("relayFee is must be N*1e10"));
        }

        try {
            await tokenHub.transferOut(defToken.address, recipient, amount, expireTime, relayFee, {from: sender, value: relayFee});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("the contract has not been bind to any bep2 token"));
        }

        await abcToken.approve(tokenHub.address, amount, {from: sender});
        try {
            await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, relayFee, {from: sender});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("received BNB amount doesn't equal to relayFee"));
        }
        const tx = await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, relayFee, {from: sender, value: relayFee});
        truffleAssert.eventEmitted(tx, "LogTransferOut", (ev) => {
            return ev.bep2TokenSymbol === "0x4142432d39433700000000000000000000000000000000000000000000000000";
        });
        const transferOutChannelSequence = await tokenHub.transferOutChannelSequence.call();
        assert.equal(transferOutChannelSequence.toNumber(), 1, "wrong transfer out channel sequence");

        let balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.eq(web3.utils.toBN(155e17).sub(amount)), true, "wrong balance");
    });
    it('Relay refund package', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const relayer = accounts[1];
        const refundAddr = accounts[2];

        const value = Buffer.from(web3.utils.hexToBytes(
            "0x000000000000000000000000000000000000000000000000000000174876E800" + // refund amount
            abcToken.address.toString().replace("0x", "") +      // BEP2E contract address
            refundAddr.toString().replace("0x", "")  +           // refund address
            "0000000000000001"  +                                                       // transferOutSequenceBSC
            "0000")                                                                     // failureCode, timeout
        );
        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        const amount = web3.utils.toBN(1e11);

        let balance = await abcToken.balanceOf.call(refundAddr);
        assert.equal(balance.eq(web3.utils.toBN(155e17).sub(amount)), true, "wrong balance");

        const tx = await tokenHub.handleRefundPackage( value, proof, merkleHeight, 0, {from: relayer});
        truffleAssert.eventEmitted(tx, "LogRefundSuccess", (ev) => {
            return ev.reason.toNumber() === 0x0;
        });

        balance = await abcToken.balanceOf.call(refundAddr);
        assert.equal(balance.eq(web3.utils.toBN(155e17)), true, "wrong balance");
    });
    it('Batch transfer out', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const sender = accounts[0];

        const recipientAddrs = ["0x37b8516a0f88e65d677229b402ec6c1e0e333004", "0xfa5e36a04eef3152092099f352ddbe88953bb540"];
        let amounts = [web3.utils.toBN(1e11), web3.utils.toBN(2e11)];
        const refundAddrs = ["0x37b8516a0f88e65d677229b402ec6c1e0e333004", "0xfa5e36a04eef3152092099f352ddbe88953bb540"];

        let timestamp = Math.floor(Date.now() / 1000);
        let expireTime = (timestamp + 150);
        const relayFee = web3.utils.toBN(2e16);

        await abcToken.approve(tokenHub.address, web3.utils.toBN(3e11), {from: sender});
        let tx = await tokenHub.batchTransferOut(recipientAddrs, amounts, refundAddrs, abcToken.address, expireTime, relayFee, {from: sender, value: relayFee});
        truffleAssert.eventEmitted(tx, "LogBatchTransferOut", (ev) => {
            return ev.transferOutSequenceBSC.toNumber() === 1 &&
                ev.contractAddr === abcToken.address &&
                ev.amounts[0].eq(amounts[0].div(web3.utils.toBN(1e10))) &&
                ev.amounts[1].eq(amounts[1].div(web3.utils.toBN(1e10)));
        });
        let txData = await web3.eth.getTransaction(tx.tx);

        amounts = [web3.utils.toBN(3e11), web3.utils.toBN(4e11)];
        await abcToken.approve(tokenHub.address, web3.utils.toBN(7e11), {from: sender});
        tx = await tokenHub.batchTransferOut(recipientAddrs, amounts, refundAddrs, abcToken.address, expireTime, relayFee, {from: sender, value: relayFee});
        truffleAssert.eventEmitted(tx, "LogBatchTransferOut", (ev) => {
            return ev.transferOutSequenceBSC.toNumber() === 2 &&
                ev.contractAddr === abcToken.address &&
                ev.amounts[0].eq(amounts[0].div(web3.utils.toBN(1e10))) &&
                ev.amounts[1].eq(amounts[1].div(web3.utils.toBN(1e10)));
        });
        truffleAssert.eventEmitted(tx, "LogBatchTransferOutAddrs", (ev) => {
            return ev.transferOutSequenceBSC.toNumber() === 2 &&
                ev.recipientAddrs[0].toString().toLowerCase() === recipientAddrs[0] &&
                ev.recipientAddrs[1].toString().toLowerCase() === recipientAddrs[1];
        });
    });
    it('Bind malicious BEP2E token', async () => {
        const maliciousToken = await MaliciousToken.deployed();
        const tokenHub = await TokenHub.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        let initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }
        let value = Buffer.from(web3.utils.hexToBytes(
            "0x4d414c4943494f552d4130390000000000000000000000000000000000000000" + // bep2TokenSymbol: MALICIOU-A09
            maliciousToken.address.toString().replace("0x", "") +// BEP2E contract address
            "00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000" +        // total supply
            "00000000000000000000000000000000000000000051e410c0f93fe543000000" +        // peggy amount
            "12" +                                                                      // 18 decimals
            expireTimeStr +                                                             // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee
        let proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        await tokenHub.handleBindPackage(value, proof, merkleHeight, 5, {from: relayer});

        const bindChannelSequence = await tokenHub.bindChannelSequence.call();
        assert.equal(bindChannelSequence.toNumber(), 6, "wrong bind channel sequence");

        await maliciousToken.approve(tokenHub.address, new BN('1000000000000000000000000', 10), {from: owner});

        let tx = await tokenHub.approveBind(maliciousToken.address, "MALICIOU-A09", {from: owner});

        truffleAssert.eventEmitted(tx, "LogBindSuccess", (ev) => {
            return ev.bep2TokenSymbol === "0x4d414c4943494f552d4130390000000000000000000000000000000000000000";
        });

        timestamp = Math.floor(Date.now() / 1000); // counted by second
        initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        initialExpireTimeStrLength = initialExpireTimeStr.length;
        expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }
        value = Buffer.from(web3.utils.hexToBytes(
            "0x4d414c4943494f552d4130390000000000000000000000000000000000000000" + // bep2TokenSymbol
            maliciousToken.address.toString().replace("0x", "") +// BEP2E contract address
            "35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48" +                                // refund address
            accounts[2].toString().replace("0x", "") +                                  // recipient amount
            "000000000000000000000000000000000000000000000000d71b0fe0a28e0000" +        // amount
            expireTimeStr +                                                             // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee
        proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        let balance = await maliciousToken.balanceOf.call(accounts[2]);
        assert.equal(balance.toNumber(), 0, "wrong balance");

        let transferInChannelSequence = await tokenHub.transferInChannelSequence.call();
        assert.equal(transferInChannelSequence.toNumber(), 3, "wrong transfer in channel sequence");

        tx = await tokenHub.handleTransferInPackage(value, proof, merkleHeight, 3, {from: relayer});
        truffleAssert.eventEmitted(tx, "LogUnexpectedRevertInBEP2E", (ev) => {
            return ev.contractAddr === maliciousToken.address && ev.reason === "malicious method";
        });
        transferInChannelSequence = await tokenHub.transferInChannelSequence.call();
        assert.equal(transferInChannelSequence.toNumber(), 4, "wrong transfer in channel sequence");

        value = Buffer.from(web3.utils.hexToBytes(
            "0x000000000000000000000000000000000000000000000000000000174876E800" +      // refund amount
            maliciousToken.address.toString().replace("0x", "") +     // BEP2E contract address
            "35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48"  +                                    // refund address
            "0000000000000001"  +                                                            // transferOutSequenceBSC
            "0000")                                                                          // failureCode, timeout
        );
        proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        let refundChannelSequence = await tokenHub.refundChannelSequence.call();
        assert.equal(refundChannelSequence.toNumber(), 1, "wrong refund channel sequence");

        tx = await tokenHub.handleRefundPackage(value, proof, merkleHeight, 1, {from: relayer});
        truffleAssert.eventEmitted(tx, "LogUnexpectedRevertInBEP2E", (ev) => {
            return ev.contractAddr === maliciousToken.address && ev.reason === "malicious method";
        });

        refundChannelSequence = await tokenHub.refundChannelSequence.call();
        assert.equal(refundChannelSequence.toNumber(), 2, "wrong refund channel sequence");
    });
    it('Uint256 overflow in transferOut and batchTransferOut', async () => {
        const tokenHub = await TokenHub.deployed();

        const sender = accounts[2];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let expireTime = timestamp + 150; // expire at two minutes later
        let recipient = "0xd719dDfA57bb1489A08DF33BDE4D5BA0A9998C60";
        let amount = web3.utils.toBN("115792089237316195423570985008687907853269984665640564039457584007910000000000");
        let relayFee = web3.utils.toBN("10000000000000000");

        try {
            await tokenHub.transferOut("0x0000000000000000000000000000000000000000", recipient, amount, expireTime, relayFee, {from: sender, value: web3.utils.toBN("9999996870360064")});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("SafeMath: addition overflow"));
        }

        const recipientAddrs = ["0x37b8516a0f88e65d677229b402ec6c1e0e333004", "0xfa5e36a04eef3152092099f352ddbe88953bb540"];
        let amounts = [web3.utils.toBN("100000000000000000000000000000000000000000000000000000000000000000000000000000"), web3.utils.toBN("15792089237316195423570985008687907853269984665640564039457584007910000000000")];
        const refundAddrs = ["0x37b8516a0f88e65d677229b402ec6c1e0e333004", "0xfa5e36a04eef3152092099f352ddbe88953bb540"];

        timestamp = Math.floor(Date.now() / 1000);
        expireTime = (timestamp + 150);
        relayFee = web3.utils.toBN(2e16);

        try {
            await tokenHub.batchTransferOut(recipientAddrs, amounts, refundAddrs, "0x0000000000000000000000000000000000000000", expireTime, relayFee, {from: sender, value: web3.utils.toBN("19999996870360064")});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("SafeMath: addition overflow"));
        }
    });
});
