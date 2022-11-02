import {BigNumber, Contract} from 'ethers';
// @ts-ignore
import {ethers} from 'hardhat';
import {
  deployContract,
  waitTx,
  setSlashIndicator,
  validatorUpdateRlpEncode,
  buildSyncPackagePrefix,
  serializeGovPack,
  mineBlocks,
  buildTransferInPackage,
  toRpcQuantity, latest, increaseTime
} from './helper';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import web3 from 'web3';
import {
  BSCValidatorSet,
  SlashIndicator,
  CrossChain,
  GovHub,
  RelayerHub,
  RelayerIncentivize,
  SystemReward,
  TendermintLightClient,
  Staking, TokenHub,
} from '../../typechain-types';
import {expect} from "chai";


const log = console.log;
const TRANSFER_IN_CHANNELID = 0x02;
const STAKE_CHANNEL_ID = 0x08;
const GOV_CHANNEL_ID = 0x09;
const proof = Buffer.from(web3.utils.hexToBytes('0x00'));
const merkleHeight = 100;
const BNBTokenAddress = ethers.constants.AddressZero

const deployContractAndInit = async (
  deployer: SignerWithAddress,
  factoryPath: string,
  needInit?: boolean
): Promise<Contract> => {
  const instance = await deployContract(deployer, factoryPath);
  if (needInit) {
    await (await instance.init()).wait(1);
  }
  return instance;
};

describe('BEP-171 TEST', () => {
  const unit = ethers.constants.WeiPerEther;
  let instances: any[];

  let tokenHub: TokenHub;
  let relayerIncentivize: RelayerIncentivize;
  let tendermintLightClient: TendermintLightClient;
  let validatorSet: BSCValidatorSet;
  let systemReward: SystemReward;
  let slashIndicator: SlashIndicator;
  let crosschain: CrossChain;
  let relayerHub: RelayerHub;
  let govHub: GovHub;
  let staking: Staking;

  let operator: SignerWithAddress;
  let validators: string[];
  let relayerAccount: string;
  let signers: SignerWithAddress[];

  before('before', async () => {
    signers = await ethers.getSigners();
    log(signers.length);
    operator = signers[0];
    relayerAccount = signers[1].address;
    validators = signers.slice(0, 100).map((signer) => signer.address);

    const contractPaths = [
      {
        name: 'RelayerIncentivize', // 0
        needInit: true,
        needUpdate: true,
      },
      {
        name: 'TendermintLightClient', // 1
        needInit: true,
        needUpdate: true,
      },
      {
        name: 'CrossChain', // 2
        needInit: false,
        needUpdate: true,
      },
      {
        name: 'SystemReward', // 3
        needInit: false,
        needUpdate: false,
      },
      {
        name: 'MockLightClient', // 4
        needInit: false,
        needUpdate: false,
      },
      {
        name: 'TokenHub', // 5
        needInit: true,
        needUpdate: true,
      },
      {
        name: 'TokenManager', // 6
        needInit: false,
        needUpdate: true,
      },
      {
        name: 'RelayerHub', // 7
        needInit: true,
        needUpdate: true,
      },
      {
        name: 'SlashIndicator', // 8
        needInit: true,
        needUpdate: true,
      },
      {
        name: 'GovHub', // 9
        needInit: false,
        needUpdate: true,
      },
      {
        name: 'BSCValidatorSet', // 10
        needInit: true,
        needUpdate: true,
      },
      {
        name: 'Staking', // 11
        needInit: false,
        needUpdate: true,
      },
    ];
    instances = [];
    for (let i = 0; i < contractPaths.length; i++) {
      const pathObj = contractPaths[i];
      instances.push(await deployContractAndInit(operator, pathObj.name, pathObj.needInit));
    }

    for (let i = 0; i < contractPaths.length; i++) {
      const pathObj = contractPaths[i];
      const instance = instances[i];

      if (!pathObj.needUpdate) {
        continue;
      }

      let crosschainAddress = instances[2].address;
      if (pathObj.name === 'BSCValidatorSet' || pathObj.name === 'GovHub') {
        crosschainAddress = operator.address;
      }

      await waitTx(
        instance.updateContractAddr(
          instances[10].address,
          instances[8].address,
          instances[3].address,
          instances[4].address,
          instances[5].address,
          instances[0].address,
          instances[7].address,
          instances[9].address,
          instances[6].address,
          crosschainAddress,
          instances[11].address,
        )
      );
    }

    tokenHub = instances[5] as TokenHub

    relayerIncentivize = instances[0];
    tendermintLightClient = instances[1];
    systemReward = instances[3] as SystemReward;
    slashIndicator = instances[8] as SlashIndicator;
    await waitTx(systemReward.addOperator(operator.address));
    await waitTx(systemReward.addOperator(tendermintLightClient.address));
    await waitTx(systemReward.addOperator(relayerIncentivize.address));

    validatorSet = instances[10] as BSCValidatorSet;
    relayerHub = instances[7] as RelayerHub;

    crosschain = instances[2] as CrossChain;
    await waitTx(crosschain.init());

    govHub = instances[9] as GovHub;

    staking = instances[11] as Staking;
  });

  beforeEach('beforeEach', async () => {
  });

  it('query code size', async () => {
    let code = await ethers.provider.getCode(crosschain.address)
    let codeSize = (code.length - 2) / 2
    log(`CrossChain Template code size: ${codeSize}, UpperLimit: 24567`)

    code = await ethers.provider.getCode(tokenHub.address)
    codeSize = (code.length - 2) / 2
    log(`TokenHub Template code size: ${codeSize}, UpperLimit: 24567`)
  });

  it('update validators', async () => {
    // do update validators
    let packageBytes = validatorUpdateRlpEncode(
      validators.slice(1, 22),
      validators.slice(1, 22),
      validators.slice(1, 22)
    );

    await waitTx(validatorSet.connect(operator).handleSynPackage(STAKE_CHANNEL_ID, packageBytes));
  });

  it('query all view func', async () => {
    expect(await validatorSet.getValidators()).to.deep.eq(validators.slice(1, 22));
    for (let i = 1; i < 50; i++) {
      const currentValidatorSetIndex = i - 1
      if (i >= 1 && i < 22) {
        expect(await validatorSet.isWorkingValidator(currentValidatorSetIndex)).to.deep.eq(true);
        expect(await validatorSet.isCurrentValidator(validators[i])).to.deep.eq(true);
        expect(await validatorSet.canEnterMaintenance(validators[i])).to.deep.eq(false);
      } else {
        expect(await validatorSet.isWorkingValidator(currentValidatorSetIndex)).to.be.eq(false);
        expect(await validatorSet.isCurrentValidator(validators[i])).to.deep.eq(false);
        expect(await validatorSet.canEnterMaintenance(validators[i])).to.deep.eq(false);
      }
      expect(await validatorSet.getIncoming(validators[i])).to.deep.eq(0);
    }

    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(0);

  });

  it('update gov params using cross-chain', async () => {
    await waitTx(relayerHub.connect(operator).register({value: unit.mul(100)}));
    await waitTx(
      govHub.updateContractAddr(
        instances[10].address,
        instances[8].address,
        instances[3].address,
        instances[4].address,
        instances[5].address,
        instances[0].address,
        instances[7].address,
        instances[9].address,
        instances[6].address,
        instances[2].address,
        instances[11].address,
      )
    );

    //  set maxNumOfMaintaining to 5
    let govChannelSeq = await crosschain.channelReceiveSequenceMap(GOV_CHANNEL_ID);
    let govValue = '0x0000000000000000000000000000000000000000000000000000000000000005'; // 5;
    let govPackageBytes = serializeGovPack('maxNumOfMaintaining', govValue, validatorSet.address);
    await crosschain
      .connect(operator)
      .handlePackage(
        Buffer.concat([buildSyncPackagePrefix(2e16), govPackageBytes]),
        proof,
        merkleHeight,
        govChannelSeq,
        GOV_CHANNEL_ID
      );
    expect(await validatorSet.maxNumOfMaintaining()).to.be.eq(BigNumber.from(govValue));

    //  set maintainSlashScale to 2
    govChannelSeq = await crosschain.channelReceiveSequenceMap(GOV_CHANNEL_ID);
    govValue = '0x0000000000000000000000000000000000000000000000000000000000000002'; // 2;
    govPackageBytes = serializeGovPack('maintainSlashScale', govValue, validatorSet.address);
    await crosschain
      .connect(operator)
      .handlePackage(
        Buffer.concat([buildSyncPackagePrefix(2e16), govPackageBytes]),
        proof,
        merkleHeight,
        govChannelSeq,
        GOV_CHANNEL_ID
      );
  });

  it('suspend fail, not cabinet', async () => {
    expect(crosschain.connect(signers[22]).suspend()).to.be.revertedWith("not cabinet");
  })

  it('suspend success, all cross-chain channels closed', async () => {
    await waitTx(crosschain.connect(signers[1]).suspend());
    expect(await crosschain.isSuspended()).to.be.eq(true);

    let govChannelSeq = await crosschain.channelReceiveSequenceMap(GOV_CHANNEL_ID);
    let govValue = '0x0000000000000000000000000000000000000000000000000000000000000005'; // 5;
    let govPackageBytes = serializeGovPack('maxNumOfMaintaining', govValue, validatorSet.address);


    expect(crosschain.connect(operator).handlePackage(
      Buffer.concat([buildSyncPackagePrefix(2e16), govPackageBytes]),
      proof,
      merkleHeight,
      govChannelSeq,
      GOV_CHANNEL_ID
      // @ts-ignore
    )).to.be.revertedWith("suspended")
    expect(crosschain.connect(operator).handlePackage(
      Buffer.concat([buildSyncPackagePrefix(2e16), govPackageBytes]),
      proof,
      merkleHeight,
      await crosschain.channelReceiveSequenceMap(STAKE_CHANNEL_ID),
      STAKE_CHANNEL_ID
      // @ts-ignore
    )).to.be.revertedWith("suspended")
  });

  it('suspend fail, already suspended', async () => {
    expect(await crosschain.isSuspended()).to.be.eq(true);
    expect(crosschain.connect(signers[1]).suspend()).to.be.revertedWith("suspended")
  });

  it('reopen success, cross-chain works', async () => {
    await waitTx(crosschain.connect(signers[2]).reopen());
    expect(await crosschain.isSuspended()).to.be.eq(true);

    expect(crosschain.connect(signers[2]).reopen()).to.be.revertedWith("already approved");
    expect(await crosschain.isSuspended()).to.be.eq(true);

    await waitTx(crosschain.connect(signers[3]).reopen());
    expect(await crosschain.isSuspended()).to.be.eq(false);

    let govChannelSeq = await crosschain.channelReceiveSequenceMap(GOV_CHANNEL_ID);
    let govValue = '0x0000000000000000000000000000000000000000000000000000000000000007'; // 7;
    let govPackageBytes = serializeGovPack('maxNumOfMaintaining', govValue, validatorSet.address);
    await waitTx(crosschain.connect(operator).handlePackage(
      Buffer.concat([buildSyncPackagePrefix(2e16), govPackageBytes]),
      proof,
      merkleHeight,
      govChannelSeq,
      GOV_CHANNEL_ID
    ))
    expect(await validatorSet.maxNumOfMaintaining()).to.be.eq(BigNumber.from(govValue));
  });

  it('maintaining cabinet suspends success, all cross-chain channels closed', async () => {
    await waitTx(validatorSet.connect(signers[5]).enterMaintenance());
    const maintainingValidators = await validatorSet.getMaintainingValidators()
    expect(maintainingValidators).to.deep.eq([validators[5]]);

    await waitTx(crosschain.connect(signers[5]).suspend());
    expect(await crosschain.isSuspended()).to.be.eq(true);

    let govChannelSeq = await crosschain.channelReceiveSequenceMap(GOV_CHANNEL_ID);
    let govValue = '0x0000000000000000000000000000000000000000000000000000000000000005'; // 5;
    let govPackageBytes = serializeGovPack('maxNumOfMaintaining', govValue, validatorSet.address);

    expect(crosschain.connect(operator).handlePackage(
      Buffer.concat([buildSyncPackagePrefix(2e16), govPackageBytes]),
      proof,
      merkleHeight,
      govChannelSeq,
      GOV_CHANNEL_ID
      // @ts-ignore
    )).to.be.revertedWith("suspended")
    expect(crosschain.connect(operator).handlePackage(
      Buffer.concat([buildSyncPackagePrefix(2e16), govPackageBytes]),
      proof,
      merkleHeight,
      await crosschain.channelReceiveSequenceMap(STAKE_CHANNEL_ID),
      STAKE_CHANNEL_ID
      // @ts-ignore
    )).to.be.revertedWith("suspended")
  });

  it('cross-chain transfer fail, suspended', async () => {
    let transferInChannelSeq = await crosschain.channelReceiveSequenceMap(TRANSFER_IN_CHANNELID);

    const transferInPackage = buildTransferInPackage(
      "BNB",
      BNBTokenAddress,
      11e18, // 11 BNB
      validators[15],
      validators[15]
    );

    expect(crosschain
      .connect(operator)
      .handlePackage(
        transferInPackage,
        proof,
        merkleHeight,
        transferInChannelSeq,
        TRANSFER_IN_CHANNELID
      )).to.be.revertedWith('suspended');

  });

  it('reopen success, cross-chain works', async () => {
    await waitTx(crosschain.connect(signers[5]).reopen());
    expect(await crosschain.isSuspended()).to.be.eq(true);

    await waitTx(crosschain.connect(signers[21]).reopen());
    expect(await crosschain.isSuspended()).to.be.eq(false);
  });

  it('cross-chain transfer success', async () => {
    // set bnb to tokenHub contract
    await ethers.provider.send(
      "hardhat_setBalance",
      [tokenHub.address, toRpcQuantity(unit.mul(9999).toHexString())],
    );

    const transferInBalance: number = 123e18
    let transferInChannelSeq = await crosschain.channelReceiveSequenceMap(TRANSFER_IN_CHANNELID);
    const transferInPackage = buildTransferInPackage(
      "BNB",
      BNBTokenAddress,
      transferInBalance, // 123 BNB
      validators[15],
      validators[15]
    );

    const balanceBefore = await ethers.provider.getBalance(validators[15])

    await waitTx(crosschain
      .connect(operator)
      .handlePackage(
        transferInPackage,
        proof,
        merkleHeight,
        transferInChannelSeq,
        TRANSFER_IN_CHANNELID))

    const balance = await ethers.provider.getBalance(validators[15])
    expect(balance.sub(balanceBefore)).to.be.eq(BigNumber.from(transferInBalance.toString()));
  });

  it('cross-chain large transfer, withdraw failed since still on locking', async () => {
    // set bnb to tokenHub contract
    await ethers.provider.send(
      "hardhat_setBalance",
      [tokenHub.address, toRpcQuantity(unit.mul(100_0000).toHexString())],
    );

    const transferInBalance: number = 10000e18 // 10000 BNB
    const transferInBalanceBig: BigNumber = BigNumber.from("0x" + transferInBalance.toString(16))
    const receiver = validators[50]


    let transferInChannelSeq = await crosschain.channelReceiveSequenceMap(TRANSFER_IN_CHANNELID);
    const transferInPackage = buildTransferInPackage(
      "BNB",
      BNBTokenAddress,
      transferInBalance,
      receiver,
      receiver,
    );

    const balanceBefore = await ethers.provider.getBalance(receiver)

    // cross-chain transferIn
    await waitTx(crosschain
      .connect(operator)
      .handlePackage(
        transferInPackage,
        proof,
        merkleHeight,
        transferInChannelSeq,
        TRANSFER_IN_CHANNELID))

    let lockInfo = await tokenHub.lockInfoMap(BNBTokenAddress, receiver)
    expect(lockInfo.amount).to.be.eq(transferInBalanceBig)


    let balance = await ethers.provider.getBalance(receiver)
    let addedBalance = balance.sub(balanceBefore)
    // large transfer locked on TokenHub for 6 hours
    expect(addedBalance).to.be.eq(BigNumber.from(0));

    let addedSeconds = 2 * 60 * 60// 2 hours
    await increaseTime(addedSeconds)
    expect(
      tokenHub.connect(operator).withdrawUnlockedToken(BNBTokenAddress, receiver)
    ).to.be.revertedWith('still on locking period')
  });

  it('cross-chain large transfer on second time', async () => {
    const transferInBalance: number = 20000e18 // 20000 BNB
    const receiver = validators[50]

    let transferInChannelSeq = await crosschain.channelReceiveSequenceMap(TRANSFER_IN_CHANNELID);
    const transferInPackage = buildTransferInPackage(
      "BNB",
      BNBTokenAddress,
      transferInBalance,
      receiver,
      receiver,
    );

    const balanceBefore = await ethers.provider.getBalance(receiver)

    let lockInfo = await tokenHub.lockInfoMap(BNBTokenAddress, receiver)
    // cross-chain transferIn
    // new locked will reset the unlockAt to currentTime + 6 hours
    await waitTx(crosschain
      .connect(operator)
      .handlePackage(
        transferInPackage,
        proof,
        merkleHeight,
        transferInChannelSeq,
        TRANSFER_IN_CHANNELID
      ))

    lockInfo = await tokenHub.lockInfoMap(BNBTokenAddress, receiver)

    const expectedLockedAmount = unit.mul(10000 + 20000)  // 1-locked 10000 BNB,  2-locked 20000 BNB
    expect(lockInfo.amount).to.be.eq(expectedLockedAmount)
    expect(lockInfo.unlockAt).to.be.eq(await latest() + 6 * 60 * 60)

    let addedSeconds = 6 * 60 * 60// 6 hours
    await increaseTime(addedSeconds)
    // anyone could withdraw the unlocked token to the receiver
    await waitTx(tokenHub.connect(signers[60]).withdrawUnlockedToken(BNBTokenAddress, receiver))

    let balance = await ethers.provider.getBalance(receiver)
    let addedBalance = balance.sub(balanceBefore)
    expect(addedBalance).to.be.eq(expectedLockedAmount)
  });

});
