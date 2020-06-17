const BN = require('bn.js');
const sleep = require("await-sleep");
const RLP = require('rlp');

const SystemReward = artifacts.require("SystemReward");
const RelayerIncentivize = artifacts.require("RelayerIncentivize");
//const TendermintLightClient = artifacts.require("TendermintLightClient");
const MockLightClient = artifacts.require("mock/MockLightClient");
const TokenHub = artifacts.require("TokenHub");
const TokenManager = artifacts.require("TokenManager");
const CrossChain = artifacts.require("CrossChain");
const ABCToken = artifacts.require("ABCToken");
const DEFToken = artifacts.require("DEFToken");
const MiniToken = artifacts.require("test/MiniToken");
const MaliciousToken = artifacts.require("test/MaliciousToken");
const RelayerHub = artifacts.require("RelayerHub");

const crypto = require('crypto');
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

const BIND_CHANNEL_ID = 0x01;
const TRANSFER_IN_CHANNELID = 0x02;
const TRANSFER_OUT_CHANNELID = 0x03;

const proof = Buffer.from(web3.utils.hexToBytes("0x00"));
const merkleHeight = 100;

function toBytes32String(input) {
    let initialInputHexStr = web3.utils.toBN(input).toString(16);
    const initialInputHexStrLength = initialInputHexStr.length;

    let inputHexStr = initialInputHexStr;
    for (var i = 0; i < 64 - initialInputHexStrLength; i++) {
        inputHexStr = '0' + inputHexStr;
    }
    return inputHexStr;
}

function toBytes32Bep2Symbol(symbol) {
    var initialSymbolHexStr = '';
    for (var i=0; i<symbol.length; i++) {
        initialSymbolHexStr += symbol.charCodeAt(i).toString(16);
    }

    const initialSymbolHexStrLength = initialSymbolHexStr.length;

    let bep2Bytes32Symbol = initialSymbolHexStr;
    for (var i = 0; i < 64 - initialSymbolHexStrLength; i++) {
        bep2Bytes32Symbol = bep2Bytes32Symbol + "0";
    }
    return '0x'+bep2Bytes32Symbol;
}

function buildSyncPackagePrefix(syncRelayFee) {
    return Buffer.from(web3.utils.hexToBytes(
        "0x00" + toBytes32String(syncRelayFee)
    ));
}

function buildAckPackagePrefix() {
    return Buffer.from(web3.utils.hexToBytes(
        "0x01" + toBytes32String(0)
    ));
}

function buildBindPackage(bindType, bep2TokenSymbol, bep2eAddr, totalSupply, peggyAmount, decimals) {
    let timestamp = Math.floor(Date.now() / 1000); // counted by second
    let initialExpireTimeStr = (timestamp + 3).toString(16); // expire at 5 second later
    const initialExpireTimeStrLength = initialExpireTimeStr.length;
    let expireTimeStr = initialExpireTimeStr;
    for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
        expireTimeStr = '0' + expireTimeStr;
    }
    expireTimeStr = "0x" + expireTimeStr;

    const packageBytesPrefix = buildSyncPackagePrefix(1e16, 1e6);

    const packageBytes = RLP.encode([
        bindType,
        toBytes32Bep2Symbol(bep2TokenSymbol),
        bep2eAddr,
        web3.utils.toBN(totalSupply).mul(web3.utils.toBN(10).pow(web3.utils.toBN(decimals))),
        web3.utils.toBN(peggyAmount).mul(web3.utils.toBN(10).pow(web3.utils.toBN(decimals))),
        decimals,
        expireTimeStr]);

    return Buffer.concat([packageBytesPrefix, packageBytes]);
}

function buildTransferInPackage(bep2TokenSymbol, bep2eAddr, amount, recipient, refundAddr) {
    let timestamp = Math.floor(Date.now() / 1000); // counted by second
    let initialExpireTimeStr = (timestamp + 3).toString(16); // expire at 5 second later
    const initialExpireTimeStrLength = initialExpireTimeStr.length;
    let expireTimeStr = initialExpireTimeStr;
    for (var i = 0; i < 16 - initialExpireTimeStrLength; i++) {
        expireTimeStr = '0' + expireTimeStr;
    }
    expireTimeStr = "0x" + expireTimeStr;

    const packageBytesPrefix = buildSyncPackagePrefix(1e16, 1e6);

    const packageBytes = RLP.encode([
        toBytes32Bep2Symbol(bep2TokenSymbol),
        bep2eAddr,
        amount,
        recipient,
        refundAddr,
        expireTimeStr]);

    return Buffer.concat([packageBytesPrefix, packageBytes]);
}

function verifyPrefixAndExtractSyncPackage(payload, expectedRelayFee) {
    eventPayloadBytes = Buffer.from(web3.utils.hexToBytes(payload));
    assert.ok(eventPayloadBytes.length>=33, "wrong bind ack package");
    assert.equal(web3.utils.bytesToHex(eventPayloadBytes.subarray(0, 1)), "0x00", "wrong package type");
    assert.ok(web3.utils.toBN(web3.utils.bytesToHex(eventPayloadBytes.subarray(1, 33))).eq(web3.utils.toBN(expectedRelayFee)), "wrong relay fee");
    return RLP.decode(eventPayloadBytes.subarray(33, eventPayloadBytes.length));
}

function verifyPrefixAndExtractAckPackage(payload) {
    eventPayloadBytes = Buffer.from(web3.utils.hexToBytes(payload));
    assert.ok(eventPayloadBytes.length>=33, "wrong bind ack package");
    assert.equal(web3.utils.bytesToHex(eventPayloadBytes.subarray(0, 1)), "0x01", "wrong package type");
    assert.ok(web3.utils.toBN(web3.utils.bytesToHex(eventPayloadBytes.subarray(1, 33))).eq(web3.utils.toBN(0)), "wrong relay fee");
    if (eventPayloadBytes.length>33) {
        return RLP.decode(eventPayloadBytes.subarray(33, eventPayloadBytes.length));
    }
    return []
}

contract('TokenHub', (accounts) => {
    it('Init TokenHub', async () => {
        const mockLightClient = await MockLightClient.deployed();
        await mockLightClient.setBlockNotSynced(false);

        const tokenHub = await TokenHub.deployed();
        let balance_wei = await web3.eth.getBalance(tokenHub.address);
        assert.equal(balance_wei, 50e18, "wrong balance");

        const relayer = accounts[1];
        const relayerInstance = await RelayerHub.deployed();
        await relayerInstance.register({from: relayer, value: 1e20});
        let res = await relayerInstance.isRelayer.call(relayer);
        assert.equal(res,true);
    });
    it('Relay expired bind package', async () => {
        const abcToken = await ABCToken.deployed();
        const tokenManager = await TokenManager.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        const bindPackage = buildBindPackage(0, "ABC-9C7", abcToken.address, 1e8, 99e6, 18);
        let bindSequence = await crossChain.channelReceiveSequenceMap.call(BIND_CHANNEL_ID);

        await crossChain.handlePackage(bindPackage, proof, merkleHeight, bindSequence, BIND_CHANNEL_ID, {from: relayer});

        let bindRequenst = await tokenManager.bindPackageRecord.call(toBytes32Bep2Symbol("ABC-9C7")); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), toBytes32Bep2Symbol("ABC-9C7"), "wrong bep2TokenSymbol");
        assert.equal(bindRequenst.totalSupply.eq(new BN('52b7d2dcc80cd2e4000000', 16)), true, "wrong total supply");  // 1e26
        assert.equal(bindRequenst.peggyAmount.eq(new BN('51e410c0f93fe543000000', 16)), true, "wrong peggy amount");  // 99e24
        assert.equal(bindRequenst.contractAddr.toString(), abcToken.address.toString(), "wrong contract address");
        try {
            await tokenManager.approveBind(abcToken.address, "ABC-9C7", {from: relayer});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("only bep2e owner can approve this bind request"));
        }

        try {
            await tokenManager.approveBind("0x0000000000000000000000000000000000000000", "ABC-9C7", {from: relayer});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("contact address doesn't equal to the contract address in bind request"));
        }

        try {
            await tokenManager.approveBind(abcToken.address, "ABC-9C7", {from: owner});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("allowance doesn't equal to (totalSupply - peggyAmount)"));
        }

        await abcToken.approve(tokenManager.address, web3.utils.toBN(1e18).mul(web3.utils.toBN(1e6)), {from: owner});
        await sleep(5 * 1000);
        // approve expired bind request
        let tx = await tokenManager.approveBind(abcToken.address, "ABC-9C7", {from: owner, value: 1e16});

        let nestedEventValues = (await truffleAssert.createTransactionResult(crossChain, tx.tx)).logs[0].args;
        decoded = verifyPrefixAndExtractSyncPackage(nestedEventValues.payload, 1e6);
        assert.equal(web3.utils.bytesToHex(decoded[0]), "0x01", "bind status should be timeout");
        assert.equal(web3.utils.bytesToHex(decoded[1]), toBytes32Bep2Symbol("ABC-9C7"), "wrong bep2TokenSymbol");

        bindRequenst = await tokenManager.bindPackageRecord.call(toBytes32Bep2Symbol("ABC-9C7")); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Reject bind', async () => {
        const tokenManager = await TokenManager.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        const bindPackage = buildBindPackage(0, "ABC-9C7", abcToken.address, 1e8, 99e6, 18);                                                      //expire time
        let bindSequence = await crossChain.channelReceiveSequenceMap.call(BIND_CHANNEL_ID);

        await crossChain.handlePackage(bindPackage, proof, merkleHeight, bindSequence, BIND_CHANNEL_ID, {from: relayer});

        try {
            await tokenManager.rejectBind(abcToken.address, "ABC-9C7", {from: relayer, value: 1e16});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("only bep2e owner can reject"));
        }

        let tx = await tokenManager.rejectBind(abcToken.address, "ABC-9C7", {from: owner, value: 1e16});

        let nestedEventValues = (await truffleAssert.createTransactionResult(crossChain, tx.tx)).logs[0].args;
        decoded = verifyPrefixAndExtractSyncPackage(nestedEventValues.payload, 1e6);

        assert.equal(web3.utils.bytesToHex(decoded[0]), "0x03", "bind status should be rejected");
        assert.equal(web3.utils.bytesToHex(decoded[1]), toBytes32Bep2Symbol("ABC-9C7"), "wrong bep2TokenSymbol");

        const bindRequenst = await tokenManager.bindPackageRecord.call(toBytes32Bep2Symbol("ABC-9C7")); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Expire bind', async () => {
        const tokenManager = await TokenManager.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        const bindPackage = buildBindPackage(0, "ABC-9C7", abcToken.address, 1e8, 99e6, 18);
        let bindSequence = await crossChain.channelReceiveSequenceMap.call(BIND_CHANNEL_ID);

        let tx = await crossChain.handlePackage(bindPackage, proof, merkleHeight, bindSequence, BIND_CHANNEL_ID, {from: relayer});

        try {
            await tokenManager.expireBind("ABC-9C7", {from: accounts[2], value: 1e16});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("bind request is not expired"));
        }

        await sleep(5 * 1000);

        tx = await tokenManager.expireBind("ABC-9C7", {from: accounts[2], value: 1e16});

        let nestedEventValues = (await truffleAssert.createTransactionResult(crossChain, tx.tx)).logs[0].args;
        decoded = verifyPrefixAndExtractSyncPackage(nestedEventValues.payload, 1e6);
        assert.equal(web3.utils.bytesToHex(decoded[0]), "0x01", "bind status should be timeout");
        assert.equal(web3.utils.bytesToHex(decoded[1]), toBytes32Bep2Symbol("ABC-9C7"), "wrong bep2TokenSymbol");

        bindRequenst = await tokenManager.bindPackageRecord.call(toBytes32Bep2Symbol("ABC-9C7")); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Mismatched token symbol', async () => {
        const tokenManager = await TokenManager.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        const bindPackage = buildBindPackage(0, "DEF-9C7", abcToken.address, 1e8, 99e6, 18);
        let bindSequence = await crossChain.channelReceiveSequenceMap.call(BIND_CHANNEL_ID);

        let tx = await crossChain.handlePackage(bindPackage, proof, merkleHeight, bindSequence, BIND_CHANNEL_ID, {from: relayer});

        tx = await tokenManager.approveBind(abcToken.address, "DEF-9C7", {from: owner, value: 1e16});

        let nestedEventValues = (await truffleAssert.createTransactionResult(crossChain, tx.tx)).logs[0].args;
        decoded = verifyPrefixAndExtractSyncPackage(nestedEventValues.payload, 1e6);
        assert.equal(web3.utils.bytesToHex(decoded[0]), "0x02", "bind status should be incorrect parameters");
        assert.equal(web3.utils.bytesToHex(decoded[1]), toBytes32Bep2Symbol("DEF-9C7"), "wrong bep2TokenSymbol");

        bindRequenst = await tokenManager.bindPackageRecord.call(toBytes32Bep2Symbol("DEF-9C7")); // symbol: ABC-9C7
        assert.equal(bindRequenst.bep2TokenSymbol.toString(), "0x0000000000000000000000000000000000000000000000000000000000000000", "wrong bep2TokenSymbol");
    });
    it('Success bind', async () => {
        const tokenManager = await TokenManager.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        const bindPackage = buildBindPackage(0, "ABC-9C7", abcToken.address, 1e8, 99e6, 18);
        let bindSequence = await crossChain.channelReceiveSequenceMap.call(BIND_CHANNEL_ID);

        await crossChain.handlePackage(bindPackage, proof, merkleHeight, bindSequence, BIND_CHANNEL_ID, {from: relayer});

        let tx = await tokenManager.approveBind(abcToken.address, "ABC-9C7", {from: owner, value: 1e16});

        let nestedEventValues = (await truffleAssert.createTransactionResult(crossChain, tx.tx)).logs[0].args;
        decoded = verifyPrefixAndExtractSyncPackage(nestedEventValues.payload, 1e6);
        assert.equal(web3.utils.bytesToHex(decoded[0]), "0x", "bind status should be successful");
        assert.equal(web3.utils.bytesToHex(decoded[1]), toBytes32Bep2Symbol("ABC-9C7"), "wrong bep2TokenSymbol");

        const tokenHub = await TokenHub.deployed();
        const bep2Symbol = await tokenHub.getBoundBep2Symbol.call(abcToken.address);
        assert.equal(bep2Symbol, "ABC-9C7", "wrong symbol");
        const contractAddr = await tokenHub.getBoundContract.call("ABC-9C7");
        assert.equal(contractAddr, abcToken.address, "wrong contract addr");

        let tokenManagerBalance = await web3.eth.getBalance(tokenManager.address);
        assert.equal(tokenManagerBalance, "0", "tokenManager balance should be zero");
    });
    it('Relayer transfer from BC to BSC', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const relayer = accounts[1];

        const transferInPackage = buildTransferInPackage("ABC-9C7", abcToken.address, 155e17, accounts[2], "0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48");
        let transferInSequence = await crossChain.channelReceiveSequenceMap.call(TRANSFER_IN_CHANNELID);

        let balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.toNumber(), 0, "wrong balance");

        await crossChain.handlePackage(transferInPackage, proof, merkleHeight, transferInSequence, TRANSFER_IN_CHANNELID, {from: relayer});

        balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.eq(web3.utils.toBN(155e17)), true, "wrong balance");
    });
    it('Expired transfer from BC to BSC', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const relayer = accounts[1];

        const transferInPackage = buildTransferInPackage("ABC-9C7", abcToken.address, 155e17, accounts[2], "0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48");
        let transferInSequence = await crossChain.channelReceiveSequenceMap.call(TRANSFER_IN_CHANNELID);

        await sleep(5 * 1000);

        let tx = await crossChain.handlePackage(transferInPackage, proof, merkleHeight, transferInSequence, TRANSFER_IN_CHANNELID, {from: relayer});
        let event;
        truffleAssert.eventEmitted(tx, "crossChainPackage",(ev) => {
            let matched = false;
            if (ev.packageSequence.toString() === "0") {
                event = ev;
                matched = true;
            }
            return matched;
        });
        let decoded = verifyPrefixAndExtractAckPackage(event.payload);
        assert.equal(web3.utils.bytesToHex(decoded[0]), toBytes32Bep2Symbol("ABC-9C7"), "response should be empty");
        assert.ok(web3.utils.bytesToHex(decoded[1]), web3.utils.toBN(155e7).toString(16), "response should be empty");
        assert.equal(web3.utils.bytesToHex(decoded[2]), "0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48", "response should be empty");
        assert.equal(web3.utils.bytesToHex(decoded[3]), "0x01", "refund status should be timeout");

        let balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.eq(web3.utils.toBN(155e17)), true, "wrong balance");
    });
    it('Relayer BNB transfer from BC to BSC', async () => {
        const tokenHub = await TokenHub.deployed();
        const crossChain = await CrossChain.deployed();
        const relayer = accounts[1];

        const transferInPackage = buildTransferInPackage("BNB", "0x0000000000000000000000000000000000000000", 1e18, accounts[2], "0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48");
        let transferInSequence = await crossChain.channelReceiveSequenceMap.call(TRANSFER_IN_CHANNELID);

        const initBalance = await web3.eth.getBalance(accounts[2]);

        await crossChain.handlePackage(transferInPackage, proof, merkleHeight, transferInSequence, TRANSFER_IN_CHANNELID, {from: relayer});

        const newBalance = await web3.eth.getBalance(accounts[2]);

        assert.equal(web3.utils.toBN(newBalance).sub(web3.utils.toBN(initBalance)).eq(web3.utils.toBN(1e18)), true, "wrong balance");
    });
    it('Transfer from BSC to BC', async () => {
        const crossChain = await CrossChain.deployed();
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const defToken = await DEFToken.deployed();

        const sender = accounts[2];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let expireTime = timestamp + 150; // expire at two minutes later
        const recipient = "0xd719dDfA57bb1489A08DF33BDE4D5BA0A9998C60";
        const amount = web3.utils.toBN(1e18);
        const relayFee = web3.utils.toBN(1e16);

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
        let tx = await tokenHub.transferOut(abcToken.address, recipient, amount, expireTime, {from: sender, value: relayFee});
        truffleAssert.eventEmitted(tx, "transferOutSuccess",(ev) => {
            return ev.amount.eq(web3.utils.toBN(amount)) && ev.bep2eAddr.toString().toLowerCase() === abcToken.address.toLowerCase();
        });

        let nestedEventValues = (await truffleAssert.createTransactionResult(crossChain, tx.tx)).logs[0].args;
        let decoded = verifyPrefixAndExtractSyncPackage(nestedEventValues.payload, 1e6);
        assert.equal(web3.utils.bytesToHex(decoded[0]), toBytes32Bep2Symbol("ABC-9C7"), "wrong symbol");
        assert.equal(web3.utils.bytesToHex(decoded[1]), abcToken.address.toLowerCase(), "wrong contract address");
        assert.ok(web3.utils.toBN(web3.utils.bytesToHex(decoded[2][0])).eq(web3.utils.toBN(1e8)), "wrong transferOut amount");
        assert.equal(web3.utils.bytesToHex(decoded[3][0]), recipient.toLowerCase(), "wrong recipient address");
        assert.equal(web3.utils.bytesToHex(decoded[4][0]), sender.toLowerCase(), "wrong refund address");

        let balance = await abcToken.balanceOf.call(accounts[2]);
        assert.equal(balance.eq(web3.utils.toBN(155e17).sub(amount)), true, "wrong balance");
    });
    it('Relay refund package', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const relayer = accounts[1];
        const refundAddr = accounts[2];

        const packageBytesPrefix = buildAckPackagePrefix(1e16);

        const packageBytes = RLP.encode([
            abcToken.address,           //bep2e contract address
            [1e18],                    //amount
            [refundAddr],               //refund address
            1]);                        //status

        let refundSequence = await crossChain.channelReceiveSequenceMap.call(TRANSFER_OUT_CHANNELID);

        const amount = web3.utils.toBN(1e18);
        let balance = await abcToken.balanceOf.call(refundAddr);
        assert.equal(balance.eq(web3.utils.toBN(155e17).sub(amount)), true, "wrong balance");

        tx = await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, refundSequence, TRANSFER_OUT_CHANNELID, {from: relayer});
        let nestedEventValues = (await truffleAssert.createTransactionResult(tokenHub, tx.tx)).logs[0].args;
        assert.equal(nestedEventValues[0].toString().toLowerCase(), abcToken.address.toLowerCase(), "wrong refund contract address");

        balance = await abcToken.balanceOf.call(refundAddr);
        assert.equal(balance.eq(web3.utils.toBN(155e17)), true, "wrong balance");
    });
    it('Batch transfer out', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const sender = accounts[0];

        const recipientAddrs = ["0x37b8516a0f88e65d677229b402ec6c1e0e333004", "0xfa5e36a04eef3152092099f352ddbe88953bb540"];
        let amounts = [web3.utils.toBN(1e16), web3.utils.toBN(2e16)];
        const refundAddrs = ["0x37b8516a0f88e65d677229b402ec6c1e0e333004", "0xfa5e36a04eef3152092099f352ddbe88953bb540"];

        let timestamp = Math.floor(Date.now() / 1000);
        let expireTime = (timestamp + 150);
        const relayFee = web3.utils.toBN(2e16);

        let tx = await tokenHub.batchTransferOutBNB(recipientAddrs, amounts, refundAddrs, expireTime, {from: sender, value: web3.utils.toBN(5e16)});
        truffleAssert.eventEmitted(tx, "transferOutSuccess",(ev) => {
            return ev.amount.eq(web3.utils.toBN(3e16)) && ev.bep2eAddr.toString().toLowerCase() === "0x0000000000000000000000000000000000000000";
        });
        assert.equal(tx.receipt.status, true, "failed transaction");
        let nestedEventValues = (await truffleAssert.createTransactionResult(crossChain, tx.tx)).logs[0].args;
        let decoded = verifyPrefixAndExtractSyncPackage(nestedEventValues.payload, 2e6);
        assert.equal(web3.utils.bytesToHex(decoded[0]), toBytes32Bep2Symbol("BNB"), "wrong symbol");
        assert.equal(web3.utils.bytesToHex(decoded[1]), "0x0000000000000000000000000000000000000000", "wrong contract address");
        assert.ok(web3.utils.toBN(web3.utils.bytesToHex(decoded[2][0])).eq(web3.utils.toBN(1e6)), "wrong transferOut amount");
        assert.ok(web3.utils.toBN(web3.utils.bytesToHex(decoded[2][1])).eq(web3.utils.toBN(2e6)), "wrong transferOut amount");
        assert.equal(web3.utils.bytesToHex(decoded[3][0]), recipientAddrs[0].toLowerCase(), "wrong recipient address");
        assert.equal(web3.utils.bytesToHex(decoded[3][1]), recipientAddrs[1].toLowerCase(), "wrong recipient address");
        assert.equal(web3.utils.bytesToHex(decoded[4][0]), refundAddrs[0].toLowerCase(), "wrong refund address");
        assert.equal(web3.utils.bytesToHex(decoded[4][1]), refundAddrs[1].toLowerCase(), "wrong refund address");
    });
    it('Bind malicious BEP2E token', async () => {
        const maliciousToken = await MaliciousToken.deployed();
        const tokenManager = await TokenManager.deployed();
        const tokenHub = await TokenHub.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        const bindPackage = buildBindPackage(0, "MALICIOU-A09", maliciousToken.address, 1e8, 99e6, 18);
        let bindSequence = await crossChain.channelReceiveSequenceMap.call(BIND_CHANNEL_ID);

        let tx = await crossChain.handlePackage(bindPackage, proof, merkleHeight, bindSequence, BIND_CHANNEL_ID, {from: relayer});
        assert.equal(tx.receipt.status, true, "failed transaction");

        await maliciousToken.approve(tokenManager.address, web3.utils.toBN('1000000000000000000000000'), {from: owner});
        await tokenManager.approveBind(maliciousToken.address, "MALICIOU-A09", {from: owner, value: 1e16});

        const bep2Symbol = await tokenHub.getBoundBep2Symbol.call(maliciousToken.address);
        assert.equal(bep2Symbol, "MALICIOU-A09", "wrong symbol");

        const transferInPackage = buildTransferInPackage("MALICIOU-A09", maliciousToken.address, 155e17, accounts[2], "0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48");
        let transferInSequence = await crossChain.channelReceiveSequenceMap.call(TRANSFER_IN_CHANNELID);

        let balance = await maliciousToken.balanceOf.call(accounts[2]);
        assert.equal(balance.toNumber(), 0, "wrong balance");

        tx = await crossChain.handlePackage(transferInPackage, proof, merkleHeight, transferInSequence, TRANSFER_IN_CHANNELID, {from: relayer});
        assert.equal(tx.receipt.status, true, "failed transaction");

        let newTransferInSequence = await crossChain.channelReceiveSequenceMap.call(TRANSFER_IN_CHANNELID);
        assert.equal(newTransferInSequence.toNumber(), transferInSequence.toNumber()+1, "wrong transferIn sequence");

        packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x01" +
            "0000000000000000000000000000000000000000000000000000000000000000"
        ));

        packageBytes = RLP.encode([
            maliciousToken.address,                                                 //bep2TokenSymbol
            ["0x000000000000000000000000000000000000000000000000000000174876E800"], //amount
            ["0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48"],                         //refund address
            1]);                                                                    //refund address
        let refundSequence = await crossChain.channelReceiveSequenceMap.call(TRANSFER_OUT_CHANNELID);

        tx = await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, refundSequence, TRANSFER_OUT_CHANNELID, {from: relayer});
        assert.equal(tx.receipt.status, true, "failed transaction");

        let newRefundSequence = await crossChain.channelReceiveSequenceMap.call(TRANSFER_OUT_CHANNELID);
        assert.equal(newRefundSequence.toNumber(), refundSequence.toNumber()+1, "wrong transferIn sequence");
    });
    it('Uint256 overflow in transferOut and batchTransferOutBNB', async () => {
        const tokenHub = await TokenHub.deployed();

        const sender = accounts[2];

        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let expireTime = timestamp + 150; // expire at two minutes later
        let recipient = "0xd719dDfA57bb1489A08DF33BDE4D5BA0A9998C60";
        let amount = web3.utils.toBN("115792089237316195423570985008687907853269984665640564039457584007910000000000");

        try {
            await tokenHub.transferOut("0x0000000000000000000000000000000000000000", recipient, amount, expireTime, {from: sender, value: web3.utils.toBN("9999996870360064")});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("SafeMath: addition overflow"));
        }

        const recipientAddrs = ["0x37b8516a0f88e65d677229b402ec6c1e0e333004", "0xfa5e36a04eef3152092099f352ddbe88953bb540"];
        let amounts = [web3.utils.toBN("100000000000000000000000000000000000000000000000000000000000000000000000000000"), web3.utils.toBN("15792089237316195423570985008687907853269984665640564039457584007910000000000")];
        const refundAddrs = ["0x37b8516a0f88e65d677229b402ec6c1e0e333004", "0xfa5e36a04eef3152092099f352ddbe88953bb540"];

        timestamp = Math.floor(Date.now() / 1000);
        expireTime = (timestamp + 150);

        try {
            await tokenHub.batchTransferOutBNB(recipientAddrs, amounts, refundAddrs, expireTime, {from: sender, value: web3.utils.toBN("39999996870360064")});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("SafeMath: addition overflow"));
        }
    });
    it('fail ack for transfer out', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();
        const relayer = accounts[1];

        let initBalance3 = await abcToken.balanceOf.call(accounts[3]);
        let initBalance4 = await abcToken.balanceOf.call(accounts[4]);

        packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x02" +
            "0000000000000000000000000000000000000000000000000000000000000000"
        ));

        packageBytes = RLP.encode([
            toBytes32Bep2Symbol("ABC-9C7"),
            abcToken.address,
            [1e6, 2e6],
            ["0x37B8516a0F88E65D677229b402ec6C1e0E333004", "0xfA5E36a04EeF3152092099F352DDbe88953bB540"],
            [accounts[3], accounts[4]],
            Math.floor(Date.now() / 1000)
        ]);
        let refundSequence = await crossChain.channelReceiveSequenceMap.call(TRANSFER_OUT_CHANNELID);

        await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, refundSequence, TRANSFER_OUT_CHANNELID, {from: relayer});

        let newBalance3 = await abcToken.balanceOf.call(accounts[3]);
        let newBalance4 = await abcToken.balanceOf.call(accounts[4]);

        assert.equal(newBalance3.sub(initBalance3).eq(web3.utils.toBN(1e16)), true, "wrong balance");
        assert.equal(newBalance4.sub(initBalance4).eq(web3.utils.toBN(2e16)), true, "wrong balance");
    });
    it('Unbind Token', async () => {
        const tokenHub = await TokenHub.deployed();
        const abcToken = await ABCToken.deployed();
        const crossChain = await CrossChain.deployed();

        const relayer = accounts[1];

        const bindPackage = buildBindPackage(1, "ABC-9C7", abcToken.address, 0, 0, 0);
        let bindSequence = await crossChain.channelReceiveSequenceMap.call(BIND_CHANNEL_ID);

        let tx = await crossChain.handlePackage(bindPackage, proof, merkleHeight, bindSequence, BIND_CHANNEL_ID, {from: relayer});
        assert.equal(tx.receipt.status, true, "failed transaction");

        const bep2Symbol = await tokenHub.getBoundBep2Symbol.call(abcToken.address);
        assert.equal(bep2Symbol, "", "wrong symbol");
        const contractAddr = await tokenHub.getBoundContract.call("ABC-9C7");
        assert.equal(contractAddr, "0x0000000000000000000000000000000000000000", "wrong contract addr");


        const transferInPackage = buildTransferInPackage("ABC-9C7", abcToken.address, 1e18, accounts[2], "0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48");
        let transferInSequence = await crossChain.channelReceiveSequenceMap.call(TRANSFER_IN_CHANNELID);

        tx = await crossChain.handlePackage(transferInPackage, proof, merkleHeight, transferInSequence, TRANSFER_IN_CHANNELID, {from: relayer});
        assert.equal(tx.receipt.status, true, "failed transaction");

        // refund should be successful
        const refundAddr = accounts[2];
        packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
            "0x01" +
            "0000000000000000000000000000000000000000000000000000000000000000"
        ));
        packageBytes = RLP.encode([
            abcToken.address,                                                       //bep2TokenSymbol
            ["0x0000000000000000000000000000000000000000000000000DE0B6B3A7640000"], //amount
            [refundAddr],                                                           //refund address
            1]);                                                                    //refund address

        let refundSequence = await crossChain.channelReceiveSequenceMap.call(TRANSFER_OUT_CHANNELID);

        let beforeRefundBalance = await abcToken.balanceOf.call(refundAddr);

        tx = await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), proof, merkleHeight, refundSequence, TRANSFER_OUT_CHANNELID, {from: relayer});
        assert.equal(tx.receipt.status, true, "failed transaction");
        let nestedEventValues = (await truffleAssert.createTransactionResult(tokenHub, tx.tx)).logs[0].args;
        assert.equal(nestedEventValues[0].toString().toLowerCase(), abcToken.address.toLowerCase(), "wrong refund contract address");
        assert.equal(nestedEventValues[1].toString().toLowerCase(), refundAddr.toLowerCase(), "wrong refund address");

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
    it('bind and transfer miniToken', async () => {
        const tokenManager = await TokenManager.deployed();
        const tokenHub = await TokenHub.deployed();
        const miniToken = await MiniToken.deployed();
        const crossChain = await CrossChain.deployed();

        const owner = accounts[0];
        const relayer = accounts[1];

        const bindPackage = buildBindPackage(0, "XYZ-9C7M", miniToken.address, 1e4, 5e3, 18);
        let bindSequence = await crossChain.channelReceiveSequenceMap.call(BIND_CHANNEL_ID);

        await crossChain.handlePackage(bindPackage, proof, merkleHeight, bindSequence, BIND_CHANNEL_ID, {from: relayer});

        await miniToken.approve(tokenManager.address, web3.utils.toBN(1e18).mul(web3.utils.toBN(5e3)), {from: owner});
        let tx = await tokenManager.approveBind(miniToken.address, "XYZ-9C7M", {from: owner, value: 1e16});

        let nestedEventValues = (await truffleAssert.createTransactionResult(crossChain, tx.tx)).logs[0].args;
        decoded = verifyPrefixAndExtractSyncPackage(nestedEventValues.payload, 1e6);
        assert.equal(web3.utils.bytesToHex(decoded[0]), "0x", "bind status should be successful");
        assert.equal(web3.utils.bytesToHex(decoded[1]), toBytes32Bep2Symbol("XYZ-9C7M"), "wrong bep2TokenSymbol");

        const bep2Symbol = await tokenHub.getBoundBep2Symbol.call(miniToken.address);
        assert.equal(bep2Symbol, "XYZ-9C7M", "wrong symbol");
        const contractAddr = await tokenHub.getBoundContract.call("XYZ-9C7M");
        assert.equal(contractAddr, miniToken.address, "wrong contract addr");

        let amount = web3.utils.toBN(1e18);
        let recipient = accounts[3];
        await miniToken.approve(tokenHub.address, amount, {from: owner});
        let timestamp = Math.floor(Date.now() / 1000); // counted by second
        let expireTime = (timestamp + 300);
        const relayFee = web3.utils.toBN(1e16);
        tx = await tokenHub.transferOut(miniToken.address, recipient, amount, expireTime, {from: owner, value: relayFee});
        truffleAssert.eventEmitted(tx, "transferOutSuccess",(ev) => {
            return ev.amount.eq(web3.utils.toBN(amount)) && ev.bep2eAddr.toString().toLowerCase() === miniToken.address.toLowerCase();
        });
        amount = web3.utils.toBN(5e17);
        await miniToken.approve(tokenHub.address, amount, {from: owner});
        timestamp = Math.floor(Date.now() / 1000); // counted by second
        expireTime = (timestamp + 300);
        try {
            await tokenHub.transferOut(miniToken.address, recipient, amount, expireTime, {from: owner, value: relayFee});
            assert.fail();
        } catch (error) {
            assert.ok(error.toString().includes("For miniToken, the transfer amount must not be less than 1"));
        }

        amount = web3.utils.toBN(1e18);
        const transferInPackage = buildTransferInPackage("XYZ-9C7M", miniToken.address, amount, accounts[2], "0x35d9d41a13d6c2e01c9b1e242baf2df98e7e8c48");
        let transferInSequence = await crossChain.channelReceiveSequenceMap.call(TRANSFER_IN_CHANNELID);

        const initBalance = await miniToken.balanceOf.call(accounts[2]);
        await crossChain.handlePackage(transferInPackage, proof, merkleHeight, transferInSequence, TRANSFER_IN_CHANNELID, {from: relayer});
        const newBalance = await miniToken.balanceOf.call(accounts[2]);
        assert.equal(newBalance.sub(initBalance).eq(amount), true, "wrong balance");
    });
});
