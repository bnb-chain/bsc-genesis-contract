const SlashIndicator = artifacts.require("SlashIndicator");
const BSCValidatorSet = artifacts.require("BSCValidatorSet");
const Web3 = require('web3');
const crypto = require('crypto');
const RLP = require('rlp');
const SystemReward = artifacts.require("SystemReward");
const truffleAssert = require('truffle-assertions');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));
const STAKE_CHANNEL_ID = 0x08;

contract('SlashIndicator', (accounts) => {
  it('slash success', async () => {
    const slashInstance = await SlashIndicator.deployed();
    const validatorInstance = await BSCValidatorSet.deployed();

    const accountOne = accounts[0];

    let validatorAccounts = await validatorInstance.getMiningValidators.call();
    let validatorAccount = validatorAccounts[0];

    for (let i =1; i<10; i++){
      await slashInstance.slash(validatorAccount, { from: accountOne });
      let res= (await slashInstance.getSlashIndicator.call(validatorAccount));
      let count =res[1].toNumber();
      assert.equal(count, i, "slash num is not correct");
    }
  });

  it('slash from no system account', async () => {
    const slashInstance = await SlashIndicator.deployed();
    const validatorInstance = await BSCValidatorSet.deployed();

    const nonSystemAccount = accounts[1];
    let validatorAccounts = await validatorInstance.getMiningValidators.call();
    let validatorAccount = validatorAccounts[0];
    // first slash
    try{
      await slashInstance.slash(validatorAccount, { from: nonSystemAccount });
      assert.fail();
    }catch (error) {
      assert.ok(error.toString().includes("the message sender must be the block producer"), "slash from no system account should not be ok");
    }
  });
});

contract('SlashIndicator: isOperator works', (accounts) => {
  it('isOperator works', async () => {
    const slashInstance = await SlashIndicator.deployed();
    const validatorInstance = await BSCValidatorSet.deployed();

    const accountOne = accounts[0];
    let validatorAccounts = await validatorInstance.getMiningValidators.call();
    let validatorAccount = validatorAccounts[0];

    // slash afterward
    for (let i =1; i<10; i++){
      await slashInstance.slash(validatorAccount, { from: accountOne });
      let res= (await slashInstance.getSlashIndicator.call(validatorAccount));
      let count =res[1].toNumber();
      assert.equal(count, i, "slash num is not correct for validator");
    }
  });
});


contract('SlashIndicator: catch emit event', (accounts) => {
  it('catch emit event', async () => {
      const slashInstance = await SlashIndicator.deployed();
      const validatorInstance = await BSCValidatorSet.deployed();
  
      const accountOne = accounts[0];
      let validatorAccounts = await validatorInstance.getMiningValidators.call();
      let validatorAccount = validatorAccounts[0];
      for (let i =1; i<50; i++){
        let tx = await slashInstance.slash(validatorAccount, { from: accountOne });
        truffleAssert.eventEmitted(tx, "validatorSlashed",(ev) => {
          return ev.validator === validatorAccount;
        });
      }
    });
});


contract('SlashIndicator', (accounts) => {
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

    let packageBytes = validatorUpdateRlpEncode([validator,secondValidator,thirdValidator],
        [validator,secondValidator,thirdValidator],[validator,secondValidator,thirdValidator]);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: accounts[8]});

    await validatorSetInstance.deposit(validator, {from: systemAccount, value: 2e18 });
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toString(),web3.utils.toBN(2e18).toString())
    for (let i =1; i<=4; i++){
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
});

contract('felony SlashIndicator', (accounts) => {
  it('trigger felony ', async () => {
    const slashInstance = await SlashIndicator.deployed();
    const validatorSetInstance = await BSCValidatorSet.deployed();

    const systemAccount = accounts[0];
    let validator = accounts[0];
    let secondValidator = accounts[1];
    let thirdValidator = accounts[2];

    let packageBytes = validatorUpdateRlpEncode([validator,secondValidator,thirdValidator],
        [validator,secondValidator,thirdValidator],[validator,secondValidator,thirdValidator]);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: accounts[8]});

    await validatorSetInstance.deposit(validator, {from: systemAccount, value: 2e18 });
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toString(),web3.utils.toBN(2e18).toString(), "case1: incoming of account1 is wrong")
    for (let i =1; i<=150; i++){
      await slashInstance.slash(validator, { from: systemAccount });
    }

    let res= (await slashInstance.getSlashIndicator.call(validator));
    assert.equal(res[1].toNumber(),0, "case1: slash indicator of account1 is wrong");
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toNumber(),0, "case1: incoming of account1 is wrong");
    amount = await validatorSetInstance.getIncoming.call(secondValidator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString(), "case1: incoming of account2 is wrong");
    amount = await validatorSetInstance.getIncoming.call(thirdValidator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString(), "case1: incoming of account3 is wrong");
    let consensusAddress = await validatorSetInstance.getValidators.call();
    assert.equal(consensusAddress.length,2, "case1: length of validators should be 2");
    assert.equal(consensusAddress[0],secondValidator, "case1: index 0 of validators should be account2");
    assert.equal(consensusAddress[1],thirdValidator, "case1: index 1 of validators should be account3");

    packageBytes = validatorUpdateRlpEncode([validator,secondValidator,thirdValidator],
        [validator,secondValidator,thirdValidator],[validator,secondValidator,thirdValidator]);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: accounts[8]});

    await validatorSetInstance.deposit(secondValidator, {from: systemAccount, value: 2e18 });
    amount = await validatorSetInstance.getIncoming.call(secondValidator);
    assert.equal(amount.toString(),web3.utils.toBN(2e18).toString(), "case2: incoming of account2 is wrong")
    for (let i =1; i<=150; i++){
      await slashInstance.slash(secondValidator, { from: systemAccount });
    }

    res= (await slashInstance.getSlashIndicator.call(secondValidator));
    assert.equal(res[1].toNumber(),0, "case2: slash indicator of account2 is wrong");
    amount = await validatorSetInstance.getIncoming.call(secondValidator);
    assert.equal(amount.toNumber(),0, "case2: incoming of account2 is wrong");
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString(), "case2: incoming of account1 is wrong");
    amount = await validatorSetInstance.getIncoming.call(thirdValidator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString(), "case2: incoming of account3 is wrong");
    consensusAddress = await validatorSetInstance.getValidators.call();
    assert.equal(consensusAddress.length,2, "case2: length of validators should be 2");
    assert.equal(consensusAddress[0],validator, "case2: index 0 of validators should be account1");
    assert.equal(consensusAddress[1],thirdValidator, "case2: index 1 of validators should be account3");

    packageBytes = validatorUpdateRlpEncode([validator,secondValidator,thirdValidator],
        [validator,secondValidator,thirdValidator],[validator,secondValidator,thirdValidator]);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: accounts[8]});

    await validatorSetInstance.deposit(thirdValidator, {from: systemAccount, value: 2e18 });
    amount = await validatorSetInstance.getIncoming.call(thirdValidator);
    assert.equal(amount.toString(),web3.utils.toBN(2e18).toString(), "case3: incoming of account3 is wrong")
    for (let i =1; i<=150; i++){
      await slashInstance.slash(thirdValidator, { from: systemAccount });
    }

    res= (await slashInstance.getSlashIndicator.call(thirdValidator));
    assert.equal(res[1].toNumber(),0, "case3: slash indicator of account3 is wrong");
    amount = await validatorSetInstance.getIncoming.call(thirdValidator);
    assert.equal(amount.toNumber(),0, "case3: incoming of account3 is wrong");
    amount = await validatorSetInstance.getIncoming.call(validator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString(), "case3: incoming of account1 is wrong");
    amount = await validatorSetInstance.getIncoming.call(secondValidator);
    assert.equal(amount.toString(),web3.utils.toBN(1e18).toString(), "case3: incoming of account2 is wrong");
    consensusAddress = await validatorSetInstance.getValidators.call();
    assert.equal(consensusAddress.length,2, "case3: length of validators should be 2");
    assert.equal(consensusAddress[0],validator, "case3: index 0 of validators should be account1");
    assert.equal(consensusAddress[1],secondValidator, "case3: index 0 of validators should be account2");

  });
});

contract('Clean SlashIndicator', (accounts) => {
  it('test slash clean', async () => {
    const slashInstance = await SlashIndicator.deployed();
    const validatorSetInstance = await BSCValidatorSet.deployed();
    let newValidator = web3.eth.accounts.create();
    let relayerAccount = accounts[8];
    const accountOne = accounts[0];

    // case 1: all clean.
    let validators = [];
    for(let i =0;i <20; i++){
      validators.push(web3.eth.accounts.create().address);
    }
    // Do init
    let packageBytes = validatorUpdateRlpEncode(validators,
        validators,validators);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    for(let i =0;i <20;i++){
      await slashInstance.slash(validators[i], { from: accountOne });
    }

    // doclean
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    let res= (await slashInstance.getSlashValidators.call());
    assert.equal(res.length, 0);

    for(let i =0;i <20;i++){
      let res = await slashInstance.getSlashIndicator.call(validators[i]);
      let count =res[1].toNumber();
      let height = res[0].toNumber();
      assert.equal(count, 0);
      assert.equal(height, 0);
    }

    // case 2: all stay.
    for(let i =0;i <20;i++){
      for(let j=0;j<5;j++){
        await slashInstance.slash(validators[i], { from: accountOne });
      }
    }
    // doclean
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});
    res= (await slashInstance.getSlashValidators.call());
    assert.equal(res.length, 20);
    for(let i =0;i <20;i++){
      let res = await slashInstance.getSlashIndicator.call(validators[i]);
      let count =res[1].toNumber();
      assert.equal(count, 1);
    }

    // case 3: partial stay.
    for(let i =0;i <10;i++){
      for(let j=0;j<5;j++){
        await slashInstance.slash(validators[2*i], { from: accountOne });
      }
      await slashInstance.slash(validators[2*i+1], { from: accountOne });
    }
    // doclean
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});
    res= (await slashInstance.getSlashValidators.call());
    assert.equal(res.length, 10);
    for(let i =0;i <20;i++){
      let res = await slashInstance.getSlashIndicator.call(validators[i]);
      let count =res[1].toNumber();
      if(i%2==0){
        assert.equal(count, 2);
      }else{
        assert.equal(count, 0);
      }
    }

    // case 4: partial stay.
    for(let i =0;i <10;i++){
      for(let j=0;j<5;j++){
        await slashInstance.slash(validators[2*i+1], { from: accountOne });
      }
      await slashInstance.slash(validators[2*i], { from: accountOne });
    }
    // doclean
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});
    res= (await slashInstance.getSlashValidators.call());
    assert.equal(res.length, 10);
    for(let i =0;i <20;i++){
      let res = await slashInstance.getSlashIndicator.call(validators[i]);
      let count =res[1].toNumber();
      if(i%2==0){
        assert.equal(count, 0);
      }else{
        assert.equal(count, 1);
      }
    }

  });
});


function validatorUpdateRlpEncode(consensusAddrList,feeAddrList, bscFeeAddrList) {
  let pkg = [];
  pkg.push(0x00);
  let n = consensusAddrList.length;
  let vals = [];
  for(let i = 0;i<n;i++) {
    vals.push([
      consensusAddrList[i].toString(),
      feeAddrList[i].toString(),
      bscFeeAddrList[i].toString(),
      0x0000000000000064,
    ]);
  }
  pkg.push(vals);
  return RLP.encode(pkg)
}