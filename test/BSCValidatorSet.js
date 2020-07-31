const BSCValidatorSet = artifacts.require("BSCValidatorSet");
const SystemReward = artifacts.require("SystemReward");
const LightClient = artifacts.require("MockLightClient");
const crypto = require('crypto');
const MockTokenHub = artifacts.require("mock/MockTokenHub");
const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));
const RLP = require('rlp');
const truffleAssert = require('truffle-assertions');
const CrossChain = artifacts.require("CrossChain");
const STAKE_CHANNEL_ID = 0x08;

const packageBytesPrefix = Buffer.from(web3.utils.hexToBytes(
    "0x00" +
    "000000000000000000000000000000000000000000000000002386F26FC10000"
));

contract('BSCValidatorSet', (accounts) => {
  it('query basic info', async () => {
    const validatorSetInstance = await BSCValidatorSet.deployed();

    let totalInComing = await validatorSetInstance.totalInComing.call();
    assert.equal(totalInComing,0, "totalInComing should be 0");

    let consensusAddr = await validatorSetInstance.getValidators.call()[0];
    assert.equal(consensusAddr,accounts[9].address, "consensusAddr should be accounts[9]");
  });

  it('deposit success and fail', async () => {
    const validatorSetInstance = await BSCValidatorSet.deployed();
    let validator =  accounts[0];
    let systemAccount = accounts[0];
    let tx = await validatorSetInstance.deposit(validator, {from: systemAccount, value: 1e8 });

    truffleAssert.eventEmitted(tx, "validatorDeposit",(ev) => {
      return ev.amount.toNumber() === 1e8 && ev.validator === validator;
    });

    let tmpAccount = web3.eth.accounts.create();
    tx = await validatorSetInstance.deposit(tmpAccount.address, {from: systemAccount, value: 1e8 });

    truffleAssert.eventEmitted(tx, "deprecatedDeposit",(ev) => {
      return ev.amount.toNumber() === 1e8 && ev.validator === tmpAccount.address;
    });

    try{
      await validatorSetInstance.deposit(validator, {from: accounts[2], value: 1e8 });
      assert.fail();
    }catch (error) {
      assert.ok(error.toString().includes("the message sender must be the block producer"));
    }

    try{
      await validatorSetInstance.deposit(validator, {from: systemAccount, value: 0 });
      assert.fail();
    }catch (error) {
      assert.ok(error.toString().includes("deposit value is zero"));
    }

    try{
      await validatorSetInstance.send(1e8, {from: systemAccount});
      assert.fail();
    }catch (error) {
    }

    let totalInComing = await validatorSetInstance.totalInComing.call();
    assert.equal(totalInComing.toNumber(),1e8, "totalInComing should be 1e8");

    let balance_wei = await web3.eth.getBalance(validatorSetInstance.address);
    assert.equal(balance_wei, 2e8, "balance not equal");
  });



});

contract('BSCValidatorSet', (accounts) => {
  it('test distribute algorithm', async () => {
    const validatorSetInstance = await BSCValidatorSet.deployed();
    const systemRewardInstance = await SystemReward.deployed();

    let validator =  accounts[0];
    let systemAccount = accounts[0];
    let tmpAccount = web3.eth.accounts.create();

    // enough reward in system reward pool
    await systemRewardInstance.send(web3.utils.toBN(1e18), {from: accounts[1]});


    for(let i =0;i <5; i++){
      await validatorSetInstance.deposit(validator, {from: systemAccount, value: 1e8 });
      await validatorSetInstance.deposit(tmpAccount.address, {from: systemAccount, value: 1e8 });
    }

    for(let i =0;i <5; i++){
      await validatorSetInstance.deposit(validator, {from: systemAccount, value: web3.utils.toBN(1e18) });
      await validatorSetInstance.deposit(tmpAccount.address, {from: systemAccount, value: web3.utils.toBN(1e18) });
    }
    
    let newValidator = web3.eth.accounts.create();
    let relayerAccount = accounts[8];

    //before
    let totalBalance = await web3.eth.getBalance(validatorSetInstance.address);
    let totalInComing = await validatorSetInstance.totalInComing.call();
    let relayerBalance = await web3.eth.getBalance(relayerAccount);

    assert.equal(totalInComing.toString(), web3.utils.toBN(5e18).add(web3.utils.toBN(5e8)).toString(), "totalInComing is not correct");
    assert.equal(totalBalance.toString(), web3.utils.toBN(1e19).add(web3.utils.toBN(1e9)).toString(), "totalbalance is not correct");

    // do update
    let packageBytes = validatorUpdateRlpEncode([newValidator.address],
        [newValidator.address],[newValidator.address]);
    let tx = await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    truffleAssert.eventEmitted(tx, "validatorSetUpdated");
    truffleAssert.eventEmitted(tx, "batchTransfer",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(5e18).toString();
    });
    truffleAssert.eventEmitted(tx, "systemTransfer",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(5e18).add(web3.utils.toBN(1e9)).toString();
    });

    let used_wei = web3.utils.toBN(20000000000).muln(tx.receipt.gasUsed);

    // after
    totalBalance = await web3.eth.getBalance(validatorSetInstance.address);
    totalInComing = await validatorSetInstance.totalInComing.call();
    let afterRelayerBalance = await web3.eth.getBalance(relayerAccount);

    assert.equal(web3.utils.toBN(relayerBalance).sub(web3.utils.toBN(afterRelayerBalance)).toString(), used_wei.toString(), "totalInComing is not correct");
    assert.equal(totalInComing.toNumber(), 0, "totalInComing is not correct");
    assert.equal(totalBalance, 0, "totalbalance is not correct");

  });

});

contract('BSCValidatorSet', (accounts) => {
  it('complicate validatorSet change and test valdiatorset map', async () => {
    const validatorSetInstance = await BSCValidatorSet.deployed();
    const systemRewardInstance = await SystemReward.deployed();

    let validatorA =  accounts[0];
    let validatorB = web3.eth.accounts.create().address;
    let validatorC = web3.eth.accounts.create().address;
    let validatorD = web3.eth.accounts.create().address;
    let validatorE = web3.eth.accounts.create().address;
    let relayerAccount = accounts[8];

    // enough reward in system reward pool
    await systemRewardInstance.send(web3.utils.toBN(1e18), {from: accounts[1]});

    await validatorSetInstance.getValidators.call();
    let arrs = [[validatorB,validatorA,validatorC,validatorD],
                [validatorB,validatorC,validatorE],
                [validatorB,validatorC,validatorE],
                [validatorE,validatorC,validatorB],
                [validatorE,validatorC,validatorB,validatorA,validatorD],
                [validatorE,validatorC,validatorB,validatorA]];
    for(let j=0;j<arrs.length;j++){
      let arr = arrs[j];
      let packageBytes = validatorUpdateRlpEncode(arr, arr,arr);
      await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});
      let consensusAddres = await validatorSetInstance.getValidators.call();
      assert.equal(consensusAddres.length, arr.length);
      for(let i =0;i<consensusAddres.length;i++){
        assert.equal(consensusAddres[i],arr[i], "consensusAddr not equal");
      }
      for(let k=0;k<arr.length;k++){
        let exist = await validatorSetInstance.isValidatorExist.call(arr[k]);
        if (!exist){
          console.log(j, k);
        }
        assert.equal(exist,true, "the address should be a validator");
      }
    }
  });
});


contract('BSCValidatorSet', (accounts) => {
  it('failed to update', async () => {
    const validatorSetInstance = await BSCValidatorSet.deployed();
    const systemRewardInstance = await SystemReward.deployed();
    const crossChain = await CrossChain.deployed();

    let validatorA =  accounts[0];
    let validatorB = web3.eth.accounts.create().address;
    let validatorC = web3.eth.accounts.create().address;
    let validatorD = web3.eth.accounts.create().address;
    let validatorE = web3.eth.accounts.create().address;
    let relayerAccount = accounts[8];
    // enough reward in system reward pool
    await systemRewardInstance.send(web3.utils.toBN(1e18), {from: accounts[1]});

    let arrs = [[validatorB,validatorA,validatorC,validatorD],
      [validatorB,validatorB,validatorE],
      [validatorC,validatorC,validatorB],
      []];
    let packageBytes = validatorUpdateRlpEncode(arrs[0], arrs[0], arrs[0]);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    for(let j=1;j<arrs.length-1;j++){
      let arr = arrs[j];
      let packageBytes = validatorUpdateRlpEncode(arr, arr,arr);
      let tx = await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});
      truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
        return ev.message === "duplicate consensus address of validatorSet";
      });
    }
    let arr =arrs[3];

    packageBytes = validatorUpdateRlpEncode(arr, arr,arr);
    let tx = await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});
    truffleAssert.eventNotEmitted(tx, "failReasonWithStr");
    // block the light client
    const lightClientInstance = await LightClient.deployed();
    await lightClientInstance.setBlockNotSynced(true);

    let validArray = arrs[0];
    try{
      packageBytes = validatorUpdateRlpEncode(validArray, validArray,validArray);
      await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), crypto.randomBytes(32),100, 0, STAKE_CHANNEL_ID, {from: relayerAccount});
      assert.fail();
    }catch(error){
      assert.ok(error.toString().includes("light client not sync the block yet"));
    }
    await lightClientInstance.setBlockNotSynced(false);
    try{
      packageBytes = validatorUpdateRlpEncode(validArray, validArray,validArray);
      await crossChain.handlePackage(Buffer.concat([packageBytesPrefix, packageBytes]), crypto.randomBytes(32),100, 0, STAKE_CHANNEL_ID, {from: accounts[4]});
      assert.fail();
    }catch(error){
      assert.ok(error.toString().includes("the msg sender is not a relayer"));
    }

  });
});

contract('BSCValidatorSet', (accounts) => {
  it('complicate distribute', async () => {
    const validatorSetInstance = await BSCValidatorSet.deployed();
    const systemRewardInstance = await SystemReward.deployed();

    let validatorA = web3.eth.accounts.create().address;
    let validatorB = web3.eth.accounts.create().address;
    let validatorC = web3.eth.accounts.create().address;
    let validatorD = web3.eth.accounts.create().address;
    let validatorE = web3.eth.accounts.create().address;
    let deprecated = web3.eth.accounts.create().address;
    let relayerAccount = accounts[8];
    let systemAccount = accounts[0];

    // enough reward in system reward pool
    await systemRewardInstance.send(web3.utils.toBN(1e18), {from: accounts[1]});

    await validatorSetInstance.getValidators.call();
    let arr = [validatorA,validatorB,validatorC,validatorD,validatorE];

    let packageBytes = validatorUpdateRlpEncode(arr, arr,arr);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    // deposit A: 1e16 B:1e16 C:1e17, D: 1e18, E:1e19, deprecated: 1e18
    await validatorSetInstance.deposit(validatorA, {from: systemAccount, value: web3.utils.toBN(1e16) });
    await validatorSetInstance.deposit(validatorB, {from: systemAccount, value: web3.utils.toBN(1e16) });
    await validatorSetInstance.deposit(validatorC, {from: systemAccount, value: web3.utils.toBN(1e17) });
    await validatorSetInstance.deposit(validatorD, {from: systemAccount, value: web3.utils.toBN(1e18) });
    await validatorSetInstance.deposit(validatorE, {from: systemAccount, value: web3.utils.toBN(1e18) });
    await validatorSetInstance.deposit(deprecated, {from: systemAccount, value: web3.utils.toBN(1e18) });

    //add some dust incoming
    await validatorSetInstance.deposit(validatorE, {from: systemAccount, value: web3.utils.toBN(1e5) });

    packageBytes = validatorUpdateRlpEncode(arr, arr,arr);
    let tx = await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});
    let validatorABalance = await web3.eth.getBalance(validatorA);
    let validatorBBalance = await web3.eth.getBalance(validatorB);
    let validatorCBalance = await web3.eth.getBalance(validatorC);
    let validatorDBalance = await web3.eth.getBalance(validatorD);
    let validatorEBalance = await web3.eth.getBalance(validatorE);
    let deprecatedBalance = await web3.eth.getBalance(deprecated);

    assert.equal(validatorABalance,web3.utils.toBN(1e16));
    assert.equal(validatorBBalance,web3.utils.toBN(1e16));
    assert.equal(validatorCBalance,0);
    assert.equal(validatorDBalance,0);
    assert.equal(validatorEBalance,0);
    assert.equal(deprecatedBalance,0);

    truffleAssert.eventEmitted(tx, "validatorSetUpdated");
    truffleAssert.eventEmitted(tx, "batchTransfer",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(21e17).toString();
    });
    truffleAssert.eventEmitted(tx, "directTransfer",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(1e16).toString();
    });
    truffleAssert.eventEmitted(tx, "systemTransfer",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(1e18).add(web3.utils.toBN(1e5)).toString();
    });
  });
});


contract('BSCValidatorSet', (accounts) => {
  it('complicate distribute when one validar fee addr is contract', async () => {
    const validatorSetInstance = await BSCValidatorSet.deployed();
    const systemRewardInstance = await SystemReward.deployed();

    let validatorA = validatorSetInstance.address;
    let validatorB = web3.eth.accounts.create().address;
    let validatorC = web3.eth.accounts.create().address;
    let validatorD = web3.eth.accounts.create().address;
    let validatorE = web3.eth.accounts.create().address;
    let deprecated = web3.eth.accounts.create().address;
    let relayerAccount = accounts[8];
    let systemAccount = accounts[0];

    // enough reward in system reward pool
    await systemRewardInstance.send(web3.utils.toBN(1e18), {from: accounts[1]});

    await validatorSetInstance.getValidators.call();
    let arr = [validatorA,validatorB,validatorC,validatorD,validatorE];

    let packageBytes = validatorUpdateRlpEncode(arr, arr,arr);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    // deposit A: 1e16 B:1e16 C:1e17, D: 1e18, E:1e19, deprecated: 1e18
    await validatorSetInstance.deposit(validatorA, {from: systemAccount, value: web3.utils.toBN(1e16) });
    await validatorSetInstance.deposit(validatorB, {from: systemAccount, value: web3.utils.toBN(1e16) });
    await validatorSetInstance.deposit(validatorC, {from: systemAccount, value: web3.utils.toBN(1e17) });
    await validatorSetInstance.deposit(validatorD, {from: systemAccount, value: web3.utils.toBN(1e18) });
    await validatorSetInstance.deposit(validatorE, {from: systemAccount, value: web3.utils.toBN(1e18) });
    await validatorSetInstance.deposit(deprecated, {from: systemAccount, value: web3.utils.toBN(1e18) });

    //add some dust incoming
    await validatorSetInstance.deposit(validatorE, {from: systemAccount, value: web3.utils.toBN(1e5) });

    packageBytes = validatorUpdateRlpEncode(arr, arr,arr);
    let tx = await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    let validatorABalance = await web3.eth.getBalance(validatorA);
    let validatorBBalance = await web3.eth.getBalance(validatorB);
    let validatorCBalance = await web3.eth.getBalance(validatorC);
    let validatorDBalance = await web3.eth.getBalance(validatorD);
    let validatorEBalance = await web3.eth.getBalance(validatorE);
    let deprecatedBalance = await web3.eth.getBalance(deprecated);

    assert.equal(validatorABalance,0);
    assert.equal(validatorBBalance,web3.utils.toBN(1e16));
    assert.equal(validatorCBalance,0);
    assert.equal(validatorDBalance,0);
    assert.equal(validatorEBalance,0);
    assert.equal(deprecatedBalance,0);

    truffleAssert.eventEmitted(tx, "validatorSetUpdated");
    truffleAssert.eventEmitted(tx, "batchTransfer",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(21e17).toString();
    });
    truffleAssert.eventEmitted(tx, "directTransfer",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(1e16).toString();
    });
    truffleAssert.eventEmitted(tx, "directTransferFail",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(1e16).toString();
    });
    truffleAssert.eventEmitted(tx, "systemTransfer",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(1e18).add(web3.utils.toBN(1e5)).add(web3.utils.toBN(1e16)).toString();
    });
  });
});

contract('BSCValidatorSet', (accounts) => {
  it('complicate distribute when cross chain transfer failed', async () => {
    const validatorSetInstance = await BSCValidatorSet.deployed();
    const systemRewardInstance = await SystemReward.deployed();
    const tokenHub = await MockTokenHub.deployed();

    let validatorA = validatorSetInstance.address;
    let validatorB = web3.eth.accounts.create().address;
    let validatorC = web3.eth.accounts.create().address;
    let validatorD = web3.eth.accounts.create().address;
    let validatorE = web3.eth.accounts.create().address;
    let deprecated = web3.eth.accounts.create().address;
    let relayerAccount = accounts[8];
    let systemAccount = accounts[0];
    await  tokenHub.setPanicBatchTransferOut(true);

    // enough reward in system reward pool
    await systemRewardInstance.send(web3.utils.toBN(1e18), {from: accounts[1]});

    await validatorSetInstance.getValidators.call();
    let arr = [validatorA,validatorB,validatorC,validatorD,validatorE];

    let packageBytes = validatorUpdateRlpEncode(arr, arr,arr);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID, packageBytes, {from: relayerAccount});

    // deposit A: 1e16 B:1e16 C:1e17, D: 1e18, E:1e19, deprecated: 1e18
    await validatorSetInstance.deposit(validatorA, {from: systemAccount, value: web3.utils.toBN(1e16) });
    await validatorSetInstance.deposit(validatorB, {from: systemAccount, value: web3.utils.toBN(1e16) });
    await validatorSetInstance.deposit(validatorC, {from: systemAccount, value: web3.utils.toBN(1e17) });
    await validatorSetInstance.deposit(validatorD, {from: systemAccount, value: web3.utils.toBN(1e18) });
    await validatorSetInstance.deposit(validatorE, {from: systemAccount, value: web3.utils.toBN(1e18) });
    await validatorSetInstance.deposit(deprecated, {from: systemAccount, value: web3.utils.toBN(1e18) });

    //add some dust incoming
    await validatorSetInstance.deposit(validatorE, {from: systemAccount, value: web3.utils.toBN(1e5) });

    packageBytes = validatorUpdateRlpEncode(arr, arr,arr);
    let tx = await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    let validatorABalance = await web3.eth.getBalance(validatorA);
    let validatorBBalance = await web3.eth.getBalance(validatorB);
    let validatorCBalance = await web3.eth.getBalance(validatorC);
    let validatorDBalance = await web3.eth.getBalance(validatorD);
    let validatorEBalance = await web3.eth.getBalance(validatorE);
    let deprecatedBalance = await web3.eth.getBalance(deprecated);

    assert.equal(validatorABalance, 0);
    assert.equal(validatorBBalance, web3.utils.toBN(1e16));
    assert.equal(validatorCBalance, web3.utils.toBN(1e17));
    assert.equal(validatorDBalance, web3.utils.toBN(1e18));
    assert.equal(validatorEBalance, web3.utils.toBN(1e18).add(web3.utils.toBN(1e5)));
    assert.equal(deprecatedBalance, 0);

    truffleAssert.eventEmitted(tx, "validatorSetUpdated");
    truffleAssert.eventEmitted(tx, "batchTransferFailed",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(21e17).toString();
    });
    truffleAssert.eventEmitted(tx, "directTransfer",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(1e16).toString();
    });
    truffleAssert.eventEmitted(tx, "directTransferFail",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(1e16).toString();
    });
    truffleAssert.eventEmitted(tx, "systemTransfer",(ev) => {
      return ev.amount.toString() === web3.utils.toBN(1e18).add(web3.utils.toBN(1e16)).toString();
    });
  });
});

contract('BSCValidatorSet', (accounts) => {
  it('validator jail', async () => {
    const validatorSetInstance = await BSCValidatorSet.deployed();

    let newValidator1 = web3.eth.accounts.create();
    let newValidator2 = web3.eth.accounts.create();
    let newValidator3 = web3.eth.accounts.create();
    let relayerAccount = accounts[8];

    // do update
    let packageBytes = validatorUpdateRlpEncode([newValidator1.address, newValidator2.address, newValidator3.address],
        [newValidator1.address, newValidator2.address, newValidator3.address], [newValidator1.address, newValidator2.address, newValidator3.address]);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    let consensusAddres = await validatorSetInstance.getValidators.call();
    assert.equal(consensusAddres.length, 3);
    assert.equal(consensusAddres[0], newValidator1.address);
    assert.equal(consensusAddres[1], newValidator2.address);
    assert.equal(consensusAddres[2], newValidator3.address);

    packageBytes = jailRlpEncode([newValidator1.address, newValidator2.address, newValidator3.address],
        [newValidator1.address, newValidator2.address, newValidator3.address], [newValidator1.address, newValidator2.address, newValidator3.address]);
    let tx = await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    truffleAssert.eventEmitted(tx, "failReasonWithStr",(ev) => {
      return ev.message === "length of jail validators must be one";
    });

    packageBytes = jailRlpEncode([newValidator1.address], [newValidator1.address], [newValidator1.address]);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    consensusAddres = await validatorSetInstance.getValidators.call();
    assert.equal(consensusAddres.length, 2);
    assert.equal(consensusAddres[0], newValidator2.address);
    assert.equal(consensusAddres[1], newValidator3.address);

    // ok to re jail
    packageBytes = jailRlpEncode([newValidator1.address], [newValidator1.address], [newValidator1.address]);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    packageBytes = jailRlpEncode([newValidator2.address], [newValidator2.address], [newValidator2.address]);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    consensusAddres = await validatorSetInstance.getValidators.call();
    assert.equal(consensusAddres.length, 1);
    assert.equal(consensusAddres[0], newValidator3.address);

    // can not jail if it is the last one validator
    packageBytes = jailRlpEncode([newValidator3.address], [newValidator3.address], [newValidator3.address]);
    await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID,packageBytes,{from: relayerAccount});

    consensusAddres = await validatorSetInstance.getValidators.call();
    assert.equal(consensusAddres.length, 1);
    assert.equal(consensusAddres[0], newValidator3.address);

  });
});

contract('BSCValidatorSet', (accounts) => {
  it('test distribute algorithm with more than 41 validators', async () => {
    const validatorSetInstance = await BSCValidatorSet.deployed();
    let relayerAccount = accounts[8];

    let newValidators = [];
    for (let i = 0; i < 42; i++) {
      newValidators.push(web3.eth.accounts.create().address)
    }
    let packageBytes = validatorUpdateRlpEncode(newValidators,
        newValidators, newValidators);
    let tx = await validatorSetInstance.handleSynPackage(STAKE_CHANNEL_ID, packageBytes, {from: relayerAccount});
    
    truffleAssert.eventEmitted(tx, "failReasonWithStr", (ev) => {
      return ev.message === "the number of validators exceed the limit";
    });
  });
});


function jailRlpEncode(consensusAddrList,feeAddrList, bscFeeAddrList) {
  let pkg = [];
  pkg.push(0x01);
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