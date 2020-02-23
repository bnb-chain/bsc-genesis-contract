const SlashIndicator = artifacts.require("SlashIndicator");
const Web3 = require('web3');
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

contract('SlashIndicator', (accounts) => {
  it('slash success', async () => {
    const slashInstance = await SlashIndicator.deployed();

    const accountOne = accounts[0];
    let validatorAccount = web3.eth.accounts.create();

    // first slash
    await slashInstance.slash(validatorAccount.address, { from: accountOne });
    let res= (await slashInstance.getSlashIndicator.call(validatorAccount.address));
    let count =res[1].toNumber();
    assert.equal(count, 0, "first slash should not count");

    // slash afterward
    for (let i =1; i<10; i++){
      await slashInstance.slash(validatorAccount.address, { from: accountOne });
      let res= (await slashInstance.getSlashIndicator.call(validatorAccount.address));
      let count =res[1].toNumber();
      assert.equal(count, i, "slash num is not correct");
    }
  });
  
  it('slash from no system account', async () => {
    const slashInstance = await SlashIndicator.deployed();

    const nonSystemAccount = accounts[1];
    let validatorAccount = web3.eth.accounts.create();

    // first slash
    try{
      await slashInstance.slash(validatorAccount.address, { from: nonSystemAccount });
      assert.fail();
    }catch (error) {
      assert.ok(error.toString().includes("the message sender must be system account"), "slash from no system account should not be ok");
    }
  });

  it('catch emit event', async () => {
    const slashInstance = await SlashIndicator.deployed();

    const accountOne = accounts[0];
    let validatorAccount = web3.eth.accounts.create();

    // first slash
    await slashInstance.slash(validatorAccount.address, { from: accountOne });
    let res= (await slashInstance.getSlashIndicator.call(validatorAccount.address));
    let count =res[1].toNumber();
    assert.equal(count, 0, "first slash should not count");

    // slash afterward
    for (let i =1; i<100; i++){
      let tx = await slashInstance.slash(validatorAccount.address, { from: accountOne });
      truffleAssert.eventNotEmitted(tx, "ValidatorSlashed");
    }
    let tx = await slashInstance.slash(validatorAccount.address, { from: accountOne });
    truffleAssert.eventEmitted(tx, "ValidatorSlashed",(ev) => {
      return ev.validator === validatorAccount.address;
    });
  });


  it('isOperator works', async () => {
    const slashInstance = await SlashIndicator.deployed();

    const accountOne = accounts[0];
    let validatorAccount1 = web3.eth.accounts.create();
    let validatorAccount2 = web3.eth.accounts.create();

    // first slash
    await slashInstance.slash(validatorAccount1.address, { from: accountOne });
    await slashInstance.slash(validatorAccount2.address, { from: accountOne });

    // slash afterward
    for (let i =1; i<10; i++){
      await slashInstance.slash(validatorAccount1.address, { from: accountOne });
      let res= (await slashInstance.getSlashIndicator.call(validatorAccount1.address));
      let count =res[1].toNumber();
      assert.equal(count, i, "slash num is not correct for validator 1");

      await slashInstance.slash(validatorAccount2.address, { from: accountOne });
      res= (await slashInstance.getSlashIndicator.call(validatorAccount2.address));
      count =res[1].toNumber();
      assert.equal(count, i, "slash num is not correct for validator 2");
    }
  });
  
});