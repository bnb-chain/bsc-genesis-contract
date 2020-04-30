const truffleAssert = require('truffle-assertions');
const GovHub = artifacts.require("GovHub");
const SystemReward = artifacts.require("SystemReward");
const BSCValidatorSet = artifacts.require("BSCValidatorSet");
const Web3 = require('web3');
const crypto = require('crypto');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

contract('GovHub self', (accounts) => {
    it('Gov it self', async () => {
        const govHubInstance = await GovHub.deployed();
        const systemRewardInstance = await SystemReward.deployed();
        let systemAccount = accounts[0];
        await systemRewardInstance.addOperator(govHubInstance.address, {from: systemAccount});

        const relayerAccount = accounts[8];
        let tx = await govHubInstance.handlePackage(serialize("0x00","relayerReward", "0x0000000000000000000000000000000000000000000000000000000000010000", govHubInstance.address),crypto.randomBytes(32),100, 0,
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "paramChange",(ev) => {
            return ev.key === "relayerReward";
        });

        let reward = await govHubInstance.relayerReward.call();
        assert.equal(reward.toNumber(), 65536, "value not equal");
    });

    it('Gov it self fail error package', async () => {
        const govHubInstance = await GovHub.deployed();
        const relayerAccount = accounts[8];

        //seq not in order
        try{
            await govHubInstance.handlePackage(serialize("0x00","relayerReward", "0x0000000000000000000000000000000000000000000000000000000000010000", govHubInstance.address),crypto.randomBytes(32),100, 0,
                {from: relayerAccount});
            assert.fail();
        }catch(error){
            assert.ok(error.toString().includes("sequence not in order"));
        }
        //not rlayer
        try{
            await govHubInstance.handlePackage(serialize("0x00","relayerReward", "0x0000000000000000000000000000000000000000000000000000000000010000", govHubInstance.address),crypto.randomBytes(32),100, 1,
                {from: accounts[0]});
            assert.fail();
        }catch(error){
            assert.ok(error.toString().includes("the msg sender is not a relayer"));
        }

        // wrong message type
        let tx = await govHubInstance.handlePackage(serialize("0x01","relayerReward", "0x0000000000000000000000000000000000000000000000000000000000010000", govHubInstance.address),crypto.randomBytes(32),100, 1,
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "unknown message type";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange")

        // unknown  key
        tx = await govHubInstance.handlePackage(serialize("0x00","unknown key", "0x0000000000000000000000000000000000000000000000000000000000010000", govHubInstance.address),crypto.randomBytes(32),100, 2,
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "unknown param";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange")

        // invalid param value
        tx = await govHubInstance.handlePackage(serialize("0x00","relayerReward", "0x10000", govHubInstance.address),crypto.randomBytes(32),100, 3,
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "length of relayerReward mismatch";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange")

        // out of range
        tx = await govHubInstance.handlePackage(serialize("0x00","relayerReward", "0x0000000000000000000000000000000000000000000000000000000000000000", govHubInstance.address),crypto.randomBytes(32),100, 4,
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "the relayerReward out of range";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange")

        // out of range2
        tx = await govHubInstance.handlePackage(serialize("0x00","relayerReward", "0x0000000000010000000000000000000000000000000000000000000000000000", govHubInstance.address),crypto.randomBytes(32),100, 5,
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "the relayerReward out of range";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange")

        // length mismatch
        tx = await govHubInstance.handlePackage(serialize("0x00","relayerReward", "0x0000000000010000000000000000000000000000000000000000000000000000", govHubInstance.address,"0x0000"),crypto.randomBytes(32),100, 6,
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "valueLength mismatch";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange")
    });

    it('Gov it self and overflow', async () => {
        const govHubInstance = await GovHub.deployed();
        const relayerAccount = accounts[8];
        let tx = await govHubInstance.handlePackage(serialize("0x00","44NefHcYoOIxHFBIRYpAGobD3ftcaDsh9Jo9BZhFiUpkdA7IgLWCILRLq4LbheFqe3lbKOOoJvqdXt8lIrm076rIxUIxID8UkOW8uq27q15Quc1tt90Tw540kENpZqQRKOtR2GDpDxLs50R7wZfymZ476Nx6vSiiTq7pjm8zzEJ5l2DJ0dzKcfQ6fsQw6KalrF6RE6aBQk1JnatKy4sBWDWTvJoMizYqUnZk441qLYOSpq8EKFcKPYrwcKQx", "0x0000000000000000000000000000000000000000000000000000000000010000", govHubInstance.address),crypto.randomBytes(32),100, 7,
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "unknown param";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange");

        let reward = await govHubInstance.relayerReward.call();
        assert.equal(reward.toNumber(), 65536, "value not equal");
    });
});


contract('GovHub others', (accounts) => {
    it('Gov others success', async () => {
        const govHubInstance = await GovHub.deployed();
        const systemRewardInstance = await SystemReward.deployed();
        const bSCValidatorSetInstance =await BSCValidatorSet.deployed();
        let systemAccount = accounts[0];
        await systemRewardInstance.addOperator(govHubInstance.address, {from: systemAccount});

        const relayerAccount = accounts[8];
        let tx = await govHubInstance.handlePackage(serialize("0x00","relayerReward", "0x0000000000000000000000000000000000000000000000000000000000010000", bSCValidatorSetInstance.address),crypto.randomBytes(32),100, 0,
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "paramChange",(ev) => {
            return ev.key === "relayerReward";
        });

        let reward = await bSCValidatorSetInstance.relayerReward.call();
        assert.equal(reward.toNumber(), 65536, "value not equal");
    });

    it('Gov others failed', async () => {
        const govHubInstance = await GovHub.deployed();
        const bSCValidatorSetInstance =await BSCValidatorSet.deployed();
        const relayerAccount = accounts[8];


        // unknown  key
        let tx = await govHubInstance.handlePackage(serialize("0x00","unknown key", "0x0000000000000000000000000000000000000000000000000000000000010000", bSCValidatorSetInstance.address),crypto.randomBytes(32),100, 1,
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "unknown param";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange")

        // exceed range  key
        tx = await govHubInstance.handlePackage(serialize("0x00","relayerReward", "0x0000000000000000000000000000000000000000000000000000000000000000", bSCValidatorSetInstance.address),crypto.randomBytes(32),100, 2,
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "the relayerReward out of range";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange")

        // length mismatch
        tx = await govHubInstance.handlePackage(serialize("0x00","relayerReward", "0x10", bSCValidatorSetInstance.address),crypto.randomBytes(32),100, 3,
            {from: relayerAccount});
        truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
            return ev.message === "length of relayerReward mismatch";
        });
        truffleAssert.eventNotEmitted(tx, "paramChange")
    });

});

function serialize(msgType, key,value, target, extra) {
    let arr = [];
    let keyBytes = web3.utils.hexToBytes(web3.utils.stringToHex(key));
    let keyLength = keyBytes.length;
    let valueBytes = web3.utils.hexToBytes(value);
    let valueLength =  valueBytes.length;

    arr.push(Buffer.from(web3.utils.hexToBytes(msgType)));
    arr.push(Buffer.from([keyLength]));
    arr.push(Buffer.from(keyBytes));
    arr.push(Buffer.from([valueLength]));
    arr.push(Buffer.from(valueBytes));
    arr.push(Buffer.from(web3.utils.hexToBytes(target.toString())));
    if(extra != null){
        arr.push(Buffer.from(web3.utils.hexToBytes(extra)));
    }
    return Buffer.concat(arr);
}
