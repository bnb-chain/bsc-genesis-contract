pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "./interface/IBSCValidatorSet.sol";
import "./interface/ICrossChain.sol";
import "./interface/IGovHub.sol";
import "./interface/IRelayerHub.sol";
import "./interface/IRelayerIncentivize.sol";
import "./interface/ISlashIndicator.sol";
import "./interface/IStaking.sol";
import "./interface/ISystemReward.sol";
import "./interface/ITokenHub.sol";
import "./interface/ITokenManager.sol";
import "./interface/ITendermintLightClient.sol";
import "../lib/RLPEncode.sol";
import "../lib/RLPDecode.sol";

contract Deployer is Test {
  using RLPEncode for *;

  // system contract address
  address public constant VALIDATOR_CONTRACT_ADDR = 0x0000000000000000000000000000000000001000;
  address public constant SLASH_CONTRACT_ADDR = 0x0000000000000000000000000000000000001001;
  address public constant SYSTEM_REWARD_ADDR = 0x0000000000000000000000000000000000001002;
  address public constant LIGHT_CLIENT_ADDR = 0x0000000000000000000000000000000000001003;
  address public constant TOKEN_HUB_ADDR = 0x0000000000000000000000000000000000001004;
  address public constant INCENTIVIZE_ADDR = 0x0000000000000000000000000000000000001005;
  address public constant RELAYERHUB_CONTRACT_ADDR = 0x0000000000000000000000000000000000001006;
  address public constant GOV_HUB_ADDR = 0x0000000000000000000000000000000000001007;
  address public constant TOKEN_MANAGER_ADDR = 0x0000000000000000000000000000000000001008;
  address public constant CROSS_CHAIN_CONTRACT_ADDR = 0x0000000000000000000000000000000000002000;
  address public constant STAKING_CONTRACT_ADDR = 0x0000000000000000000000000000000000002001;

  uint8 public constant BIND_CHANNELID = 0x01;
  uint8 public constant TRANSFER_IN_CHANNELID = 0x02;
  uint8 public constant TRANSFER_OUT_CHANNELID = 0x03;
  uint8 public constant MIRROR_CHANNELID = 0x04;
  uint8 public constant SYNC_CHANNELID = 0x05;
  uint8 public constant STAKING_CHANNELID = 0x08;
  uint8 public constant GOV_CHANNELID = 0x09;
  uint8 public constant SLASH_CHANNELID = 0x0b;
  uint8 public constant CROSS_STAKE_CHANNELID = 0x10;

  BSCValidatorSet public validator;
  SlashIndicator public slash;
  SystemReward public systemReward;
  TendermintLightClient public lightClient;
  TokenHub public tokenHub;
  RelayerIncentivize public incentivize;
  RelayerHub public relayerHub;
  GovHub public govHub;
  TokenManager public tokenManager;
  CrossChain public crossChain;
  Staking public staking;

  address payable public relayer;
  address payable[] public addrSet;
  uint256 public addrIdx;

  bytes32 internal nextUser = keccak256(abi.encodePacked("user address"));

  constructor() {
    // create fork
    // you should modify this for your own test, which generally should be the bsc mainnet latest number
    vm.createSelectFork("bsc", 23839447);

    validator = BSCValidatorSet(VALIDATOR_CONTRACT_ADDR);
    vm.label(address(validator), "Validator");
    slash = SlashIndicator(SLASH_CONTRACT_ADDR);
    vm.label(address(slash), "SlashIndicator");
    systemReward = SystemReward(SYSTEM_REWARD_ADDR);
    vm.label(address(systemReward), "SystemReward");
    lightClient = TendermintLightClient(LIGHT_CLIENT_ADDR);
    vm.label(address(lightClient), "LightClient");
    tokenHub = TokenHub(TOKEN_HUB_ADDR);
    vm.label(address(tokenHub), "TokenHub");
    incentivize = RelayerIncentivize(INCENTIVIZE_ADDR);
    vm.label(address(incentivize), "RelayerIncentivize");
    relayerHub = RelayerHub(RELAYERHUB_CONTRACT_ADDR);
    vm.label(address(relayerHub), "RelayerHub");
    govHub = GovHub(GOV_HUB_ADDR);
    vm.label(address(govHub), "GovHub");
    tokenManager = TokenManager(TOKEN_MANAGER_ADDR);
    vm.label(address(tokenManager), "TokenManager");
    crossChain = CrossChain(CROSS_CHAIN_CONTRACT_ADDR);
    vm.label(address(crossChain), "CrossChain");
    staking = Staking(STAKING_CONTRACT_ADDR);
    vm.label(address(staking), "Staking");

    addrSet = createUsers(100);

    relayer = payable(0xb005741528b86F5952469d80A8614591E3c5B632); // whitelabel relayer
    vm.label(relayer, "relayer");
  }

  // create users with 1,000,000 ether balance
  function createUsers(uint256 userNum) public returns (address payable[] memory) {
    address payable[] memory users = new address payable[](userNum);
    for (uint256 i = 0; i < userNum; ++i) {
      address payable user = _getNextUserAddress();
      vm.deal(user, 1_000_000 ether);
      users[i] = user;
    }
    return users;
  }

  function _getNextUserAddress() internal returns (address payable) {
    //bytes32 to address conversion
    address payable user = payable(address(uint160(uint256(nextUser))));
    nextUser = keccak256(abi.encodePacked(nextUser));
    return user;
  }

  function updateParamByGovHub(bytes memory key, bytes memory value, address addr) public {
    bytes[] memory elements = new bytes[](3);
    elements[0] = key.encodeBytes();
    elements[1] = value.encodeBytes();
    elements[2] = addr.encodeAddress();

    vm.startPrank(address(crossChain));
    govHub.handleSynPackage(GOV_CHANNELID, elements.encodeList());
    vm.stopPrank();
  }

  function encodeOldValidatorSetUpdatePack(uint8 code, address[] memory valSet) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](2);
    elements[0] = code.encodeUint();

    bytes[] memory vals = new bytes[](valSet.length);
    for (uint256 i; i < valSet.length; ++i) {
      bytes[] memory tmp = new bytes[](4);
      tmp[0] = valSet[i].encodeAddress();
      tmp[1] = valSet[i].encodeAddress();
      tmp[2] = valSet[i].encodeAddress();
      tmp[3] = uint8(0x64).encodeUint();
      vals[i] = tmp.encodeList();
    }

    elements[1] = vals.encodeList();
    return elements.encodeList();
  }

  function encodeNewValidatorSetUpdatePack(uint8 code, address[] memory valSet, bytes[] memory voteAddrs) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](2);
    elements[0] = code.encodeUint();

    bytes[] memory vals = new bytes[](valSet.length);
    for (uint256 i; i < valSet.length; ++i) {
      bytes[] memory tmp = new bytes[](5);
      tmp[0] = valSet[i].encodeAddress();
      tmp[1] = valSet[i].encodeAddress();
      tmp[2] = valSet[i].encodeAddress();
      tmp[3] = uint8(0x64).encodeUint();
      tmp[4] = voteAddrs[i].encodeBytes();
      vals[i] = tmp.encodeList();
    }

    elements[1] = vals.encodeList();
    return elements.encodeList();
  }
}
