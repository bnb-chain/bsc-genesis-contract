const SlashIndicator = artifacts.require("SlashIndicator");
const SystemReward = artifacts.require("SystemReward");
const TypesToBytes = artifacts.require("Seriality/TypesToBytes");
const BytesToTypes = artifacts.require("Seriality/BytesToTypes");
const SizeOf = artifacts.require("Seriality/SizeOf");
const BytesLib = artifacts.require("solidity-bytes-utils/contracts/BytesLib");

const LightClient = artifacts.require("mock/LightClient");
const CrossChainTransfer = artifacts.require("mock/CrossChainTransfer");
const BSCValidatorSet = artifacts.require("BSCValidatorSet");

const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

module.exports = function(deployer,network, accounts) {
  deployer.deploy(SlashIndicator);
  let operators = [accounts[0],accounts[1], accounts[2]];
  deployer.deploy(SystemReward, operators);

  // deploy lib
  deployer.deploy(TypesToBytes).then(function() {
    return deployer.deploy(BytesToTypes);
  }).then(function() {
    return deployer.deploy(SizeOf);
  }).then(function() {
    return deployer.deploy(BytesLib);
  }).then(function() {
    // deploy mock
    return deployer.deploy(LightClient);
  }).then(function() {
    // deploy mock
    return deployer.deploy(CrossChainTransfer);
  }).then(function() {
    deployer.link(TypesToBytes, BSCValidatorSet);
    deployer.link(BytesToTypes, BSCValidatorSet);
    deployer.link(SizeOf, BSCValidatorSet);
    deployer.link(BytesLib, BSCValidatorSet);

    let fromChain = web3.utils.hexToBytes(web3.utils.stringToHex("Binance-Chain-Tigris"));
    let toChain = web3.utils.hexToBytes(web3.utils.stringToHex("714"))

    let tokenAddress = web3.eth.accounts.create().address;
    return deployer.deploy(BSCValidatorSet,fromChain,toChain, SystemReward.address, CrossChainTransfer.address,
        LightClient.address, tokenAddress,
        serialize([accounts[9]],[accounts[9]],[web3.eth.accounts.create().address]));
  });
};


function serialize(consensusAddrList,feeAddrList, bscFeeAddrList ) {
  let n = consensusAddrList.length;
  let arr = [];
  for(let i = 0;i<n;i++){
    arr.push(Buffer.from(web3.utils.hexToBytes(consensusAddrList[i].toString())));
    arr.push(Buffer.from(web3.utils.hexToBytes(feeAddrList[i].toString())));
    arr.push(Buffer.from(web3.utils.hexToBytes(bscFeeAddrList[i].toString())));
  }
  return Buffer.concat(arr);
}