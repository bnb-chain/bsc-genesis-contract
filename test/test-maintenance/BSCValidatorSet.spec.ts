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

  it('query code size', async () => {
    const code = await ethers.provider.getCode(validatorSet.address)
    const codeSize = (code.length - 2) / 2
    log(`BSCValidatorSet Mock Template code size: ${codeSize}, UpperLimit: 24567` )
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
    expect(await validatorSet.numOfMaintaining()).to.be.eq(0);
  });

  it('common case 1-2: validator-1 enterMaintenance', async () => {
    await waitTx(validatorSet.connect(signers[1]).enterMaintenance());
    const maintainingValidators = await validatorSet.getMaintainingValidators()
    expect(maintainingValidators).to.deep.eq([validators[1]]);
  });

  it('common case 1-3: validator-2 enterMaintenance', async () => {
    await waitTx(validatorSet.connect(signers[2]).enterMaintenance());
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[2],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(2);
  });

  it('common case 1-4: validator-3 misdemeanor, enterMaintenance', async () => {
    await setSlashIndicator(operator.address, validatorSet, instances);

    await validatorSet.connect(operator).misdemeanor(validators[3]);

    const index = await validatorSet.getCurrentValidatorIndex(validators[3]);
    const validatorExtra = await validatorSet.validatorExtraSet(index); 
    
    expect(validatorExtra.isMaintaining).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[2],
      validators[3],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(3);
  });

  it('common case 1-5: validator-2 exitMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[2]).exitMaintenance());
    const index = await validatorSet.getCurrentValidatorIndex(validators[2]);
    const validatorExtra = await validatorSet.validatorExtraSet(index);

    expect(validatorExtra.isMaintaining).to.be.eq(false);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[3],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(2);
  });

  it('common case 1-6: validator-4 misdemeanor, enterMaintenance', async () => {
    await setSlashIndicator(operator.address, validatorSet, instances);

    await validatorSet.connect(operator).misdemeanor(validators[4]);
    const index = await validatorSet.getCurrentValidatorIndex(validators[4]);
    const validatorExtra = await validatorSet.validatorExtraSet(index);


    expect(validatorExtra.isMaintaining).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[3],
      validators[4],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(3);
  });

  it('common case 1-7: validator-5 misdemeanor, enterMaintenance', async () => {
    await validatorSet.connect(operator).misdemeanor(validators[5]);
    const index = await validatorSet.getCurrentValidatorIndex(validators[5]);
    const validatorExtra = await validatorSet.validatorExtraSet(index);

    expect(validatorExtra.isMaintaining).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[3],
      validators[4],
      validators[5],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(4);

  });

  it('common case 1-8: validator-6 enterMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[6]).enterMaintenance());
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[3],
      validators[4],
      validators[5],
      validators[6],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(5);

  });

  it('common case 1-9: validator-7 enterMaintenance failed!', async () => {
    expect(validatorSet.connect(signers[7]).enterMaintenance()).to.be.revertedWith(
      'can not enter Temporary Maintenance'
    );
    expect(await validatorSet.numOfMaintaining()).to.be.eq(5);
  });

  it('common case 1-10: validator-7 misdemeanor, enterMaintenance failed!', async () => {
    await setSlashIndicator(operator.address, validatorSet, instances);

    await validatorSet.connect(operator).misdemeanor(validators[7]);
    const index = await validatorSet.getCurrentValidatorIndex(validators[7]);
    const validatorExtra = await validatorSet.validatorExtraSet(index);

    expect(validatorExtra.isMaintaining).to.be.eq(false);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[1],
      validators[3],
      validators[4],
      validators[5],
      validators[6],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(5);
  });

  it('common case 1-11: validator-1 exitMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[1]).exitMaintenance());
    const index = await validatorSet.getCurrentValidatorIndex(validators[1]);
    const validatorExtra = await validatorSet.validatorExtraSet(index);

    expect(validatorExtra.isMaintaining).to.be.eq(false);
    expect(validatorExtra.enterMaintenanceHeight.toNumber() > 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[3],
      validators[4],
      validators[5],
      validators[6],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(4);
  });

  it('common case 1-12: validator-1 misdemeanor, enterMaintenance failed!', async () => {
    await setSlashIndicator(operator.address, validatorSet, instances);

    await validatorSet.connect(operator).misdemeanor(validators[1]);
    const index = await validatorSet.getCurrentValidatorIndex(validators[1]);
    const validatorExtra = await validatorSet.validatorExtraSet(index);

    expect(validatorExtra.isMaintaining).to.be.eq(false);
    expect(validatorExtra.enterMaintenanceHeight.toNumber() > 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[3],
      validators[4],
      validators[5],
      validators[6],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(4);
  });

  it('common case 1-13: validator-8 enterMaintenance', async () => {
    await mineBlocks(21 * 100 * maintainSlashScale);

    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[8]).enterMaintenance());

    const index = await validatorSet.getCurrentValidatorIndex(validators[8]);
    const validatorExtra = await validatorSet.validatorExtraSet(index);

    expect(validatorExtra.isMaintaining).to.be.eq(true);
    expect(validatorExtra.enterMaintenanceHeight.toNumber() > 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[3],
      validators[4],
      validators[5],
      validators[6],
      validators[8],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(5);
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
      validators[3],
      validators[4],
      validators[5],
      validators[6],
      validators[8],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(5);
  });

  it('common case 1-16: validator-2 enterMaintenance failed!', async () => {
    expect(validatorSet.connect(signers[2]).enterMaintenance()).to.be.revertedWith(
      'can not enter Temporary Maintenance'
    );
  });

  it('common case 1-17: validator-4 exitMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[4]).exitMaintenance());
    const index = await validatorSet.getCurrentValidatorIndex(validators[4]);
    const validatorExtra = await validatorSet.validatorExtraSet(index);

    expect(validatorExtra.isMaintaining).to.be.eq(false);
    expect(validatorExtra.enterMaintenanceHeight.toNumber() > 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[3],
      validators[5],
      validators[6],
      validators[8],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(4);
  });

  it('common case 1-18: validator-2 enterMaintenance failed!', async () => {
    expect(validatorSet.connect(signers[2]).enterMaintenance()).to.be.revertedWith(
      'can not enter Temporary Maintenance'
    );
  });

  it('common case 1-19: validator-2 misdemeanor, enterMaintenance failed!', async () => {
    await setSlashIndicator(operator.address, validatorSet, instances);
    await validatorSet.connect(operator).misdemeanor(validators[2]);
    const index = await validatorSet.getCurrentValidatorIndex(validators[2]);
    const validatorExtra = await validatorSet.validatorExtraSet(index);

    expect(validatorExtra.isMaintaining).to.be.eq(false);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[3],
      validators[5],
      validators[6],
      validators[8],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(4);
  });

  it('common case 1-20: validator-10 enterMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[10]).enterMaintenance());

    const index = await validatorSet.getCurrentValidatorIndex(validators[10]);
    const validatorExtra = await validatorSet.validatorExtraSet(index);

    expect(validatorExtra.isMaintaining).to.be.eq(true);
    expect(validatorExtra.enterMaintenanceHeight.toNumber() > 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[3],
      validators[5],
      validators[6],
      validators[8],
      validators[10],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(5);
  });

  it('common case 1-21: validator-3 exitMaintenance', async () => {
    await setSlashIndicator(slashIndicator.address, validatorSet, instances);

    await waitTx(validatorSet.connect(signers[3]).exitMaintenance());
    const index = await validatorSet.getCurrentValidatorIndex(validators[3]);
    const validatorExtra = await validatorSet.validatorExtraSet(index);

    expect(validatorExtra.isMaintaining).to.be.eq(false);
    expect(validatorExtra.enterMaintenanceHeight.toNumber() > 0).to.be.eq(true);
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([
      validators[5],
      validators[6],
      validators[8],
      validators[10],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(4);
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
      validators[5],
      validators[6],
      validators[8],
      validators[10],
    ]);
    expect(await validatorSet.numOfMaintaining()).to.be.eq(4);

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
    expect(await validatorSet.numOfMaintaining()).to.be.eq(0);

    for (let i = 2; i < 23; i++) {
      if (i === 5 || i === 6) {
        // because of felony, validator-5,6 are not the current validators
        expect(validatorSet.getCurrentValidatorIndex(validators[i])).to.be.revertedWith(
          'only current validators'
        );
        continue;
      }
      const index = await validatorSet.getCurrentValidatorIndex(validators[i]);
      const validatorExtra = await validatorSet.validatorExtraSet(index);

      expect(validatorExtra.isMaintaining).to.be.eq(false);
      expect(validatorExtra.enterMaintenanceHeight.toNumber() === 0).to.be.eq(true);
    }
    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([]);
  });


  it('common case 1-25: query all view func', async () => {
    expect(await validatorSet.maxNumOfMaintaining()).to.be.eq(maxNumOfMaintaining)
    expect(await validatorSet.maintainSlashScale()).to.be.eq(maintainSlashScale)
    expect(await validatorSet.numOfMaintaining()).to.be.eq(0);

    for (let i = 2; i < 50; i++) {
      if (i >= 2 && i < 23 && i !== 5 && i !== 6) {
        expect(await validatorSet.isCurrentValidator(validators[i])).to.deep.eq(true);
      } else {
        expect(await validatorSet.isCurrentValidator(validators[i])).to.deep.eq(false);
      }
      expect(await validatorSet.getIncoming(validators[i])).to.deep.eq(0);
    }

    expect(await validatorSet.getMaintainingValidators()).to.deep.eq([]);
  });


    it('common case 2-1 update params', async () => {
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
        maxNumOfMaintaining = 18;
        let govValue = '0x0000000000000000000000000000000000000000000000000000000000000012'; // 18
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
        maintainSlashScale = 1;
        govValue = '0x0000000000000000000000000000000000000000000000000000000000000001'; // 1
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
        expect(await validatorSet.numOfMaintaining()).to.be.eq(0);
    });


    it('common case 2-2: validator 7 ~ 10 enterMaintenance', async () => {
        await setSlashIndicator(slashIndicator.address, validatorSet, instances);

        for (let i = 7; i < 10; i++) {
            await waitTx(validatorSet.connect(signers[i]).enterMaintenance());
        }

        const expectedMaintainingValidators = []

        for (let i = 7; i < 10; i++) {
            const index = await validatorSet.getCurrentValidatorIndex(validators[i]);
            const validatorExtra = await validatorSet.validatorExtraSet(index);
            expect(validatorExtra.isMaintaining).to.be.eq(true);
            expect(validatorExtra.enterMaintenanceHeight.toNumber() > 0).to.be.eq(true);
            expectedMaintainingValidators.push(validators[i]);
        }


        expect(await validatorSet.getMaintainingValidators()).to.deep.eq(expectedMaintainingValidators);
        expect(await validatorSet.numOfMaintaining()).to.be.eq(3);

        const felonyThreshold = (await slashIndicator.felonyThreshold()).toNumber();
        await mineBlocks( 4 * felonyThreshold * maintainSlashScale / 2);
    });


    it('common case 2-3: validator 10 ~ 21 enterMaintenance', async () => {
        await setSlashIndicator(slashIndicator.address, validatorSet, instances);

        for (let i = 10; i < 22; i++) {
            await waitTx(validatorSet.connect(signers[i]).enterMaintenance());
        }

        const expectedMaintainingValidators = []
        for (let i = 7; i < 10; i++) {
            expectedMaintainingValidators.push(validators[i]);
        }

        for (let i = 10; i < 22; i++) {
            const index = await validatorSet.getCurrentValidatorIndex(validators[i]);
            const validatorExtra = await validatorSet.validatorExtraSet(index);
            expect(validatorExtra.isMaintaining).to.be.eq(true);
            expect(validatorExtra.enterMaintenanceHeight.toNumber() > 0).to.be.eq(true);
            expectedMaintainingValidators.push(validators[i]);
        }

        expect(await validatorSet.getMaintainingValidators()).to.deep.eq(expectedMaintainingValidators);
        expect(await validatorSet.numOfMaintaining()).to.be.eq(15);

        const felonyThreshold = (await slashIndicator.felonyThreshold()).toNumber();
        await mineBlocks( 4 * felonyThreshold * maintainSlashScale / 2 + 1);
    });

    it('common case 2-4: update validator set', async () => {
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

        // do update validators
        let packageBytes = validatorUpdateRlpEncode(
            validators.slice(5, 26),
            validators.slice(5, 26),
            validators.slice(5, 26),
        );
        await waitTx(validatorSet.connect(operator).handleSynPackage(STAKE_CHANNEL_ID, packageBytes));

        // validator 7 ~ 9 will be felony, their slashCount =  4 * felonyThreshold * maintainSlashScale / workingValidatorCount(4)
        const expectedValidators: string[] = [validators[5], validators[6]].concat(validators.slice(10, 26));

        expect(await validatorSet.getValidators()).to.deep.eq(expectedValidators);
        expect(await validatorSet.numOfMaintaining()).to.be.eq(0);
    });

});
