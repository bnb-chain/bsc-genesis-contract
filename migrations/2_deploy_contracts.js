<<<<<<< HEAD
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
  // let operators = [accounts[0],accounts[1], accounts[2]];
  deployer.deploy(SystemReward).then(function (instance) {
    instance.addOperator(accounts[0], {from: accounts[0]});
    instance.addOperator(accounts[1], {from: accounts[0]});
    instance.addOperator(accounts[2], {from: accounts[0]});
  })

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
    // deploy mock
    return deployer.deploy(SlashIndicator);
  }).then(function(slashInstance) {
    deployer.link(TypesToBytes, BSCValidatorSet);
    deployer.link(BytesToTypes, BSCValidatorSet);
    deployer.link(SizeOf, BSCValidatorSet);
    deployer.link(BytesLib, BSCValidatorSet);
    return deployer.deploy(BSCValidatorSet).then(function (instance) {
      instance.init();
      slashInstance.init();
      slashInstance.updateContractAddr(BSCValidatorSet.address);
      instance.updateContractAddr(SystemReward.address, CrossChainTransfer.address, LightClient.address, SlashIndicator.address, web3.eth.accounts.create().address)
      });
  });
};

