pragma solidity 0.6.4;

import "./System.sol";
import "./lib/Memory.sol";
import "./lib/BytesToTypes.sol";
import "./interface/IApplication.sol";
import "./interface/ICrossChain.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/ITokenHub.sol";
import "./lib/CmnPkg.sol";
import "./lib/SafeMath.sol";
import "./lib/RLPEncode.sol";
import "./lib/RLPDecode.sol";
import "./interface/IStaking.sol";

contract Staking is IStaking, System, IParamSubscriber, IApplication {
  using SafeMath for uint256;
  using RLPEncode for *;
  using RLPDecode for *;

  struct DelegateAckPackage {
    address delegator;
    address validator;
    uint256 amount;
    uint8 errCode;
  }

  struct UndelegateAckPackage {
    address delegator;
    address validator;
    uint256 amount;
    uint8 errCode;
  }

  struct RedelegateAckPackage {
    address delegator;
    address valSrc;
    address valDst;
    uint256 amount;
    uint8 errCode;
  }

  struct DistributeRewardSynPackage {
    uint256 amount;
    address recipient;
  }

  struct DistributeUndelegatedSynPackage {
    uint256 amount;
    address recipient;
    address validator;
  }

  // Cross-Chain Stake Event type
  uint8 public constant EVENT_DELEGATE = 0x01;
  uint8 public constant EVENT_UNDELEGATE = 0x02;
  uint8 public constant EVENT_REDELEGATE = 0x03;
  uint8 public constant EVENT_DISTRIBUTE_REWARD = 0x04;
  uint8 public constant EVENT_DISTRIBUTE_UNDELEGATED = 0x05;

  uint32 public constant ERROR_UNKNOWN_PACKAGE_TYPE = 101;
  uint32 public constant ERROR_WITHDRAW_BNB = 102;

  uint256 constant public TEN_DECIMALS = 1e10;

  uint256 public constant INIT_ORACLE_RELAYER_FEE = 2e16; //TODO
  uint256 public constant INIT_MIN_DELEGATION_CHANGE = 1e20;

  uint256 public oracleRelayerFee;
  uint256 public minDelegationChange;

  mapping(address => uint256) delegated;
  mapping(address => mapping(address => uint256)) delegatedOfValidator;
  mapping(address => uint256) distributedReward;
  mapping(address => mapping(address => uint256)) pendingUndelegated;
  mapping(address => uint256) undelegated;
  mapping(address => mapping(address => mapping(address => uint256))) pendingRedelegate;

  bool internal locked;

  modifier noReentrant() {
    require(!locked, "No re-entrancy");
    locked = true;
    _;
    locked = false;
  }

  modifier tenDecimalPrecision(uint256 amount) {
    require(msg.value%TEN_DECIMALS==0,
      "invalid msg value: precision loss in amount conversion");
    require(amount%TEN_DECIMALS==0,
      "invalid amount: precision loss in amount conversion");
    _;
  }

  modifier initParams() {
    if (!alreadyInit) {
      oracleRelayerFee = INIT_ORACLE_RELAYER_FEE;
      minDelegationChange = INIT_MIN_DELEGATION_CHANGE;
      alreadyInit = true;
    }
    _;
  }

  /*********************************** Events **********************************/
  event delegateSubmitted(address indexed delegator, address indexed validator, uint256 amount, uint256 oracleRelayerFee);
  event undelegateSubmitted(address indexed delegator, address indexed validator, uint256 amount, uint256 oracleRelayerFee);
  event redelegateSubmitted(address indexed delegator, address indexed validatorSrc, address indexed validatorDst, uint256 amount, uint256 oracleRelayerFee);
  event rewardReceived(address indexed delegator, uint256 amount);
  event rewardClaimed(address indexed delegator, uint256 amount);
  event undelegatedReceived(address indexed delegator, uint256 amount);
  event undelegatedClaimed(address indexed delegator, uint256 amount);
  event failedDelegate(address indexed delegator, address indexed validator, uint256 amount, uint8 errCode);
  event failedUndelegate(address indexed delegator, address indexed validator, uint256 amount, uint8 errCode);
  event failedRedelegate(address indexed delegator, address indexed valSrc, address indexed valDst, uint256 amount, uint8 errCode);
  event paramChange(string key, bytes value);
  event failedSynPackage(uint256 errCode);
  event crashResponse();

  receive() external payable {}

  /************************* Implement cross chain app *************************/
  function handleSynPackage(uint8, bytes calldata msgBytes) external onlyCrossChainContract initParams override returns(bytes memory) {
    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    uint8 eventCode = uint8(iter.next().toUint());
    uint32 resCode;
    if (eventCode == EVENT_DISTRIBUTE_REWARD) {
      resCode = _handleDistributeRewardSynPackage(iter);
    } else if (eventCode == EVENT_DISTRIBUTE_UNDELEGATED) {
      resCode = _handleDistributeUndelegatedSynPackage(iter);
    } else {
      resCode = ERROR_UNKNOWN_PACKAGE_TYPE;
    }

    if (resCode == CODE_OK) {
      return new bytes(0);
    } else {
      emit failedSynPackage(resCode);
      return msgBytes;
    }
  }

  function handleAckPackage(uint8, bytes calldata msgBytes) external onlyCrossChainContract initParams override {
    RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
    uint8 eventCode = uint8(iter.next().toUint());
    if (eventCode == EVENT_DELEGATE) {
      _handleDelegateAckPackage(iter);
    } else if (eventCode == EVENT_UNDELEGATE) {
      _handleUndelegateAckPackage(iter);
    } else if (eventCode == EVENT_REDELEGATE) {
      _handleRedelegateAckPackage(iter);
    } else {
      require(false, "unknown event type");
    }
    return;
  }

  function handleFailAckPackage(uint8, bytes calldata) external onlyCrossChainContract initParams override {
    emit crashResponse();
    return;
  }

  /***************************** External functions *****************************/
  function delegate(address validator, uint256 amount) override external payable tenDecimalPrecision(amount) initParams {
    require(amount >= minDelegationChange, "the amount must not be less than minDelegationChange");
    require(msg.value >= amount.add(oracleRelayerFee), "the msg value should be no less than the sum of stake amount and minimum oracleRelayerFee");

    // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
    uint256 convertedAmount = amount.div(TEN_DECIMALS);
    uint256 _oracleRelayerFee = (msg.value).sub(amount);

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_DELEGATE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = convertedAmount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, _RLPEncode(EVENT_DELEGATE, msgBytes), _oracleRelayerFee.div(TEN_DECIMALS));
    payable(TOKEN_HUB_ADDR).transfer(msg.value);

    delegated[msg.sender] = delegated[msg.sender].add(amount);
    delegatedOfValidator[msg.sender][validator] = delegatedOfValidator[msg.sender][validator].add(amount);

    emit delegateSubmitted(msg.sender, validator, amount, _oracleRelayerFee);
  }

  function undelegate(address validator, uint256 amount) override external payable tenDecimalPrecision(amount) initParams {
    require(pendingUndelegated[msg.sender][validator] == 0, "pending undelegation exist");
    if (amount < minDelegationChange) {
      require(amount == delegatedOfValidator[msg.sender][validator],
        "the amount must not be less than minDelegationChange, or else equal to the remaining delegation");
    }
    delegatedOfValidator[msg.sender][validator] = delegatedOfValidator[msg.sender][validator].sub(amount, "not enough funds to undelegate");

    // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
    uint256 convertedAmount = amount.div(TEN_DECIMALS);
    uint256 _oracleRelayerFee = msg.value;
    require(_oracleRelayerFee >= oracleRelayerFee, "the msg value should be no less than the minimum oracleRelayerFee");

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_UNDELEGATE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = convertedAmount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, _RLPEncode(EVENT_UNDELEGATE, msgBytes), _oracleRelayerFee.div(TEN_DECIMALS));
    payable(TOKEN_HUB_ADDR).transfer(_oracleRelayerFee);

    delegated[msg.sender] = delegated[msg.sender].sub(amount);
    pendingUndelegated[msg.sender][validator] = amount;

    emit undelegateSubmitted(msg.sender, validator, amount, _oracleRelayerFee);
  }

  function redelegate(address validatorSrc, address validatorDst, uint256 amount) override external payable tenDecimalPrecision(amount) initParams {
    require(validatorSrc!=validatorDst, "invalid redelegation, source validator is the same as dest validator");
    require(pendingRedelegate[msg.sender][validatorSrc][validatorDst] == 0 ||
      block.timestamp >= pendingRedelegate[msg.sender][validatorSrc][validatorDst],
      "conflicting redelegation from this source validator to this dest validator already exists, you must wait for it to finish");
    require(amount >= minDelegationChange, "the amount must not be less than minDelegationChange");
    delegatedOfValidator[msg.sender][validatorSrc] = delegatedOfValidator[msg.sender][validatorSrc].sub(amount, "not enough funds to redelegate");
    delegatedOfValidator[msg.sender][validatorDst] = delegatedOfValidator[msg.sender][validatorDst].add(amount);
    pendingRedelegate[msg.sender][validatorSrc][validatorDst] = block.timestamp.add(7*24*3600);

    // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
    uint256 convertedAmount = amount.div(TEN_DECIMALS);
    uint256 _oracleRelayerFee = msg.value;
    require(_oracleRelayerFee >= oracleRelayerFee, "the msg value should be no less than the minimum oracleRelayerFee");

    bytes[] memory elements = new bytes[](5);
    elements[0] = EVENT_REDELEGATE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validatorSrc.encodeAddress();
    elements[3] = validatorDst.encodeAddress();
    elements[4] = convertedAmount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, _RLPEncode(EVENT_REDELEGATE, msgBytes), _oracleRelayerFee.div(TEN_DECIMALS));
    payable(TOKEN_HUB_ADDR).transfer(_oracleRelayerFee);

    emit redelegateSubmitted(msg.sender, validatorSrc, validatorDst, amount, _oracleRelayerFee);
  }

  function claimReward() override external noReentrant returns(uint256 amount) {
    require(distributedReward[msg.sender] > 0, "no pending reward");

    amount = distributedReward[msg.sender];
    distributedReward[msg.sender] = 0;
    payable(msg.sender).transfer(amount);
    emit rewardClaimed(msg.sender, amount);
  }

  function claimUndeldegated() override external noReentrant returns(uint256 amount) {
    require(undelegated[msg.sender] > 0, "no undelegated funds");

    amount = undelegated[msg.sender];
    undelegated[msg.sender] = 0;
    payable(msg.sender).transfer(amount);
    emit undelegatedClaimed(msg.sender, amount);
  }

  function getDelegated(address delegator, address validator) override external view returns(uint256) {
    return delegatedOfValidator[delegator][validator];
  }

  function getDistributedReward(address delegator) override external view returns(uint256) {
    return distributedReward[delegator];
  }

  function getUndelegated(address delegator) override external view returns(uint256) {
    return undelegated[delegator];
  }

  function getPendingUndelegated(address delegator, address validator) override external view returns(uint256) {
    return pendingUndelegated[delegator][validator];
  }

  function getOracleRelayerFee() override external view returns(uint256) {
    return oracleRelayerFee;
  }

  function getMinDelegationChange() override external view returns(uint256) {
    return minDelegationChange;
  }

  /***************************** Internal functions *****************************/
  function _RLPEncode(uint8 eventType, bytes memory msgBytes) internal pure returns(bytes memory out) {
    bytes[] memory elements = new bytes[](2);
    elements[0] = eventType.encodeUint();
    elements[1] = msgBytes.encodeBytes();
    out = elements.encodeList();
  }

  /******************************** Param update ********************************/
  function updateParam(string calldata key, bytes calldata value) override external onlyInit onlyGov {
    if (Memory.compareStrings(key, "oracleRelayerFee")) {
      require(value.length == 32, "length of oracleRelayerFee mismatch");
      uint256 newOracleRelayerFee = BytesToTypes.bytesToUint256(32, value);
      require(newOracleRelayerFee >0, "the oracleRelayerFee must be greater than 0");
      oracleRelayerFee = newOracleRelayerFee;
    } else if (Memory.compareStrings(key, "minDelegationChange")) {
      require(value.length == 32, "length of minDelegationChange mismatch");
      uint256 newMinDelegationChange = BytesToTypes.bytesToUint256(32, value);
      require(newMinDelegationChange > 0, "the minDelegationChange must be greater than 0");
      minDelegationChange = newMinDelegationChange;
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }

  /************************* Handle cross-chain package *************************/
  function _handleDelegateAckPackage(RLPDecode.Iterator memory iter) internal {
    DelegateAckPackage memory pack;

    bool success = false;
    uint256 idx = 0;
    while (iter.hasNext()) {
      if (idx == 0) {
        pack.delegator = address(uint160(iter.next().toAddress()));
      } else if (idx == 1) {
        pack.validator = address(uint160(iter.next().toAddress()));
      } else if (idx == 2) {
        pack.amount = uint256(iter.next().toUint());
      } else if (idx == 3) {
        pack.errCode = uint8(iter.next().toUint());
        success = true;
      } else {
        break;
      }
      idx++;
    }
    require(success, "rlp decode ack package failed");

    require(ITokenHub(TOKEN_HUB_ADDR).withdrawStakingBNB(pack.amount), "withdraw funds from tokenhub failed");

    delegated[pack.delegator] = delegated[pack.delegator].sub(pack.amount);
    undelegated[pack.delegator] = undelegated[pack.delegator].add(pack.amount);
    delegatedOfValidator[pack.delegator][pack.validator] = delegatedOfValidator[pack.delegator][pack.validator].sub(pack.amount);

    emit failedDelegate(pack.delegator, pack.validator, pack.amount, pack.errCode);
  }

  function _handleUndelegateAckPackage(RLPDecode.Iterator memory iter) internal {
    UndelegateAckPackage memory pack;

    bool success = false;
    uint256 idx = 0;
    while (iter.hasNext()) {
      if (idx == 0) {
        pack.delegator = address(uint160(iter.next().toAddress()));
      } else if (idx == 1) {
        pack.validator = address(uint160(iter.next().toAddress()));
      } else if (idx == 2) {
        pack.amount = uint256(iter.next().toUint());
      } else if (idx == 3) {
        pack.errCode = uint8(iter.next().toUint());
        success = true;
      } else {
        break;
      }
      idx++;
    }
    require(success, "rlp decode ack package failed");

    delegated[pack.delegator] = delegated[pack.delegator].add(pack.amount);
    pendingUndelegated[pack.delegator][pack.validator] = 0;

    emit failedUndelegate(pack.delegator, pack.validator, pack.amount, pack.errCode);
  }

  function _handleRedelegateAckPackage(RLPDecode.Iterator memory iter) internal {
    RedelegateAckPackage memory pack;

    bool success = false;
    uint256 idx = 0;
    while (iter.hasNext()) {
      if (idx == 0) {
        pack.delegator = address(uint160(iter.next().toAddress()));
      } else if (idx == 1) {
        pack.valSrc = address(uint160(iter.next().toAddress()));
      } else if (idx == 2) {
        pack.valDst = address(uint160(iter.next().toAddress()));
      } else if (idx == 3) {
        pack.amount = uint256(iter.next().toUint());
      } else if (idx == 4) {
        pack.errCode = uint8(iter.next().toUint());
        success = true;
      } else {
        break;
      }
      idx++;
    }
    require(success, "rlp decode ack package failed");

    delegatedOfValidator[pack.delegator][pack.valSrc] = delegatedOfValidator[pack.delegator][pack.valSrc].add(pack.amount);
    delegatedOfValidator[pack.delegator][pack.valDst] = delegatedOfValidator[pack.delegator][pack.valDst].sub(pack.amount);
    pendingRedelegate[pack.delegator][pack.valSrc][pack.valDst] = 0;

    emit failedRedelegate(pack.delegator, pack.valSrc, pack.valDst, pack.amount, pack.errCode);
  }

  function _handleDistributeRewardSynPackage(RLPDecode.Iterator memory iter) internal returns(uint32) {
    DistributeRewardSynPackage memory pack;

    bool success = false;
    uint256 idx = 0;
    while (iter.hasNext()) {
      if (idx == 0) {
        pack.amount = uint256(iter.next().toUint());
      } else if (idx == 1) {
        pack.recipient = address(uint160(iter.next().toAddress()));
        success = true;
      } else {
        break;
      }
      idx++;
    }
    if (!success) {
      return ERROR_FAIL_DECODE;
    }

    bool ok = ITokenHub(TOKEN_HUB_ADDR).withdrawStakingBNB(pack.amount);
    if (!ok) {
      return ERROR_WITHDRAW_BNB;
    }

    distributedReward[pack.recipient] = distributedReward[pack.recipient].add(pack.amount);
    emit rewardReceived(pack.recipient, pack.amount);

    return CODE_OK;
  }

  function _handleDistributeUndelegatedSynPackage(RLPDecode.Iterator memory iter) internal returns(uint32) {
    DistributeUndelegatedSynPackage memory pack;

    bool success = false;
    uint256 idx = 0;
    while (iter.hasNext()) {
      if (idx == 0) {
        pack.amount = uint256(iter.next().toUint());
      } else if (idx == 1) {
        pack.recipient = address(uint160(iter.next().toAddress()));
      } else if (idx == 2) {
        pack.validator = address(uint160(iter.next().toAddress()));
        success = true;
      } else {
        break;
      }
      idx++;
    }
    if (!success) {
      return ERROR_FAIL_DECODE;
    }

    bool ok = ITokenHub(TOKEN_HUB_ADDR).withdrawStakingBNB(pack.amount);
    if (!ok) {
      return ERROR_WITHDRAW_BNB;
    }

    pendingUndelegated[pack.recipient][pack.validator] = 0;
    undelegated[pack.recipient] = undelegated[pack.recipient].add(pack.amount);

    emit undelegatedReceived(pack.recipient, pack.amount);
    return CODE_OK;
  }
}
