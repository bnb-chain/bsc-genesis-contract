import { ethers } from 'hardhat';
import { Signer } from '@ethersproject/abstract-signer';
import { Contract, ContractReceipt, ContractTransaction } from '@ethersproject/contracts';
import { BSCValidatorSet } from '../../typechain-types';

const RLP = require('rlp');
import web3 from 'web3';

export async function deployContract(
  signer: Signer,
  factoryPath: string,
  ...args: Array<any>
): Promise<Contract> {
  const factory = await ethers.getContractFactory(factoryPath);
  const contract = await factory.connect(signer).deploy(...args);
  await contract.deployTransaction.wait(1);
  return contract;
}

export async function waitTx(txRequest: Promise<ContractTransaction>): Promise<ContractReceipt> {
  const txResponse = await txRequest;
  return await txResponse.wait(1);
}

export const setSlashIndicator = async (
  slashAddress: string,
  validatorSet: BSCValidatorSet,
  instances: any[]
) => {
  await waitTx(
    validatorSet.updateContractAddr(
      instances[10].address,
      slashAddress,
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
};

export function validatorUpdateRlpEncode(
  consensusAddrList: any,
  feeAddrList: any,
  bscFeeAddrList: any
) {
  let pkg = [];
  pkg.push(0x00);
  let n = consensusAddrList.length;
  let vals = [];
  for (let i = 0; i < n; i++) {
    vals.push([
      consensusAddrList[i].toString(),
      feeAddrList[i].toString(),
      bscFeeAddrList[i].toString(),
      0x0000000000000064,
    ]);
  }
  pkg.push(vals);
  return RLP.encode(pkg);
}

export function buildSyncPackagePrefix(syncRelayFee: any) {
  return Buffer.from(web3.utils.hexToBytes('0x00' + toBytes32String(syncRelayFee)));
}

export function toBytes32String(input: any) {
  let initialInputHexStr = web3.utils.toBN(input).toString(16);
  const initialInputHexStrLength = initialInputHexStr.length;

  let inputHexStr = initialInputHexStr;
  for (let i = 0; i < 64 - initialInputHexStrLength; i++) {
    inputHexStr = '0' + inputHexStr;
  }
  return inputHexStr;
}

export function serializeGovPack(key: string, value: string, target: string, extra?: string) {
  let pkg = [];
  pkg.push(key);
  pkg.push(value);
  pkg.push(target);
  if (extra) {
    pkg.push(extra);
  }
  return RLP.encode(pkg);
}

export async function mineBlocks(addedBlocksCount: number) {
  for (let i = 0; i < addedBlocksCount; i++) {
    await ethers.provider.send('evm_mine', []);
  }
}
