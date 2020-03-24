const BN = require('bn.js');
const sleep = require("await-sleep");
const InputDataDecoder = require('ethereum-input-data-decoder');

const SystemReward = artifacts.require("SystemReward");
const HeaderRelayerIncentivize = artifacts.require("HeaderRelayerIncentivize");
const TransferRelayerIncentivize = artifacts.require("TransferRelayerIncentivize");
//const TendermintLightClient = artifacts.require("TendermintLightClient");
const MockLightClient = artifacts.require("mock/MockLightClient");
const TokenHub = artifacts.require("TokenHub");
const ABCToken = artifacts.require("ABCToken");
const DEFToken = artifacts.require("DEFToken");

const crypto = require('crypto');
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

const crossChainKeyPrefix = "0x00";
const sourceChainID = "0003";
const destChainID = "000f";

const bindChannelID = "01";
const transferChannelID = "02";
const refundChannelID = "03";

const minimumRelayFee = 1e12;
const refundRelayReward = 1e12;

const merkleHeight = 100;

contract('TokenHub', (accounts) => {
    it('Init TokenHub', async () => {
        const tokenHub = await TokenHub.deployed();
        await tokenHub.initTokenHub(
            SystemReward.address, 
            MockLightClient.address, 
            HeaderRelayerIncentivize.address, 
            TransferRelayerIncentivize.address,
            parseInt("0x"+sourceChainID, 16),
            parseInt("0x"+destChainID, 16),
            minimumRelayFee,
            refundRelayReward,
            {
                from: accounts[0],
                value: 10e18
            }
        );

        let balance_wei = await web3.eth.getBalance(tokenHub.address);
        assert.equal(balance_wei, 10e18, "wrong balance");
        const _lightClientContract = await tokenHub._lightClientContract.call();
        assert.equal(_lightClientContract, MockLightClient.address, "wrong tendermint light client contract address");

        const systemReward = await SystemReward.deployed();
        const isOperator = await systemReward.isOperator.call(tokenHub.address);
        assert.equal(isOperator, true, "failed to grant system reward authority to tokenhub contract");
    });
    it('Relay expired bind package', async () => {
        const mockLightClient = await MockLightClient.deployed();
        const abcToken = await ABCToken.deployed();
        const tokenHub = await TokenHub.deployed();

        await mockLightClient.setBlockNotSynced(false);

        const owner = accounts[0];
        const relayer = accounts[1];
        let _bindChannelSequence = await tokenHub._bindChannelSequence.call();
        assert.equal(_bindChannelSequence.toNumber(), 0, "wrong bind channel sequence");

        const key = Buffer.from(web3.utils.hexToBytes(
            crossChainKeyPrefix + 
            sourceChainID +
            destChainID +
            bindChannelID +
            "0000000000000000"));

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4142432d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol
            abcToken.address.toString().replace("0x", "") +      // erc20 contract address
            "00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000" +        // total supply
            "00000000000000000000000000000000000000000051e410c0f93fe543000000" +        // peggy amount
            expireTimeStr +                                                              // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        await tokenHub.handleBindPackage(merkleHeight, key, value, proof, {from: relayer});

        _bindChannelSequence = await tokenHub._bindChannelSequence.call();
        assert.equal(_bindChannelSequence.toNumber(), 1, "wrong bind channel sequence");

        let bindRequenst = await tokenHub._bindPackageRecord.call("0x4142432d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x4142432d39433700000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
        assert.equal(bindRequenst.totalSupply.eq(new BN('52b7d2dcc80cd2e4000000', 16)), true, "wrong total supply");
        assert.equal(bindRequenst.peggyAmount.eq(new BN('51e410c0f93fe543000000', 16)), true, "wrong peggy amount");
        assert.equal(bindRequenst.contractAddr.toString(), abcToken.address.toString(), "wrong contract address");
        assert.equal(bindRequenst.expireTime.eq(web3.utils.toBN(expireTimeStr)), true, "wrong expire time");
        assert.equal(bindRequenst.relayFee.eq(web3.utils.toBN(1e16)), true, "wrong relayFee");
        try {
            await tokenHub.approveBind(abcToken.address, "0x4142432d39433700000000000000000000000000000000000000000000000000", {from: relayer})
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("only erc20 owner can approve this bind request"));
        }

        try {
            await tokenHub.approveBind("0x0000000000000000000000000000000000000000", "0x4142432d39433700000000000000000000000000000000000000000000000000", {from: relayer})
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("contact address doesn't equal to the contract address in bind request"));
        }

        try {
            await tokenHub.approveBind(abcToken.address, "0x4142432d39433700000000000000000000000000000000000000000000000000", {from: owner})
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("allowance doesn't equal to (totalSupply - peggyAmount)"));
        }

        await abcToken.approve(tokenHub.address, new BN('1000000000000000000000000', 10), {from: owner});
        await sleep(10 * 1000);
        // approve expired bind request
        await tokenHub.approveBind(abcToken.address, "0x4142432d39433700000000000000000000000000000000000000000000000000", {from: owner});
        bindRequenst = await tokenHub._bindPackageRecord.call("0x4142432d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Reject bind', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        const key = Buffer.from(web3.utils.hexToBytes("0x000003000f010000000000000001"));

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4142432d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol
            abcToken.address.toString().replace("0x", "") +      // erc20 contract address
            "00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000" +        // total supply
            "00000000000000000000000000000000000000000051e410c0f93fe543000000" +        // peggy amount
            expireTimeStr +                                                              // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee
        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
        await tokenHub.handleBindPackage(merkleHeight, key, value, proof, {from: relayer});

        const _bindChannelSequence = await tokenHub._bindChannelSequence.call();
        assert.equal(_bindChannelSequence.toNumber(), 2, "wrong bind channel sequence");

        try {
            await tokenHub.rejectBind(abcToken.address, "0x4142432d39433700000000000000000000000000000000000000000000000000", {from: relayer});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("only erc20 owner can reject"));
        }

        await tokenHub.rejectBind(abcToken.address, "0x4142432d39433700000000000000000000000000000000000000000000000000", {from: owner});

        const bindRequenst = await tokenHub._bindPackageRecord.call("0x4142432d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Expire bind', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        const key = Buffer.from(web3.utils.hexToBytes(
            crossChainKeyPrefix + 
            sourceChainID +
            destChainID +
            bindChannelID +
            "0000000000000002"));

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4142432d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol
            abcToken.address.toString().replace("0x", "") +      // erc20 contract address
            "00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000" +        // total supply
            "00000000000000000000000000000000000000000051e410c0f93fe543000000" +        // peggy amount
            expireTimeStr +                                                              // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee
        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        await tokenHub.handleBindPackage(merkleHeight, key, value, proof, {from: relayer});

        const _bindChannelSequence = await tokenHub._bindChannelSequence.call();
        assert.equal(_bindChannelSequence.toNumber(), 3, "wrong bind channel sequence");

        try {
            await tokenHub.expireBind("0x4142432d39433700000000000000000000000000000000000000000000000000", {from: accounts[2]});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("bind request is not expired"));
        }

        await sleep(10 * 1000);

        await tokenHub.expireBind("0x4142432d39433700000000000000000000000000000000000000000000000000", {from: accounts[2]});

        bindRequenst = await tokenHub._bindPackageRecord.call("0x4142432d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Mismatched token symbol', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        const key = Buffer.from(web3.utils.hexToBytes(
            crossChainKeyPrefix + 
            sourceChainID +
            destChainID +
            bindChannelID +
            "0000000000000003"));

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4445462d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol, symbol: DEF-9C7
            abcToken.address.toString().replace("0x", "") +      // erc20 contract address
            "00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000" +        // total supply
            "00000000000000000000000000000000000000000051e410c0f93fe543000000" +        // peggy amount
            expireTimeStr +                                                              // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee
        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        await tokenHub.handleBindPackage(merkleHeight, key, value, proof, {from: relayer});

        const _bindChannelSequence = await tokenHub._bindChannelSequence.call();
        assert.equal(_bindChannelSequence.toNumber(), 4, "wrong bind channel sequence");

        let tx = await tokenHub.approveBind(abcToken.address, "0x4445462d39433700000000000000000000000000000000000000000000000000", {from: owner});
        truffleAssert.eventEmitted(tx, "LogBindInvalidParameter", (ev) => {
            return ev.bep2TokenSymbol === "0x4445462d39433700000000000000000000000000000000000000000000000000";
        });

        bindRequenst = await tokenHub._bindPackageRecord.call("0x4445462d39433700000000000000000000000000000000000000000000000000"); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Success bind', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        const key = Buffer.from(web3.utils.hexToBytes(
            crossChainKeyPrefix + 
            sourceChainID +
            destChainID +
            bindChannelID +
            "0000000000000004"));

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireTimeStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireTimeStrLength = initialExpireTimeStr.length;
        let expireTimeStr = initialExpireTimeStr;
        for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }

        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4142432d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol
            abcToken.address.toString().replace("0x", "") +      // erc20 contract address
            "00000000000000000000000000000000000000000052b7d2dcc80cd2e4000000" +        // total supply
            "00000000000000000000000000000000000000000051e410c0f93fe543000000" +        // peggy amount
            expireTimeStr +                                                              // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        await tokenHub.handleBindPackage(merkleHeight, key, value, proof, {from: relayer});

        const _bindChannelSequence = await tokenHub._bindChannelSequence.call();
        assert.equal(_bindChannelSequence.toNumber(), 5, "wrong bind channel sequence");

        await tokenHub.approveBind(abcToken.address, "0x4142432d39433700000000000000000000000000000000000000000000000000", {from: owner});

        const bep2Symbol = await tokenHub._contractAddrToBEP2Symbol.call(abcToken.address);
        assert.equal(bep2Symbol, "0x4142432d39433700000000000000000000000000000000000000000000000000", "wrong symbol");
        const contractAddr = await tokenHub._bep2SymbolToContractAddr.call("0x4142432d39433700000000000000000000000000000000000000000000000000");
        assert.equal(contractAddr, abcToken.address, "wrong contract addr");
    });
    it('Relayer transfer from BBC to BSC', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const relayer = accounts[1];

        const key = Buffer.from(web3.utils.hexToBytes(
            crossChainKeyPrefix +    // prefix
            sourceChainID +        // source chainID
            destChainID +        // destination chainID
            transferChannelID +          // channel ID
            "0000000000000000")); // sequence
        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireStrLength = initialExpireStr.length;
        let expireTimeStr = initialExpireStr;
        for (var i = 0; i < 16 - initialExpireStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }
        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4142432d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol
            abcToken.address.toString().replace("0x", "") +      // erc20 contract address
            "35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48" +                                // sender address
            accounts[2].toString().replace("0x", "") +                                  // recipient amount
            "000000000000000000000000000000000000000000000000d71b0fe0a28e0000" +        // amount
            expireTimeStr +                                                             // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        let balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.toNumber(), 0, "wrong balance");

        await tokenHub.handleTransferInPackage(merkleHeight, key, value, proof, {from: relayer});

        const _transferInChannelSequence = await tokenHub._transferInChannelSequence.call();
        assert.equal(_transferInChannelSequence.toNumber(), 1, "wrong transfer in channel sequence");

        balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.eq(web3.utils.toBN(155e17)), true, "wrong balance");
    });
    it('Expired transfer from BBC to BSC', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        const key = Buffer.from(web3.utils.hexToBytes(
            crossChainKeyPrefix +    // prefix
            sourceChainID +        // source chainID
            destChainID +        // destination chainID
            transferChannelID +          // channel ID
            "0000000000000001")); // sequence
        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let initialExpireStr = (timestamp + 5).toString(16); // expire at 5 second later
        const initialExpireStrLength = initialExpireStr.length;
        let expireTimeStr = initialExpireStr;
        for (var i = 0; i < 16 - initialExpireStrLength; i++) {
            expireTimeStr = '0' + expireTimeStr;
        }
        const value = Buffer.from(web3.utils.hexToBytes(
            "0x4142432d39433700000000000000000000000000000000000000000000000000" + // bep2TokenSymbol
            abcToken.address.toString().replace("0x", "") +      // erc20 contract address
            "35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48" +                                // sender address
            accounts[2].toString().replace("0x", "") +                                  // recipient amount
            "000000000000000000000000000000000000000000000000d71b0fe0a28e0000" +        // amount
            expireTimeStr +                                                             // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        await sleep(10 * 1000);
        const tx = await tokenHub.handleTransferInPackage(merkleHeight, key, value, proof, {from: relayer});
        truffleAssert.eventEmitted(tx, "LogTransferInFailureTimeout", (ev) => {
            return ev.bep2TokenSymbol === "0x4142432d39433700000000000000000000000000000000000000000000000000";
        });
        const _transferInChannelSequence = await tokenHub._transferInChannelSequence.call();
        assert.equal(_transferInChannelSequence.toNumber(), 2, "wrong transfer in channel sequence");

        let balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.eq(web3.utils.toBN(155e17)), true, "wrong balance");
    });
    it('Relayer BNB transfer from BBC to BSC', async () => {
        const tokenHub = await TokenHub.deployed();

        const relayer = accounts[1];

        const key = Buffer.from(web3.utils.hexToBytes(
            crossChainKeyPrefix +    // prefix
            sourceChainID +        // source chainID
            destChainID +        // destination chainID
            transferChannelID +          // channel ID
            "0000000000000002")); // sequence
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
            "35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48" +                                // sender address
            accounts[2].toString().replace("0x", "") +                                  // recipient amount
            "0000000000000000000000000000000000000000000000000DE0B6B3A7640000" +        // amount 1e18
            expireTimeStr +                                                             // expire time
            "000000000000000000000000000000000000000000000000002386f26fc10000"));       // relayFee

        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        const initBalance = await web3.eth.getBalance(accounts[2]);
        const tx = await tokenHub.handleTransferInPackage(merkleHeight, key, value, proof, {from: relayer});
        truffleAssert.eventEmitted(tx, "LogTransferInSuccess", (ev) => {
            return ev.recipient === accounts[2];
        });
        const newBalance = await web3.eth.getBalance(accounts[2]);

        const _transferInChannelSequence = await tokenHub._transferInChannelSequence.call();
        assert.equal(_transferInChannelSequence.toNumber(), 3, "wrong transfer in channel sequence");
        assert.equal(web3.utils.toBN(newBalance).sub(web3.utils.toBN(initBalance)).eq(web3.utils.toBN(1e18)), true, "wrong balance");
    });
    it('Transfer from BSC to BBC', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const defToken = await DEFToken.deployed();

        const sender = accounts[2];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let expireTime = timestamp + 10; // expire at 5 second later
        const recipient = "0xd719dDfA57bb1489A08DF33BDE4D5BA0A9998C60";
        const amount = web3.utils.toBN(1e11);
        const relayFee = web3.utils.toBN(1e16);

        try {
            await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, relayFee, {from: sender, value: relayFee});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("ERC20: transfer amount exceeds allowance"));
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
            assert.ok(error.toString().includes("relayFee is must be N*10^10"));
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
        const _transferOutChannelSequence = await tokenHub._transferOutChannelSequence.call();
        assert.equal(_transferOutChannelSequence.toNumber(), 1, "wrong transfer out channel sequence");

        let balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.eq(web3.utils.toBN(155e17).sub(amount)), true, "wrong balance");
    });
    it('Relay refund package', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();

        const relayer = accounts[1];
        const refundAddr = accounts[2];

        const key = Buffer.from(web3.utils.hexToBytes(
            crossChainKeyPrefix + 
            sourceChainID +
            destChainID +
            refundChannelID +
            "0000000000000000"));

        const value = Buffer.from(web3.utils.hexToBytes(
            "0x000000000000000000000000000000000000000000000000000000174876E800" + // refund amount
            abcToken.address.toString().replace("0x", "") +      // erc20 contract address
            refundAddr.toString().replace("0x", "")  +           // refund address
            "0000")                                                                     // failureCode, timeout
        );
        const proof = Buffer.from(web3.utils.hexToBytes("0x00"));

        const amount = web3.utils.toBN(1e11);

        let balance = await abcToken.balanceOf.call(refundAddr);
        assert.equal(balance.eq(web3.utils.toBN(155e17).sub(amount)), true, "wrong balance");

        const tx = await tokenHub.handleRefundPackage(merkleHeight, key, value, proof, {from: relayer});
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
        let expireTime = (timestamp + 5);
        const relayFee = web3.utils.toBN(1e16);

        await abcToken.approve(tokenHub.address, web3.utils.toBN(3e11), {from: sender});
        let tx = await tokenHub.batchTransferOut(recipientAddrs, amounts, refundAddrs, abcToken.address, expireTime, relayFee, {from: sender, value: relayFee});
        truffleAssert.eventEmitted(tx, "LogBatchTransferOut", (ev) => {
            return ev.sequence.toNumber() === 1 &&
                ev.contractAddr === abcToken.address &&
                ev.amounts[0].eq(amounts[0].div(web3.utils.toBN(1e10))) &&
                ev.amounts[1].eq(amounts[1].div(web3.utils.toBN(1e10)));
        });
        let txData = await web3.eth.getTransaction(tx.tx);

        const decoder = new InputDataDecoder('./test/abi/tokenHub.json');
        let batchTransferOut = decoder.decodeData(txData.input);
        assert.equal(batchTransferOut.inputs[0][0], recipientAddrs[0].toString().replace("0x", ""), "wrong recipient address");
        assert.equal(batchTransferOut.inputs[0][1], recipientAddrs[1].toString().replace("0x", ""), "wrong recipient address");
        assert.equal(batchTransferOut.inputs[2][0], refundAddrs[0].toString().replace("0x", ""), "wrong refund address");
        assert.equal(batchTransferOut.inputs[2][1], refundAddrs[1].toString().replace("0x", ""), "wrong refund address");

        amounts = [web3.utils.toBN(3e11), web3.utils.toBN(4e11)];

        await abcToken.approve(tokenHub.address, web3.utils.toBN(7e11), {from: sender});
        tx = await tokenHub.batchTransferOut(recipientAddrs, amounts, refundAddrs, abcToken.address, expireTime, relayFee, {from: sender, value: relayFee});
        truffleAssert.eventEmitted(tx, "LogBatchTransferOut", (ev) => {
            return ev.sequence.toNumber() === 2 &&
                ev.contractAddr === abcToken.address &&
                ev.amounts[0].eq(amounts[0].div(web3.utils.toBN(1e10))) &&
                ev.amounts[1].eq(amounts[1].div(web3.utils.toBN(1e10)));
        });
        txData = await web3.eth.getTransaction(tx.tx);
        result = decoder.decodeData(txData.input);
        batchTransferOut = decoder.decodeData(txData.input);
        assert.equal(batchTransferOut.inputs[0][0], recipientAddrs[0].toString().replace("0x", ""), "wrong recipient address");
        assert.equal(batchTransferOut.inputs[0][1], recipientAddrs[1].toString().replace("0x", ""), "wrong recipient address");
        assert.equal(batchTransferOut.inputs[2][0], refundAddrs[0].toString().replace("0x", ""), "wrong refund address");
        assert.equal(batchTransferOut.inputs[2][1], refundAddrs[1].toString().replace("0x", ""), "wrong refund address");
    });
});