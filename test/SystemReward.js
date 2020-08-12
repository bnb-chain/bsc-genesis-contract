const SystemReward = artifacts.require("SystemReward");
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

contract('SystemReward', (accounts) => {
  it('receive token success', async () => {
    const systemRewardInstance = await SystemReward.deployed();
    let tx = await systemRewardInstance.send(1e8, {from: accounts[3]});
    let balance_wei = await web3.eth.getBalance(systemRewardInstance.address);
    assert.equal(balance_wei, 1e8, "balance not equal");
    truffleAssert.eventEmitted(tx, "receiveDeposit",(ev) => {
      return ev.amount.toNumber() === 1e8 && ev.from === accounts[3];
    });
  });

  it('isOperator works', async () => {
    const systemRewardInstance = await SystemReward.deployed();
    let res = await systemRewardInstance.isOperator.call(accounts[0]);
    assert.ok(res, "accounts[0] should be operator");
    res = await systemRewardInstance.isOperator.call(accounts[1]);
    assert.ok(res, "accounts[1] should be operator");
    res = await systemRewardInstance.isOperator.call(accounts[2]);
    assert.ok(res, "accounts[2] should be operator");
    res = await systemRewardInstance.isOperator.call(accounts[3]);
    assert.ok(!res, "accounts[3] should not be operator");
    res = await systemRewardInstance.isOperator.call(accounts[4]);
    assert.ok(!res, "accounts[4] should not be operator");
  });


  it('claim reward success', async () => {
    const systemRewardInstance = await SystemReward.deployed();
    let newAccount = web3.eth.accounts.create();

    await systemRewardInstance.send(1e8, {from: accounts[3]});
    let tx = await systemRewardInstance.claimRewards(newAccount.address, 1e7, {from: accounts[0]})

    truffleAssert.eventEmitted(tx, "rewardTo",(ev) => {
      return ev.amount.toNumber() === 1e7 && ev.to === newAccount.address;
    });

    let balance_wei = await web3.eth.getBalance(newAccount.address);
    assert.equal(balance_wei, 1e7, "balance not equal");
  });

  it('claim reward failed', async () => {
    const systemRewardInstance = await SystemReward.deployed();
    let newAccount = web3.eth.accounts.create();

    await systemRewardInstance.send(1e8, {from: accounts[3]});
    try{
      await systemRewardInstance.claimRewards(newAccount.address, 1e7, {from: accounts[3]})
      assert.fail();
    }catch (error) {
      assert.ok(error.toString().includes("only operator is allowed to call the method"));
    }
  });
});

contract('SystemReward', (accounts) => {
  
  it('claim empty reward', async () => {
    const systemRewardInstance = await SystemReward.deployed();
    let newAccount = web3.eth.accounts.create();
    let tx = await systemRewardInstance.claimRewards(newAccount.address, 1e7, {from: accounts[0]})
    truffleAssert.eventEmitted(tx, "rewardEmpty");
    let balance_wei = await web3.eth.getBalance(newAccount.address);
    assert.equal(balance_wei, 0, "balance not equal");
  });
});
