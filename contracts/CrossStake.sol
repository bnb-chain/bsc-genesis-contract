pragma solidity 0.6.4;

import "./System.sol";
import "./interface/ICrossChain.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/IApplication.sol";
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

  function stake(address validator) payable initRelayerFee {
    uint256 amount = msg.value;
    require(amount > oracleRelayerFee, "Send value cannot cover the relayer fee or stake value is zero");

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_STAKE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = amount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain.sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, oracleRelayerFee);
  }

  function unstake(address validator, uint256 amount) payable initRelayerFee {
    uint256 _amount = msg.value;
    require(_amount >= oracleRelayerFee, "Send value cannot cover the relayer fee");

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_UNSTAKE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = amount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain.sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _amount);
  }

  function claimReward(address receiver) payable initRelayerFee noReentrant {
    uint256 amount = msg.value;
    require(amount >= oracleRelayerFee+BSCRelayerFee, "Send value cannot cover the relayer fee");

    bytes[] memory elements = new bytes[](3);
    elements[0] = EVENT_CLAIM_REWARD.encodeUint();
    elements[1] = receiver.encodeAddress();
    uint256 _bSCRelayerFee = amount-oracleRelayerFee;
    elements[2] = _bSCRelayerFee.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain.sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, oracleRelayerFee);
  }

  function claimUnstake(address receiver) payable initRelayerFee noReentrant {
    uint256 amount = msg.value;
    require(amount >= oracleRelayerFee+BSCRelayerFee, "Send value cannot cover the relayer fee");

    bytes[] memory elements = new bytes[](3);
    elements[0] = EVENT_CLAIM_UNSTAKE.encodeUint();
    elements[1] = receiver.encodeAddress();
    uint256 _bSCRelayerFee = amount-oracleRelayerFee;
    elements[2] = _bSCRelayerFee.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain.sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, oracleRelayerFee);
  }

  function reStake(address validator, uint256 amount) payable initRelayerFee {
    uint256 _amount = msg.value;
    require(amount >= oracleRelayerFee, "Send value cannot cover the relayer fee");

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_RESTAKE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = amount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain.sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _amount);
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
