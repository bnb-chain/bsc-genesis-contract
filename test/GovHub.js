const truffleAssert = require('truffle-assertions');
const GovHub = artifacts.require("GovHub");
const BSCValidatorSet = artifacts.require("BSCValidatorSet");
const TokenHub = artifacts.require("TokenHub");
const RelayerIncentivize = artifacts.require("RelayerIncentivize");
const TendermintLightClient = artifacts.require("TendermintLightClient");
const RLP = require('rlp');
const GOV_CHANNEL_ID = 0x09;

contract('GovHub others', (accounts) => {
    it('Gov others success', async () => {
        const govHubInstance = await GovHub.deployed();
        const bSCValidatorSetInstance =await BSCValidatorSet.deployed();

        const relayerAccount = accounts[8];
         await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("0x00","relayerReward", "0x0000000000000000000000000000000000000000000000000000000000010000", bSCValidatorSetInstance.address),
            {from: relayerAccount});
        // truffleAssert.eventEmitted(tx, "paramChange",(ev) => {
        //     return ev.key === "relayerReward";
        // });
        //
        // let reward = await bSCValidatorSetInstance.relayerReward.call();
        // assert.equal(reward.toNumber(), 65536, "value not equal");
    });

    // it('Gov others failed', async () => {
    //     const govHubInstance = await GovHub.deployed();
    //     const bSCValidatorSetInstance =await BSCValidatorSet.deployed();
    //     const systemRewardInstance = await SystemReward.deployed();
    //     const relayerAccount = accounts[8];
    //
    //     // unknown  key
    //     let tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("0x00","unknown key", "0x0000000000000000000000000000000000000000000000000000000000010000", bSCValidatorSetInstance.address),
    //         {from: relayerAccount});
    //
    //     truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
    //         return ev.message === "unknown param";
    //     });
    //     truffleAssert.eventNotEmitted(tx, "paramChange")
    //
    //     // exceed range  key
    //     tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("0x00","relayerReward", "0x0000000000000000000000000000000000000000000000000000000000000000", bSCValidatorSetInstance.address),
    //         {from: relayerAccount});
    //     truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
    //         return ev.message === "the relayerReward out of range";
    //     });
    //     truffleAssert.eventNotEmitted(tx, "paramChange")
    //
    //     // length mismatch
    //     tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("0x00","relayerReward", "0x10", bSCValidatorSetInstance.address),
    //         {from: relayerAccount});
    //     truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
    //         return ev.message === "length of relayerReward mismatch";
    //     });
    //     truffleAssert.eventNotEmitted(tx, "paramChange")
    //
    //     // address do not exist
    //     tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("0x00","relayerReward", "0x0000000000000000000000000000000000000000000000000000000000000000", "0x1110000000000000000000000000000000001004"),
    //         {from: relayerAccount});
    //     truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
    //         return ev.message === "the target is not a contract";
    //     });
    //
    //     // method do no exist
    //     tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("0x00","relayerReward", "0x0000000000000000000000000000000000000000000000000000000000000000", systemRewardInstance.address),
    //         {from: relayerAccount});
    //     truffleAssert.eventEmitted(tx, "failReasonWithBytes",(ev) => {
    //         return ev.message === null;
    //     });
    // });
    //
    // it('Gov tokenhub', async () => {
    //     const govHubInstance = await GovHub.deployed();
    //     const tokenHub =await TokenHub.deployed();
    //
    //     const relayerAccount = accounts[8];
    //     let tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("0x00","minimumRelayFee", "0x0000000000000000000000000000000000000000000000000000000000010000", tokenHub.address),
    //         {from: relayerAccount});
    //     truffleAssert.eventEmitted(tx, "paramChange",(ev) => {
    //         return ev.key === "minimumRelayFee";
    //     });
    //
    //     let minimumRelayFee = await tokenHub.minimumRelayFee.call();
    //     assert.equal(minimumRelayFee.toNumber(), 65536, "value not equal");
    // });
    //
    // it('Gov tendermintLightClient', async () => {
    //     const govHubInstance = await GovHub.deployed();
    //     const tendermintLightClient =await TendermintLightClient.deployed();
    //
    //     const relayerAccount = accounts[8];
    //     let tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("0x00","rewardForValidatorSetChange", "0x0000000000000000000000000000000000000000000000000000000000010000", TendermintLightClient.address),
    //         {from: relayerAccount});
    //     truffleAssert.eventEmitted(tx, "paramChange",(ev) => {
    //         return ev.key === "rewardForValidatorSetChange";
    //     });
    //
    //     let rewardForValidatorSetChange = await tendermintLightClient.rewardForValidatorSetChange.call();
    //     assert.equal(rewardForValidatorSetChange.toNumber(), 65536, "value not equal");
    // });
    //
    // it('Gov relayerIncentivize', async () => {
    //     const govHubInstance = await GovHub.deployed();
    //     const relayerIncentivize =await RelayerIncentivize.deployed();
    //
    //     const relayerAccount = accounts[8];
    //     let tx = await govHubInstance.handleSynPackage(GOV_CHANNEL_ID, serialize("0x00","moleculeHeaderRelayer", "0x0000000000000000000000000000000000000000000000000000000000010000", RelayerIncentivize.address),
    //         {from: relayerAccount});
    //     truffleAssert.eventEmitted(tx, "paramChange",(ev) => {
    //         return ev.key === "moleculeHeaderRelayer";
    //     });
    //
    //     let moleculeHeaderRelayer = await relayerIncentivize.moleculeHeaderRelayer.call();
    //     assert.equal(moleculeHeaderRelayer.toNumber(), 65536, "value not equal");
    // });
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
