pragma solidity 0.6.4;

import "./System.sol";
import "./interface/ICrossChain.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/IApplication.sol";
import "./lib/SafeMath.sol";
import "./lib/RLPDecode.sol";

contract CrossStake is System, IParamSubscriber, IApplication {
  using SafeMath for uint256;
  using RLPDecode for *;

  uint8 constant public CROSS_STAKE_CHANNELID = 0x10;

  // Cross-Chain Stake Event type
  uint8 public constant EVENT_STAKE = 0x00;
  uint8 public constant EVENT_UNSTAKE = 0x01;
  uint8 public constant EVENT_CLAIM_REWARD = 0x02;
  uint8 public constant EVENT_CLAIM_UNSTAKE = 0x03;
  uint8 public constant EVENT_RESTAKE = 0x04;

  //TODO
  uint256 public constant INIT_ORACLE_RELAYER_FEE = 0;
  uint256 public constant INIT_BSC_RELAYER_FEE = 0;

  uint256 public oracleRelayerFee;
  uint256 public BSCRelayerFee;

  modifier initRelayerFee() {
    if (oracleRelayerFee == 0) {
      oracleRelayerFee = INIT_ORACLE_RELAYER_FEE;
      BSCRelayerFee = INIT_BSC_RELAYER_FEE;
    }
    _;
  }

  function stake(address validator) payable initRelayerFee {
    uint256 amount = msg.value;
    require(amount > oracleRelayerFee, "Send value cannot cover the relayer fee");

    bytes memory msgBytes;
    msgBytes = abi.encode(EVENT_STAKE, msg.sender, amount-oracleRelayerFee, validator);
    ICrossChain.sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, oracleRelayerFee);
  }

  function unstake(address validator, uint256 amount) payable initRelayerFee {
    uint256 _value = msg.value;
    require(amount >= oracleRelayerFee, "Send value cannot cover the relayer fee");

    bytes memory msgBytes;
    msgBytes = abi.encode(EVENT_UNSTAKE, msg.sender, validator, amount);
    ICrossChain.sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, oracleRelayerFee);
  }

  function claimReward() payable initRelayerFee {
    uint256 _value = msg.value;
    require(amount >= oracleRelayerFee+BSCRelayerFee, "Send value cannot cover the relayer fee");

    bytes memory msgBytes;
    msgBytes = abi.encode(EVENT_CLAIM_REWARD, msg.sender, BSCRelayerFee);
    ICrossChain.sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, oracleRelayerFee);
  }

  function claimUnstake() payable initRelayerFee {
    uint256 _value = msg.value;
    require(amount >= oracleRelayerFee+BSCRelayerFee, "Send value cannot cover the relayer fee");

    bytes memory msgBytes;
    msgBytes = abi.encode(EVENT_CLAIM_UNSTAKE, msg.sender, BSCRelayerFee);
    ICrossChain.sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, oracleRelayerFee);
  }

  function reStake(address validator, uint256 amount) payable initRelayerFee {
    uint256 _value = msg.value;
    require(amount >= oracleRelayerFee, "Send value cannot cover the relayer fee");

    bytes memory msgBytes;
    msgBytes = abi.encode(EVENT_RESTAKE, msg.sender, validator, amount);
    ICrossChain.sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, oracleRelayerFee);
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
