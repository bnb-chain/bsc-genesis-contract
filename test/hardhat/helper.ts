import { ethers } from 'hardhat';
import { Signer } from '@ethersproject/abstract-signer';
import { Contract, ContractReceipt, ContractTransaction } from '@ethersproject/contracts';
import { BSCValidatorSet } from '../../typechain-types';

const RLP = require('rlp');
import web3 from 'web3';
import {isHexPrefixed} from "hardhat/internal/hardhat-network/provider/utils/isHexPrefixed";
import {BigNumber} from "ethers";

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
      instances[2].address,
      instances[11].address,
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

function stringToBytes32(symbol: string) {
  let initialSymbolHexStr = '';
  for (let i=0; i<symbol.length; i++) {
    initialSymbolHexStr += symbol.charCodeAt(i).toString(16);
  }

  const initialSymbolHexStrLength = initialSymbolHexStr.length;

  let bep2Bytes32Symbol = initialSymbolHexStr;
  for (let i = 0; i < 64 - initialSymbolHexStrLength; i++) {
    bep2Bytes32Symbol = bep2Bytes32Symbol + "0";
  }
  return '0x'+bep2Bytes32Symbol;
}

export function buildTransferInPackage(bep2TokenSymbol: string, bep20Addr: string, amount: number | bigint, recipient: string, refundAddr: string) {
  let timestamp = Math.floor(Date.now() / 1000); // counted by second
  let initialExpireTimeStr = (timestamp + 100).toString(16); // expire at 5 second later
  const initialExpireTimeStrLength = initialExpireTimeStr.length;
  let expireTimeStr = initialExpireTimeStr;
  for (let i = 0; i < 16 - initialExpireTimeStrLength; i++) {
    expireTimeStr = '0' + expireTimeStr;
  }
  expireTimeStr = "0x" + expireTimeStr;

  const packageBytesPrefix = buildSyncPackagePrefix(1e16);

  const packageBytes = RLP.encode([
    stringToBytes32(bep2TokenSymbol),
    bep20Addr,
    amount,
    recipient,
    refundAddr,
    expireTimeStr]);

  return Buffer.concat([packageBytesPrefix, packageBytes]);
}

export function toRpcQuantity(x: BigNumber | number | string): string {
  let hex: string;
  if (typeof x === "number" || typeof x === "bigint") {
    // TODO: check that number is safe
    hex = `0x${x.toString(16)}`;
  } else if (typeof x === "string") {
    if (!x.startsWith("0x")) {
      throw "Only 0x-prefixed hex-encoded strings are accepted";
    }
    hex = x;
  } else if ("toHexString" in x) {
    hex = x.toHexString();
  } else if ("toString" in x) {
    // @ts-ignore
    hex = x.toString(16);
  } else {
    throw `${x as any} cannot be converted to an RPC quantity`;
  }


  if (hex === "0x0") return hex;

  return hex.startsWith("0x") ? hex.replace(/0x0+/, "0x") : `0x${hex}`;
}
