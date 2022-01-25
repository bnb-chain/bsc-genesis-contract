import { BigNumber, Contract } from 'ethers';
import { ethers } from 'hardhat';
import { expect } from 'chai';
import {
  deployContract,
  waitTx,
  setSlashIndicator,
  validatorUpdateRlpEncode,
  buildSyncPackagePrefix,
  serializeGovPack,
  mineBlocks,
} from './helper';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
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
} from '../../typechain-types';

const log = console.log;
const STAKE_CHANNEL_ID = 0x08;
const GOV_CHANNEL_ID = 0x09;
const proof = Buffer.from(web3.utils.hexToBytes('0x00'));
const merkleHeight = 100;

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

describe('BSCValidatorSet', () => {
  const unit = ethers.constants.WeiPerEther;
  let instances: any[];

  let relayerIncentivize: RelayerIncentivize;
  let tendermintLightClient: TendermintLightClient;
  let validatorSet: BSCValidatorSet;
  let systemReward: SystemReward;
  let slashIndicator: SlashIndicator;
  let crosschain: CrossChain;
  let relayerHub: RelayerHub;
  let govHub: GovHub;

  let operator: SignerWithAddress;
  let validators: string[];
  let relayerAccount: string;
  let signers: SignerWithAddress[];

  let maxNumOfMaintaining: number;
  let maintainSlashScale: number;
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
          crosschainAddress
        )
      );
    }

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
  });

  beforeEach('beforeEach', async () => {});

  it('query basic info', async () => {
    // do update validators
    let packageBytes = validatorUpdateRlpEncode(
      validators.slice(1, 22),
      validators.slice(1, 22),
      validators.slice(1, 22)
    );

    log('current validators', validators.slice(1, 22));

    await waitTx(validatorSet.connect(operator).handleSynPackage(STAKE_CHANNEL_ID, packageBytes));

    expect(await validatorSet.getValidators()).to.deep.eq(validators.slice(1, 22));
  });

  it('common case 1-0', async () => {
    expect(validatorSet.connect(signers[1]).enterMaintenance()).to.be.revertedWith(
      'can not enter Temporary Maintenance'
    );
  });

  it('common case 1-1 update params', async () => {
    await waitTx(relayerHub.connect(operator).register({ value: unit.mul(100) }));
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
        instances[2].address
      )
    );

    //  set maxNumOfMaintaining to 5
    let govChannelSeq = await crosschain.channelReceiveSequenceMap(GOV_CHANNEL_ID);
    maxNumOfMaintaining = 5;
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
    maintainSlashScale = 2;
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
    expect(await validatorSet.maintainSlashScale()).to.be.eq(BigNumber.from(govValue));
  });

  it('common case 1-2: validator-1 enterMaintenance', async () => {
    await waitTx(validatorSet.connect(signers[1]).enterMaintenance());
    const validatorInfo = await validatorSet.maintainingValidatorSet(0);
    expect(validatorInfo.consensusAddress).to.be.eq(validators[1]);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([validators[1]]);
  });

  it('common case 1-3: validator-2 enterMaintenance', async () => {
    await waitTx(validatorSet.connect(signers[2]).enterMaintenance());
    const validatorInfo = await validatorSet.maintainingValidatorSet(1);
    expect(validatorInfo.consensusAddress).to.be.eq(validators[2]);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[2],
    ]);
  });

  it('common case 1-4: validator-3 misdemeanor, enterMaintenance', async () => {
    await setSlashIndicator(operator.address, validatorSet, instances);

    await validatorSet.connect(operator).misdemeanor(validators[3]);
    const maintainInfo = await validatorSet.maintainInfoMap(validators[3]);
    expect(maintainInfo.isMaintaining).to.be.eq(true);
    expect(maintainInfo.index).to.be.eq(BigNumber.from(3));
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[2],
      validators[3],
    ]);
  });

  it('common case 1-5: validator-2 exitMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[2]).exitMaintenance());
    const maintainInfo = await validatorSet.maintainInfoMap(validators[2]);

    expect(maintainInfo.isMaintaining).to.be.eq(false);
    expect(maintainInfo.index).to.be.eq(BigNumber.from(0));
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[3],
    ]);
  });

  it('common case 1-6: validator-4 misdemeanor, enterMaintenance', async () => {
    await setSlashIndicator(operator.address, validatorSet, instances);

    await validatorSet.connect(operator).misdemeanor(validators[4]);
    const maintainInfo = await validatorSet.maintainInfoMap(validators[4]);
    expect(maintainInfo.isMaintaining).to.be.eq(true);
    expect(maintainInfo.index).to.be.eq(BigNumber.from(3));
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[3],
      validators[4],
    ]);
  });

  it('common case 1-7: validator-5 misdemeanor, enterMaintenance', async () => {
    await validatorSet.connect(operator).misdemeanor(validators[5]);
    const maintainInfo = await validatorSet.maintainInfoMap(validators[5]);
    expect(maintainInfo.isMaintaining).to.be.eq(true);
    expect(maintainInfo.index).to.be.eq(BigNumber.from(4));
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[3],
      validators[4],
      validators[5],
    ]);
  });

  it('common case 1-8: validator-6 enterMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[6]).enterMaintenance());
    const validatorInfo = await validatorSet.maintainingValidatorSet(4);
    expect(validatorInfo.consensusAddress).to.be.eq(validators[6]);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[3],
      validators[4],
      validators[5],
      validators[6],
    ]);
  });

  it('common case 1-9: validator-7 enterMaintenance failed!', async () => {
    expect(validatorSet.connect(signers[7]).enterMaintenance()).to.be.revertedWith(
      'can not enter Temporary Maintenance'
    );
  });

  it('common case 1-10: validator-7 misdemeanor, enterMaintenance failed!', async () => {
    await setSlashIndicator(operator.address, validatorSet, instances);

    await validatorSet.connect(operator).misdemeanor(validators[7]);
    const maintainInfo = await validatorSet.maintainInfoMap(validators[7]);
    expect(maintainInfo.isMaintaining).to.be.eq(false);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[3],
      validators[4],
      validators[5],
      validators[6],
    ]);
  });

  it('common case 1-11: validator-1 exitMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[1]).exitMaintenance());
    const maintainInfo = await validatorSet.maintainInfoMap(validators[1]);

    expect(maintainInfo.isMaintaining).to.be.eq(false);
    expect(maintainInfo.index).to.be.eq(BigNumber.from(0));
    expect(maintainInfo.startBlockNumber.toNumber() > 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[6],
      validators[3],
      validators[4],
      validators[5],
    ]);
  });

  it('common case 1-12: validator-1 misdemeanor, enterMaintenance failed!', async () => {
    await setSlashIndicator(operator.address, validatorSet, instances);

    await validatorSet.connect(operator).misdemeanor(validators[1]);
    const maintainInfo = await validatorSet.maintainInfoMap(validators[1]);
    expect(maintainInfo.isMaintaining).to.be.eq(false);
    expect(maintainInfo.index).to.be.eq(BigNumber.from(0));
    expect(maintainInfo.startBlockNumber.toNumber() > 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[6],
      validators[3],
      validators[4],
      validators[5],
    ]);
  });

  it('common case 1-13: validator-8 enterMaintenance', async () => {
    await mineBlocks(21 * 100 * maintainSlashScale);

    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[8]).enterMaintenance());

    const maintainInfo = await validatorSet.maintainInfoMap(validators[8]);
    expect(maintainInfo.isMaintaining).to.be.eq(true);
    expect(maintainInfo.startBlockNumber.toNumber() > 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[6],
      validators[3],
      validators[4],
      validators[5],
      validators[8],
    ]);
  });

  it('common case 1-14: validator-9 enterMaintenance failed!', async () => {
    expect(validatorSet.connect(signers[9]).enterMaintenance()).to.be.revertedWith(
      'can not enter Temporary Maintenance'
    );
  });

  it('common case 1-15: validator-1 felony', async () => {
    let index = await validatorSet.currentValidatorSetMap(validators[1]);
    expect(index.toNumber() > 0).to.be.eq(true);

    await setSlashIndicator(operator.address, validatorSet, instances);
    await validatorSet.connect(operator).felony(validators[1]);

    index = await validatorSet.currentValidatorSetMap(validators[1]);
    expect(index.toNumber() === 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[6],
      validators[3],
      validators[4],
      validators[5],
      validators[8],
    ]);
  });

  it('common case 1-16: validator-2 enterMaintenance failed!', async () => {
    expect(validatorSet.connect(signers[2]).enterMaintenance()).to.be.revertedWith(
      'can not enter Temporary Maintenance'
    );
  });

  it('common case 1-17: validator-4 exitMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[4]).exitMaintenance());
    const maintainInfo = await validatorSet.maintainInfoMap(validators[4]);

    expect(maintainInfo.isMaintaining).to.be.eq(false);
    expect(maintainInfo.index).to.be.eq(BigNumber.from(0));
    expect(maintainInfo.startBlockNumber.toNumber() > 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[6],
      validators[3],
      validators[8],
      validators[5],
    ]);
  });

  it('common case 1-18: validator-2 enterMaintenance failed!', async () => {
    expect(validatorSet.connect(signers[2]).enterMaintenance()).to.be.revertedWith(
      'can not enter Temporary Maintenance'
    );
  });

  it('common case 1-19: validator-2 misdemeanor, enterMaintenance failed!', async () => {
    await setSlashIndicator(operator.address, validatorSet, instances);
    await validatorSet.connect(operator).misdemeanor(validators[2]);
    const maintainInfo = await validatorSet.maintainInfoMap(validators[2]);
    expect(maintainInfo.isMaintaining).to.be.eq(false);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[6],
      validators[3],
      validators[8],
      validators[5],
    ]);
  });

  it('common case 1-20: validator-10 enterMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[10]).enterMaintenance());

    const maintainInfo = await validatorSet.maintainInfoMap(validators[10]);
    expect(maintainInfo.isMaintaining).to.be.eq(true);
    expect(maintainInfo.startBlockNumber.toNumber() > 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[6],
      validators[3],
      validators[8],
      validators[5],
      validators[10],
    ]);
  });

  it('common case 1-21: validator-3 exitMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[3]).exitMaintenance());
    const maintainInfo = await validatorSet.maintainInfoMap(validators[3]);

    expect(maintainInfo.isMaintaining).to.be.eq(false);
    expect(maintainInfo.index).to.be.eq(BigNumber.from(0));
    expect(maintainInfo.startBlockNumber.toNumber() > 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[6],
      validators[10],
      validators[8],
      validators[5],
    ]);
  });

  it('common case 1-22: validator-4 exitMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);
    expect(validatorSet.connect(signers[4]).exitMaintenance()).to.revertedWith(
      'not in maintenance'
    );
  });

  it('common case 1-23: validator-4 enterMaintenance failed!', async () => {
    expect(validatorSet.connect(signers[4]).enterMaintenance()).to.be.revertedWith(
      'can not enter Temporary Maintenance'
    );
  });

  it('common case 1-24: 24 hours ended, clear all maintainInfo', async () => {
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[6],
      validators[10],
      validators[8],
      validators[5],
    ]);

    await waitTx(
      validatorSet.updateContractAddr(
        instances[10].address,
        instances[8].address,
        instances[3].address,
        instances[4].address,
        instances[5].address,
        instances[0].address,
        instances[7].address,
        instances[9].address,
        instances[6].address,
        operator.address
      )
    );

    await mineBlocks(21 * 50 * maintainSlashScale);

    // do update validators
    let packageBytes = validatorUpdateRlpEncode(
      validators.slice(2, 23),
      validators.slice(2, 23),
      validators.slice(2, 23)
    );
    await waitTx(validatorSet.connect(operator).handleSynPackage(STAKE_CHANNEL_ID, packageBytes));

    // validator-5,6 felony,  validator-8 misdemeanor
    const expectedValidators = validators
      .slice(2, 23)
      .filter((item) => item !== validators[5] && item !== validators[6]);
    expect(await validatorSet.getValidators()).to.deep.eq(expectedValidators);

    for (let i = 2; i < 23; i++) {
      const maintainInfo = await validatorSet.maintainInfoMap(validators[i]);
      expect(maintainInfo.isMaintaining).to.be.eq(false);
      expect(maintainInfo.index).to.be.eq(BigNumber.from(0));
      expect(maintainInfo.startBlockNumber.toNumber() === 0).to.be.eq(true);
    }
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([]);
    expect(validatorSet.maintainingValidatorSet(0)).to.be.reverted;
  });
});
