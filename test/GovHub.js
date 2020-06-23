const truffleAssert = require('truffle-assertions');
const GovHub = artifacts.require("GovHub");
const BSCValidatorSet = artifacts.require("BSCValidatorSet");
const CrossChain = artifacts.require("CrossChain");
const SystemReward = artifacts.require("SystemReward");
const TokenHub = artifacts.require("TokenHub");
const RelayerIncentivize = artifacts.require("RelayerIncentivize");
const TendermintLightClient = artifacts.require("TendermintLightClient");
const RLP = require('rlp');
const Web3 = require('web3');
const GOV_CHANNEL_ID = 0x09;
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

contract('GovHub others', (accounts) => {
    it('Gov others success', async () => {
        const govHubInstance = await GovHub.deployed();
        const bSCValidatorSetInstance =await BSCValidatorSet.deployed();

        const relayerAccount = accounts[8];
        let tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("expireTimeSecondGap", "0x0000000000000000000000000000000000000000000000000000000000010000", bSCValidatorSetInstance.address),
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "paramChange",(ev) => {
            return ev.key === "expireTimeSecondGap";
        });

        let reward = await bSCValidatorSetInstance.expireTimeSecondGap.call();
        assert.equal(reward.toNumber(), 65536, "value not equal");
    });

    it('Gov others failed', async () => {
        const govHubInstance = await GovHub.deployed();
        const bSCValidatorSetInstance =await BSCValidatorSet.deployed();
        const systemRewardInstance = await SystemReward.deployed();
        const relayerAccount = accounts[8];

        // unknown  key
        let tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("unknown key", "0x0000000000000000000000000000000000000000000000000000000000010000", bSCValidatorSetInstance.address),
            {from: relayerAccount});

        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "unknown param";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange")

        // exceed range  key
        tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("expireTimeSecondGap", "0x000000000000010000000000000000000000000000000000000000000000000", bSCValidatorSetInstance.address),
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "the expireTimeSecondGap is out of range";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange")

        // length mismatch
        tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("expireTimeSecondGap", "0x10000", bSCValidatorSetInstance.address),
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "length of expireTimeSecondGap mismatch";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange")

        // address do not exist
        tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("expireTimeSecondGap", "0x0000000000000000000000000000000000000000000000000000000000000000", "0x1110000000000000000000000000000000001004"),
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "the target is not a contract";
        });

        // method do no exist
        tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("expireTimeSecondGap", "0x0000000000000000000000000000000000000000000000000000000000000000", systemRewardInstance.address),
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithBytes",(ev) => {
            return ev.message === null;
        });
    });

    it('Gov tokenhub', async () => {
        const govHubInstance = await GovHub.deployed();
        const tokenHub =await TokenHub.deployed();

        const relayerAccount = accounts[8];
        let tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("relayFee", "0x00000000000000000000000000000000000000000000000000038d7ea4c68000", tokenHub.address),
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "paramChange",(ev) => {
            return ev.key === "relayFee";
        });

        let minimumRelayFee = await tokenHub.relayFee.call();
        assert.equal(minimumRelayFee.toNumber(), 1000000000000000, "value not equal");
    });

    it('Gov tendermintLightClient', async () => {
        const govHubInstance = await GovHub.deployed();
        const tendermintLightClient =await TendermintLightClient.deployed();

        const relayerAccount = accounts[8];
        let tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("rewardForValidatorSetChange", "0x0000000000000000000000000000000000000000000000000000000000010000", TendermintLightClient.address),
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "paramChange",(ev) => {
            return ev.key === "rewardForValidatorSetChange";
        });

        let rewardForValidatorSetChange = await tendermintLightClient.rewardForValidatorSetChange.call();
        assert.equal(rewardForValidatorSetChange.toNumber(), 65536, "value not equal");
    });

    it('Gov relayerIncentivize', async () => {
        const govHubInstance = await GovHub.deployed();
        const relayerIncentivize =await RelayerIncentivize.deployed();

        const relayerAccount = accounts[8];
        let tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("moleculeHeaderRelayer", "0x0000000000000000000000000000000000000000000000000000000000010000", RelayerIncentivize.address),
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "paramChange",(ev) => {
            return ev.key === "moleculeHeaderRelayer";
        });

        let moleculeHeaderRelayer = await relayerIncentivize.moleculeHeaderRelayer.call();
        assert.equal(moleculeHeaderRelayer.toNumber(), 65536, "value not equal");
    });

    it('Gov cross chain contract', async () => {
        const govHubInstance = await GovHub.deployed();
        const crossChainInstance =await CrossChain.deployed();

        const relayerAccount = accounts[8];
        let tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("addChannel", web3.utils.bytesToHex(Buffer.concat([Buffer.from(web3.utils.hexToBytes("0x57")), Buffer.from(web3.utils.hexToBytes("0x00")), Buffer.from(web3.utils.hexToBytes(RelayerIncentivize.address))])), crossChainInstance.address),
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "paramChange",(ev) => {
            return ev.key === 'addChannel';
        });

        let appAddr = await crossChainInstance.channelHandlerContractMap.call(0x57);
        assert.equal(appAddr, RelayerIncentivize.address, "value not equal");
        let fromSys = await crossChainInstance.isRelayRewardFromSystemReward.call(0x57);
        assert.equal(fromSys, true, "should from system reward");

        tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("batchSizeForOracle", "0x0000000000000000000000000000000000000000000000000000000000000064", crossChainInstance.address),
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "paramChange",(ev) => {
            return ev.key === 'batchSizeForOracle';
        });
        let batchSizeForOracle = await crossChainInstance.batchSizeForOracle.call();
        assert.equal(batchSizeForOracle, 100, "value not equal");
    });
});

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
