pragma solidity 0.6.4;

import "./System.sol";
import "./lib/Memory.sol";
import "./lib/BytesToTypes.sol";
import "./interface/ICrossChain.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/IApplication.sol";
import "./lib/CmnPkg.sol";
import "./lib/SafeMath.sol";
import "./lib/RLPEncode.sol";
import "./lib/RLPDecode.sol";

contract CrossStake is System, IParamSubscriber, IApplication {
  using SafeMath for uint256;
  using RLPEncode for *;

  // Cross-Chain Stake Event type
  uint8 public constant EVENT_STAKE = 0x01;
  uint8 public constant EVENT_UNSTAKE = 0x02;
  uint8 public constant EVENT_CLAIM_REWARD = 0x03;
  uint8 public constant EVENT_CLAIM_UNSTAKE = 0x04;
  uint8 public constant EVENT_RESTAKE = 0x05;

  uint256 public constant INIT_ORACLE_RELAYER_FEE = 2e15;
  uint256 public constant INIT_BSC_RELAYER_FEE = 0;

  uint256 public oracleRelayerFee;
  uint256 public BSCRelayerFee;

  bool internal locked;

  modifier noReentrant() {
    require(!locked, "No re-entrancy");
    locked = true;
    _;
    locked = false;
  }

  modifier initRelayerFee() {
    if (oracleRelayerFee == 0 || BSCRelayerFee == 0) {
      oracleRelayerFee = INIT_ORACLE_RELAYER_FEE;
      BSCRelayerFee = INIT_BSC_RELAYER_FEE;
    }
    _;
  }

  /*********************** events **************************/
  event stake(address indexed delAddr, address indexed validator, uint256 amount);
  event unstake(address indexed delAddr, address indexed validator, uint256 amount);
  event claimReward(address indexed receiver);
  event claimUnstake(address indexed receiver);
  event restake(address indexed delAddr, address indexed validator, uint256 amount);
  event paramChange(string key, bytes value);
  event unexpectedPackage(uint8 channelId, bytes msgBytes);

  /*********************** Implement cross chain app ********************************/
  function handleSynPackage(uint8, bytes calldata) external onlyCrossChainContract onlyInit override returns(bytes memory) {
    require(false, "receive unexpected syn package");
  }

  function handleAckPackage(uint8, bytes calldata msgBytes) external onlyCrossChainContract onlyInit override {
    // should not happen
    emit unexpectedPackage(channelId, msgBytes);
  }

  function handleFailAckPackage(uint8, bytes calldata) external onlyCrossChainContract onlyInit override {
    // should not happen
    emit unexpectedPackage(channelId, msgBytes);
  }

  function stakeTo(address validator, uint256 _oracleRelayerFee) external payable initRelayerFee {
    uint256 amount = msg.value;
    require(amount > _oracleRelayerFee && _oracleRelayerFee >= oracleRelayerFee, "Send value cannot cover the relayer fee or stake value is zero");

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_STAKE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = (amount-_oracleRelayerFee).encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee);
    emit stake(msg.sender, validator, amount-_oracleRelayerFee);
  }

  function unstakeFrom(address validator, uint256 amount) external payable initRelayerFee {
    uint256 _oracleRelayerFee = msg.value;
    require(_oracleRelayerFee >= oracleRelayerFee, "Send value cannot cover the relayer fee");

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_UNSTAKE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = amount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee);
    emit unstake(msg.sender, validator, amount);
  }

  function claimRewardTo(address receiver, uint256 _oracleRelayerFee) external payable initRelayerFee noReentrant {
    uint256 amount = msg.value;
    require(amount >= _oracleRelayerFee+BSCRelayerFee && _oracleRelayerFee >= oracleRelayerFee, "Send value cannot cover the relayer fee");

    bytes[] memory elements = new bytes[](3);
    elements[0] = EVENT_CLAIM_REWARD.encodeUint();
    elements[1] = receiver.encodeAddress();
    uint256 _bSCRelayerFee = amount-_oracleRelayerFee;
    elements[2] = _bSCRelayerFee.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee);
    emit claimReward(receiver);
  }

  function claimUnstakeTo(address receiver, uint256 _oracleRelayerFee) external payable initRelayerFee noReentrant {
    uint256 amount = msg.value;
    require(amount >= _oracleRelayerFee+BSCRelayerFee && _oracleRelayerFee >= oracleRelayerFee, "Send value cannot cover the relayer fee");

    bytes[] memory elements = new bytes[](3);
    elements[0] = EVENT_CLAIM_UNSTAKE.encodeUint();
    elements[1] = receiver.encodeAddress();
    uint256 _bSCRelayerFee = amount-_oracleRelayerFee;
    elements[2] = _bSCRelayerFee.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee);
    emit claimUnstake(receiver);
  }

  function restakeTo(address validator, uint256 amount) external payable initRelayerFee {
    uint256 _oracleRelayerFee = msg.value;
    require(_oracleRelayerFee >= oracleRelayerFee, "Send value cannot cover the relayer fee");

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_RESTAKE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = amount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee);
    emit restake(msg.sender, validator, amount);
  }

  function updateParam(string calldata key, bytes calldata value) override external onlyInit onlyGov {
    if (Memory.compareStrings(key, "oracleRelayerFee")) {
      require(value.length == 32, "length of oracleRelayerFee mismatch");
      uint256 newOracleRelayerFee = BytesToTypes.bytesToUint256(32, value);
      require(newOracleRelayerFee >0, "the oracleRelayerFee must be greater than 0");
      oracleRelayerFee = newOracleRelayerFee;
    } else if (Memory.compareStrings(key, "BSCRelayerFee")) {
      require(value.length == 32, "length of BSCRelayerFee mismatch");
      uint256 newBSCRelayerFee = BytesToTypes.bytesToUint256(32, value);
      require(newBSCRelayerFee > 0, "the BSCRelayerFee must be greater than 0");
      BSCRelayerFee = newBSCRelayerFee;
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }
}
