const SlashIndicator = artifacts.require("SlashIndicator");
const SystemReward = artifacts.require("SystemReward");
const TypesToBytes = artifacts.require("Seriality/TypesToBytes");
const CmnPkg = artifacts.require("Seriality/CmnPkg");
const RLPDecode = artifacts.require("rlp/RLPDecode");
const RLPEncode = artifacts.require("rlp/RLPEncode");
const BytesToTypes = artifacts.require("rlp/BytesToTypes");
const Memory = artifacts.require("Seriality/Memory");
const SafeMath = artifacts.require("lib/SafeMath");
const BytesLib = artifacts.require("solidity-bytes-utils/contracts/BytesLib");

const MockLightClient = artifacts.require("mock/MockLightClient");
const MockTokenHub = artifacts.require("mock/MockTokenHub");
const MockRelayerHub = artifacts.require("mock/MockRelayerHub");
const BSCValidatorSet = artifacts.require("BSCValidatorSet");
const RelayerHub = artifacts.require("RelayerHub");
const GovHub = artifacts.require("GovHub");
const Staking = artifacts.require("Staking");

const RelayerIncentivize = artifacts.require("RelayerIncentivize");
const TendermintLightClient = artifacts.require("TendermintLightClient");
const CrossChain = artifacts.require("CrossChain");
const TokenHub = artifacts.require("TokenHub");
const TokenManager = artifacts.require("TokenManager");
const ABCToken = artifacts.require("test/ABCToken");
const DEFToken = artifacts.require("test/DEFToken");
const XYZToken = artifacts.require("test/XYZToken");
const MiniToken = artifacts.require("test/MiniToken");
const MaliciousToken = artifacts.require("test/MaliciousToken");
const BSCValidatorSetTool = artifacts.require("tool/BSCValidatorSetTool");

const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));


module.exports = function(deployer, network, accounts) {
  let relayerIncentivizeInstance;
  deployer.deploy(RelayerIncentivize).then(function(_relayerIncentivizeInstance){
    relayerIncentivizeInstance=_relayerIncentivizeInstance;
    relayerIncentivizeInstance.init();
  });
  let tendermintLightClientInstance;
  deployer.deploy(TendermintLightClient).then(function(_tendermintLightClientInstance){
    tendermintLightClientInstance=_tendermintLightClientInstance;
    tendermintLightClientInstance.init();
  });
  let crossChainInstance;
  deployer.deploy(CrossChain).then(function (_crossChainInstance) {
    crossChainInstance = _crossChainInstance;
  });
  let stakingInstance;
  deployer.deploy(Staking).then(function (_stakingInstance) {
    stakingInstance = _stakingInstance;
  });
  deployer.deploy(ABCToken);
  deployer.deploy(DEFToken);
  deployer.deploy(XYZToken);
  deployer.deploy(MiniToken);
  deployer.deploy(MaliciousToken);
  deployer.deploy(MockRelayerHub);
  deployer.deploy(BSCValidatorSetTool);

  // let operators = [accounts[0],accounts[1], accounts[2]];
  deployer.deploy(SystemReward).then(function (instance) {
    instance.addOperator(accounts[0], {from: accounts[0]});
    instance.addOperator(accounts[1], {from: accounts[0]});
    instance.addOperator(accounts[2], {from: accounts[0]});
    instance.addOperator(TendermintLightClient.address, {from: accounts[0]});
    instance.addOperator(RelayerIncentivize.address, {from: accounts[0]});
  });

  let tokenMgrInstance;
  let tokenHubInstance;
  let relayerHubInstance;
  // deploy lib
  deployer.deploy(TypesToBytes).then(function() {
    return deployer.deploy(BytesToTypes);
  }).then(function() {
    return deployer.deploy(Memory);
  }).then(function() {
    return deployer.deploy(SafeMath);
  }).then(function() {
    return deployer.deploy(BytesLib);
  }).then(function() {
    return deployer.deploy(CmnPkg);
  }).then(function() {
    return deployer.deploy(RLPDecode);
  }).then(function() {
    return deployer.deploy(RLPEncode);
  }).then(function() {
    // deploy mock
    return deployer.deploy(MockLightClient);
  }).then(function() {
    deployer.deploy(TokenHub).then(function(_tokenHubInstance){
      deployer.link(RLPEncode, TokenHub);
      deployer.link(RLPDecode, TokenHub);
      deployer.link(SafeMath, TokenHub);
      tokenHubInstance=_tokenHubInstance;
      tokenHubInstance.init();
      tokenHubInstance.sendTransaction({from:accounts[0],value:50e18});
    });
  }).then(function() {
    deployer.deploy(TokenManager).then(function(_tokenMgrInstance){
      deployer.link(RLPEncode, TokenManager);
      deployer.link(RLPDecode, TokenManager);
      deployer.link(SafeMath, TokenManager);
      tokenMgrInstance=_tokenMgrInstance;
    });
  }).then(function() {
    // deploy mock
    deployer.link(Memory, RelayerHub);
    return deployer.deploy(RelayerHub);
  }).then(function(_relayerHubInstance) {
    relayerHubInstance=_relayerHubInstance;
    relayerHubInstance.init();
    relayerHubInstance.register({from: accounts[8],value: 1e20});
    // deploy mock
    return deployer.deploy(MockTokenHub);
  }).then(function() {
    deployer.link(Memory, SlashIndicator);
    return deployer.deploy(SlashIndicator);
  }).then(function(slashInstance) {
    slashInstance.init();
    deployer.link(TypesToBytes, BSCValidatorSet);
    deployer.link(BytesToTypes, BSCValidatorSet);
    deployer.link(Memory, BSCValidatorSet);
    deployer.link(BytesLib, BSCValidatorSet);
    deployer.link(CmnPkg, BSCValidatorSet);
    deployer.link(RLPDecode, BSCValidatorSet);

    deployer.link(BytesToTypes, GovHub);
    deployer.link(Memory, GovHub);
    deployer.link(BytesLib, GovHub);

    let govHubInstance;
    deployer.deploy(GovHub).then(function(_govHubInstance){
      govHubInstance=_govHubInstance;
    });

    return deployer.deploy(BSCValidatorSet).then(function (validatorInstance) {
      validatorInstance.init();
      relayerIncentivizeInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address, MockLightClient.address,TokenHub.address,RelayerIncentivize.address,RelayerHub.address,GovHub.address, TokenManager.address, CrossChain.address, Staking.address);
      tendermintLightClientInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address, MockLightClient.address,TokenHub.address,RelayerIncentivize.address,RelayerHub.address,GovHub.address, TokenManager.address, CrossChain.address, Staking.address);
      tokenHubInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address, MockLightClient.address,TokenHub.address,RelayerIncentivize.address,RelayerHub.address,GovHub.address, TokenManager.address, CrossChain.address, Staking.address);
      tokenMgrInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address, MockLightClient.address,TokenHub.address,RelayerIncentivize.address,RelayerHub.address,GovHub.address, TokenManager.address, CrossChain.address, Staking.address);
      govHubInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address, MockLightClient.address,TokenHub.address,RelayerIncentivize.address,RelayerHub.address,GovHub.address, TokenManager.address, accounts[8], Staking.address);
      slashInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address, MockLightClient.address,TokenHub.address,RelayerIncentivize.address,RelayerHub.address,GovHub.address, TokenManager.address, CrossChain.address, Staking.address);
      validatorInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address, MockLightClient.address,MockTokenHub.address,RelayerIncentivize.address,RelayerHub.address,GovHub.address, TokenManager.address, accounts[8], Staking.address);
      relayerHubInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address, MockLightClient.address,TokenHub.address,RelayerIncentivize.address,RelayerHub.address,GovHub.address, TokenManager.address, CrossChain.address, Staking.address);
      crossChainInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address, MockLightClient.address,TokenHub.address,RelayerIncentivize.address,RelayerHub.address,GovHub.address, TokenManager.address, CrossChain.address, Staking.address);
      stakingInstance.updateContractAddr(BSCValidatorSet.address, SlashIndicator.address, SystemReward.address, MockLightClient.address,TokenHub.address,RelayerIncentivize.address,RelayerHub.address,GovHub.address, TokenManager.address, CrossChain.address, Staking.address)
      crossChainInstance.init();
    });
  });
};
