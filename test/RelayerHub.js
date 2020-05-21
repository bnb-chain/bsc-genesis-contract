const RelayerHub = artifacts.require("RelayerHub");
const SystemReward = artifacts.require("SystemReward");
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

contract('RelayerHub', (accounts) => {
  it('register and unregister success', async () => {
    const relayerInstance = await RelayerHub.deployed();
    const systemRewardInstance = await SystemReward.deployed();

    let tx =await relayerInstance.register({from: accounts[3],value: 1e20});
    truffleAssert.eventEmitted(tx, "relayerRegister");
    let res = await relayerInstance.isRelayer.call(accounts[3]);
    assert.equal(res,true);

    let balanceBefore = await web3.eth.getBalance(accounts[3]);
    let systemRewardBefore = await web3.eth.getBalance(systemRewardInstance.address);

    tx =await relayerInstance.unregister({from: accounts[3]});
    truffleAssert.eventEmitted(tx, "relayerUnRegister");

    res = await relayerInstance.isRelayer.call(accounts[3]);
    assert.equal(res,false);

    let balanceAfter = await web3.eth.getBalance(accounts[3]);
    assert.equal(res,false);
    let deposit = await relayerInstance.requiredDeposit.call();
    let dues = await relayerInstance.dues.call();
    assert.equal(web3.utils.toBN(balanceAfter).sub(web3.utils.toBN(balanceBefore)).add(web3.utils.toBN(2e10).mul(web3.utils.toBN(tx.receipt.gasUsed))).toString(), deposit.sub(dues).toString());

    let systemRewardAfter = await web3.eth.getBalance(systemRewardInstance.address);
    assert.equal(web3.utils.toBN(systemRewardAfter).sub(web3.utils.toBN(systemRewardBefore)).toString(), web3.utils.toBN(1e17).toString())
  });

  it('fail to register', async () => {
    const relayerInstance = await RelayerHub.deployed();
    await relayerInstance.register({from: accounts[3],value: 1e20});
    // reregister
    try {
      await relayerInstance.register({from: accounts[3],value: 1e20});
      assert.fail();
    } catch (error) {
      assert.ok(error.toString().includes("relayer already exist"));
    }

    await relayerInstance.unregister({from: accounts[3]});
    try {
      await relayerInstance.unregister({from: accounts[3]});
      assert.fail();
    } catch (error) {
      assert.ok(error.toString().includes("relayer do not exist"));
    }

    try {
      await relayerInstance.register({from: accounts[4],value: 2e20});
      assert.fail();
    } catch (error) {
      assert.ok(error.toString().includes("deposit value is not exactly the same"));
    }

    try {
      await relayerInstance.register({from: accounts[4],value: 1e10});
      assert.fail();
    } catch (error) {
      assert.ok(error.toString().includes("deposit value is not exactly the same"));
    }

  });
});

