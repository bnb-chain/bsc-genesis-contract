import {ethers} from "hardhat";
import {Signer} from "@ethersproject/abstract-signer";
import {Contract, ContractReceipt, ContractTransaction} from "@ethersproject/contracts";

export async function deployContract(signer: Signer, factoryPath: string, ...args: Array<any>): Promise<Contract> {
  const factory = await ethers.getContractFactory(factoryPath);
  const contract = await factory.connect(signer).deploy(...args);
  await contract.deployTransaction.wait(1)
  return contract
}

export async function waitTx(txRequest: Promise<ContractTransaction>): Promise<ContractReceipt> {
  const txResponse = await txRequest
  return await txResponse.wait(1)
}


