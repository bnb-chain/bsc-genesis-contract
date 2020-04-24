const SlashIndicator = artifacts.require("SlashIndicator");
const BSCValidatorSet = artifacts.require("BSCValidatorSet");
const Web3 = require('web3');
const crypto = require('crypto');
const SystemReward = artifacts.require("SystemReward");
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

contract('SlashIndicator', (accounts) => {
  it('slash success', async () => {
    const slashInstance = await SlashIndicator.deployed();
    const accountOne = accounts[0];
    
    let validatorAccount = web3.eth.accounts.create();
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
      assert.ok(error.toString().includes("the message sender must be the block producer"), "slash from no system account should not be ok");
    }
  });

  it('catch emit event', async () => {
    const slashInstance = await SlashIndicator.deployed();

    const accountOne = accounts[0];
    let validatorAccount = web3.eth.accounts.create();
    for (let i =1; i<50; i++){
      let tx = await slashInstance.slash(validatorAccount.address, { from: accountOne });
      truffleAssert.eventEmitted(tx, "validatorSlashed",(ev) => {
        return ev.validator === validatorAccount.address;
      });
    }
  });


  it('isOperator works', async () => {
    const slashInstance = await SlashIndicator.deployed();

    const accountOne = accounts[0];
    let validatorAccount1 = web3.eth.accounts.create();
    let validatorAccount2 = web3.eth.accounts.create();

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

  it('trigger misdemeanor', async () => {
    const slashInstance = await SlashIndicator.deployed();
    const validatorSetInstance = await BSCValidatorSet.deployed();
    const systemRewardInstance = await SystemReward.deployed();

    const systemAccount = accounts[0];
    let validator = accounts[0];
    let secondValidator = accounts[1];
    let thirdValidator = accounts[2];

    await validatorSetInstance.deposit(validator, {from: systemAccount, value: 1e18 });
    await systemRewardInstance.addOperator(validatorSetInstance.address, {from: systemAccount});

    let amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString())

    for (let i =1; i<=50; i++){
      await slashInstance.slash(validator, { from: systemAccount });
    }

    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toNumber(),0);

    await validatorSetInstance.handlePackage(serialize([validator,secondValidator,thirdValidator],
        [validator,secondValidator,thirdValidator],[validator,secondValidator,thirdValidator]), crypto.randomBytes(32),100, 0, {from: accounts[8]});

    await validatorSetInstance.deposit(validator, {from: systemAccount, value: 2e18 });
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toString(),web3.utils.toBN(2e18).toString())
    for (let i =1; i<=50; i++){
      await slashInstance.slash(validator, { from: systemAccount });
    }
    let res= (await slashInstance.getSlashIndicator.call(validator));
    assert.equal(res[1].toNumber(),50);
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toNumber(),0);
    amount = await validatorSetInstance.getIncoming.call(secondValidator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString())
    amount = await validatorSetInstance.getIncoming.call(thirdValidator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString())
    


    await validatorSetInstance.deposit(secondValidator, {from: systemAccount, value: 1e18 });
    amount = await validatorSetInstance.getIncoming.call(secondValidator);
    assert.equal(amount.toString(),web3.utils.toBN(2e18).toString())
    for (let i =1; i<=50; i++){
      await slashInstance.slash(secondValidator, { from: systemAccount });
    }
    res= (await slashInstance.getSlashIndicator.call(secondValidator));
    assert.equal(res[1].toNumber(),50);
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString())
    amount = await validatorSetInstance.getIncoming.call(secondValidator);
    assert.equal(amount.toNumber(),0);
    amount = await validatorSetInstance.getIncoming.call(thirdValidator);
    assert.equal(amount.toString(),web3.utils.toBN(2e18).toString())

    for (let i =1; i<=50; i++){
      await slashInstance.slash(thirdValidator, { from: systemAccount });
    }
    res= (await slashInstance.getSlashIndicator.call(thirdValidator));
    assert.equal(res[1].toNumber(),50);
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toString(),web3.utils.toBN(2e18).toString())
    amount = await validatorSetInstance.getIncoming.call(secondValidator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString())
    amount = await validatorSetInstance.getIncoming.call(thirdValidator);
    assert.equal(amount.toNumber(),0);

  });


  it('trigger felony ', async () => {
    const slashInstance = await SlashIndicator.deployed();
    const validatorSetInstance = await BSCValidatorSet.deployed();

    const systemAccount = accounts[0];
    let validator = accounts[0];
    let secondValidator = accounts[1];
    let thirdValidator = accounts[2];
    await validatorSetInstance.handlePackage(serialize([validator,secondValidator,thirdValidator],
        [validator,secondValidator,thirdValidator],[validator,secondValidator,thirdValidator]), crypto.randomBytes(32),100, 1, {from: accounts[8]});

    await validatorSetInstance.deposit(validator, {from: systemAccount, value: 2e18 });
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toString(),web3.utils.toBN(2e18).toString())
    for (let i =1; i<=150; i++){
      await slashInstance.slash(validator, { from: systemAccount });
    }

    let res= (await slashInstance.getSlashIndicator.call(validator));
    assert.equal(res[1].toNumber(),150);
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toNumber(),0);
    amount = await validatorSetInstance.getIncoming.call(secondValidator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString());
    amount = await validatorSetInstance.getIncoming.call(thirdValidator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString());
    let consensusAddres = await validatorSetInstance.getValidators.call();
    assert.equal(consensusAddres.length,2);
    assert.equal(consensusAddres[0],thirdValidator);
    assert.equal(consensusAddres[1],secondValidator);


    await validatorSetInstance.handlePackage(serialize([validator,secondValidator,thirdValidator],
        [validator,secondValidator,thirdValidator],[validator,secondValidator,thirdValidator]), crypto.randomBytes(32),100, 2, {from: accounts[8]});

    await validatorSetInstance.deposit(secondValidator, {from: systemAccount, value: 2e18 });
    amount = await validatorSetInstance.getIncoming.call(secondValidator);
    assert.equal(amount.toString(),web3.utils.toBN(2e18).toString())
    for (let i =1; i<=150; i++){
      await slashInstance.slash(secondValidator, { from: systemAccount });
    }

    res= (await slashInstance.getSlashIndicator.call(secondValidator));
    assert.equal(res[1].toNumber(),150);
    amount = await validatorSetInstance.getIncoming.call(secondValidator);
    assert.equal(amount.toNumber(),0);
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString());
    amount = await validatorSetInstance.getIncoming.call(thirdValidator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString());
    consensusAddres = await validatorSetInstance.getValidators.call();
    assert.equal(consensusAddres.length,2);
    assert.equal(consensusAddres[0],validator);
    assert.equal(consensusAddres[1],thirdValidator);

    await validatorSetInstance.handlePackage(serialize([validator,secondValidator,thirdValidator],
        [validator,secondValidator,thirdValidator],[validator,secondValidator,thirdValidator]), crypto.randomBytes(32),100, 3, {from: accounts[8]});

    await validatorSetInstance.deposit(thirdValidator, {from: systemAccount, value: 2e18 });
    amount = await validatorSetInstance.getIncoming.call(thirdValidator);
    assert.equal(amount.toString(),web3.utils.toBN(2e18).toString())
    for (let i =1; i<=150; i++){
      await slashInstance.slash(thirdValidator, { from: systemAccount });
    }

    res= (await slashInstance.getSlashIndicator.call(thirdValidator));
    assert.equal(res[1].toNumber(),150);
    amount = await validatorSetInstance.getIncoming.call(thirdValidator);
    assert.equal(amount.toNumber(),0);
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString());
    amount = await validatorSetInstance.getIncoming.call(secondValidator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString());
    consensusAddres = await validatorSetInstance.getValidators.call();
    assert.equal(consensusAddres.length,2);
    assert.equal(consensusAddres[0],validator);
    assert.equal(consensusAddres[1],secondValidator);

  });
});

function serialize(consensusAddrList,feeAddrList, bscFeeAddrList) {
  let n = consensusAddrList.length;
  let arr = [];
  arr.push(Buffer.from(web3.utils.hexToBytes("0x00")));
  for(let i = 0;i<n;i++){
    arr.push(Buffer.from(web3.utils.hexToBytes(consensusAddrList[i].toString())));
    arr.push(Buffer.from(web3.utils.hexToBytes(feeAddrList[i].toString())));
    arr.push(Buffer.from(web3.utils.hexToBytes(bscFeeAddrList[i].toString())));
    arr.push(Buffer.from(web3.utils.hexToBytes("0x0000000000000064")));
  }
  return Buffer.concat(arr);
}
