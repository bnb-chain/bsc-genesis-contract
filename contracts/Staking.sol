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

contract CrossStake is IStaking, System, IParamSubscriber, IApplication {
  using SafeMath for uint256;
  using RLPEncode for *;
  using RLPDecode for *;

  // Cross-Chain Stake Event type
  uint8 public constant EVENT_DELEGATE = 0x01;
  uint8 public constant EVENT_UNDELEGATE = 0x02;
  uint8 public constant EVENT_REDELEGATE = 0x03;
  uint8 public constant EVENT_CLAIM_REWARD = 0x04;
  uint8 public constant EVENT_CLAIM_UNDELEGATED = 0x05;

  uint256 constant public TEN_DECIMALS = 1e10;

  uint256 public constant INIT_ORACLE_RELAYER_FEE = 2e15; //TODO
  uint256 public constant INIT_MIN_DELEGATION_CHANGE = 1e19;
  uint256 public constant INIT_CALLBACK_GAS_LIMIT = 23000;

  uint256 public oracleRelayerFee;
  uint256 public minDelegationChange;
  uint256 public callbackGasLimit;

  mapping(address => uint256) stakingRecord;
  mapping(address => mapping(address => uint256)) stakingValidatorsMap;
  mapping(address => uint256) pendingReward;
  mapping(address => uint256) lockedUndelegated;
  mapping(address => uint256) pendingUndelegated;

  bool internal locked;

  modifier noReentrant() {
    require(!locked, "No re-entrancy");
    locked = true;
    _;
    locked = false;
  }

  modifier tenDecimalPrecision() {
    require(msg.value%TEN_DECIMALS==0,
      "invalid received BNB amount: precision loss in amount conversion");
    _;
  }

  modifier initParams() {
    if (oracleRelayerFee == 0 || minDelegationChange == 0 || callbackGasLimit == 0) {
      oracleRelayerFee = INIT_ORACLE_RELAYER_FEE;
      minDelegationChange = INIT_MIN_DELEGATION_CHANGE;
      callbackGasLimit = INIT_CALLBACK_GAS_LIMIT;
    }
    _;
  }

  /*********************** events **************************/
  event delegateSubmitted(address indexed delAddr, address indexed validator, uint256 amount, uint256 oracleRelayerFee);
  event undelegateSubmitted(address indexed delAddr, address indexed validator, uint256 amount, uint256 oracleRelayerFee);
  event redelegateSubmitted(address indexed delAddr, address indexed validatorSrc, address indexed validatorDst, uint256 amount, uint256 oracleRelayerFee);
  event rewardClaimed(address indexed delegator, uint256 amount);
  event undelegatedClaimed(address indexed delegator, uint256 amount);
  event failedDelegate(address indexed delAddr, address indexed validator, uint256 amount, string err);
  event failedUndelegate(address indexed delAddr, address indexed validator, uint256 amount, string err);
  event failedRedelegate(address indexed delAddr, address indexed valSrc, address indexed valDst, uint256 amount, string err);
  event paramChange(string key, bytes value);
  event crashResponse();

  /*********************** Implement cross chain app ********************************/
  function handleSynPackage(uint8, bytes calldata) external onlyCrossChainContract onlyInit override returns(bytes memory) {
    require(false, "receive unexpected syn package");
  }

  function handleAckPackage(uint8, bytes calldata msgBytes) external onlyCrossChainContract onlyInit override {
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

  function handleFailAckPackage(uint8, bytes calldata msgBytes) external onlyCrossChainContract onlyInit override {
    emit crashResponse();
    return;
  }

  /*********************** External Functions **************************/
  function delegate(address validator, uint256 amount) override external payable tenDecimalPrecision initParams {
    require(amount >= minDelegationChange, "delegate amount is too small");
    require(msg.value >= amount.add(oracleRelayerFee), "received BNB amount should be no less than the sum of stake amount and minimum oracleRelayerFee");
    // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
    require(amount%TEN_DECIMALS==0, "invalid delegate amount: precision loss in amount conversion");
    uint256 convertedAmount = amount.div(TEN_DECIMALS);
    uint256 _oracleRelayerFee = (msg.value).sub(amount);

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_DELEGATE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = convertedAmount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee.div(TEN_DECIMALS));
    payable(TOKEN_HUB_ADDR).transfer(msg.value);

    stakingRecord[msg.sender] = stakingRecord[msg.sender].add(amount);
    stakingValidatorsMap[msg.sender][validator] = stakingValidatorsMap[msg.sender][validator].add(amount);

    emit delegateSubmitted(msg.sender, validator, amount, _oracleRelayerFee);
  }

  function undelegate(address validator, uint256 amount) override external payable tenDecimalPrecision initParams {
    stakingValidatorsMap[msg.sender][validator] = stakingValidatorsMap[msg.sender][validator].sub(amount, "not enough funds to undelegate");
    amount = amount != 0 ? amount : stakingValidatorsMap[msg.sender][validator];
    if (amount < minDelegationChange) {
      if (amount != stakingValidatorsMap[msg.sender][validator]) {
        require(false, "the amount must not be less than minDelegationChange, or the amount is all the remaining delegation");
      }
    }
    // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
    require(amount%TEN_DECIMALS==0, "invalid undelegate amount: precision loss in amount conversion");
    uint256 convertedAmount = amount.div(TEN_DECIMALS);
    uint256 _oracleRelayerFee = msg.value;
    require(_oracleRelayerFee >= oracleRelayerFee, "received BNB amount should be no less than the minimum oracleRelayerFee");

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_UNDELEGATE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = convertedAmount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee.div(TEN_DECIMALS));
    payable(TOKEN_HUB_ADDR).transfer(_oracleRelayerFee);

    stakingRecord[msg.sender] = stakingRecord[msg.sender].sub(amount);
    lockedUndelegated[msg.sender] = lockedUndelegated[msg.sender].add(amount);

    emit undelegateSubmitted(msg.sender, validator, amount, _oracleRelayerFee);
  }

  function redelegate(address validatorSrc, address validatorDst, uint256 amount) override external payable tenDecimalPrecision initParams {
    stakingValidatorsMap[msg.sender][validatorSrc] = stakingValidatorsMap[msg.sender][validatorSrc].sub(amount, "not enough funds to redelegate");
    amount = amount != 0 ? amount : stakingValidatorsMap[msg.sender][validatorSrc];
    if (amount < minDelegationChange) {
      if (amount != stakingValidatorsMap[msg.sender][validator]) {
        require(false, "the amount must not be less than minDelegationChange, or the amount is all the remaining delegation");
      }
    }
    // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
    require(amount%TEN_DECIMALS==0, "invalid redelegate amount: precision loss in amount conversion");
    uint256 convertedAmount = amount.div(TEN_DECIMALS);
    uint256 _oracleRelayerFee = msg.value;
    require(_oracleRelayerFee >= oracleRelayerFee, "received BNB amount should be no less than the minimum oracleRelayerFee");

    bytes[] memory elements = new bytes[](5);
    elements[0] = EVENT_REDELEGATE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validatorSrc.encodeAddress();
    elements[3] = validatorDst.encodeAddress();
    elements[4] = convertedAmount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee.div(TEN_DECIMALS));
    payable(TOKEN_HUB_ADDR).transfer(_oracleRelayerFee);

    stakingValidatorsMap[msg.sender][validatorDst] = stakingValidatorsMap[msg.sender][validatorDst].add(amount);

    emit redelegateSubmitted(msg.sender, validatorSrc, validatorDst, amount, _oracleRelayerFee);
  }

  function claimReward() override external noReentrant returns(uint256 amount) {
    require(pendingReward[msg.sender] > 0, "no pending reward");

    amount = pendingReward[msg.sender];
    payable(msg.sender).transfer(amount);
    pendingReward[msg.sender] = 0;
    emit rewardClaimed(msg.sender, amount);
  }

  function claimUndeldegated() override external noReentrant returns(uint256 amount) {
    require(pendingUndelegated[msg.sender] > 0, "no pending reward");

    amount = pendingUndelegated[msg.sender];
    payable(msg.sender).transfer(amount);
    pendingUndelegated[msg.sender] = 0;
    emit undelegatedClaimed(msg.sender, amount);
  }

  function getDelegated(address delegator, address validator) override external view returns(uint256) {
    return stakingValidatorsMap[delegator][validator];
  }

  function getPendingReward(address delegator) override external view returns(uint256) {
    return pendingReward[delegator];
  }

  function getPendingUndelegated(address delegator) override external view returns(uint256) {
    return pendingUndelegated[delegator];
  }

  function getLockedUndelegated(address delegator) override external view returns(uint256) {
    return lockedUndelegated[delegator];
  }

  function getOracleRelayerFee() override external view returns(uint256) {
    return oracleRelayerFee;
  }

  /*********************** Param update ********************************/
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
    } else if (Memory.compareStrings(key, "callbackGasLimit")) {
      require(value.length == 32, "length of callbackGasLimit mismatch");
      uint256 newCallbackGasLimit = BytesToTypes.bytesToUint256(32, value);
      require(newCallbackGasLimit > 0, "the callbackGasLimit must be greater than 0");
      callbackGasLimit = newCallbackGasLimit;
    } else {
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }

  /*********************** Handle ack package ********************************/
  function _handleDelegateAckPackage(RLPDecode.Iterator memory iter) internal {
    bool success = false;
    uint256 idx = 0;
    address delegator;
    address validator;
    uint256 amount;
    string memory err;
    while (iter.hasNext()) {
      if (idx == 0) {
        continue;
      } else if (idx == 1) {
        delegator = address(uint160(iter.next().toAddress()));
      } else if (idx == 2) {
        validator = address(uint160(iter.next().toAddress()));
      } else if (idx == 3) {
        amount = uint256(iter.next().toUint());
      } else if (idx == 4) {
        err = string(iter.next().toBytes());
        success = true;
      } else {
        break;
      }
      idx++;
    }
    if (!success) {
      require(false, "rlp decode ack package failed");
    }
    require(ITokenHub(TOKEN_HUB_ADDR).withdrawStakingBNB(amount), "withdraw funds from tokenhub failed");
    delegator.call{value: amount, gas: callbackGasLimit}("");

    stakingRecord[delegator] = stakingRecord[delegator].sub(amount);
    stakingValidatorsMap[msg.sender][validator] = stakingValidatorsMap[msg.sender][validator].sub(amount);

  emit failedDelegate(delegator, validator, amount, err);
  }

  function _handleUndelegateAckPackage(RLPDecode.Iterator memory iter) internal {
    bool success = false;
    uint256 idx = 0;
    address delegator;
    address validator;
    uint256 amount;
    string memory err;
    while (iter.hasNext()) {
      if (idx == 0) {
        continue;
      } else if (idx == 1) {
        delegator = address(uint160(iter.next().toAddress()));
      } else if (idx == 2) {
        validator = address(uint160(iter.next().toAddress()));
      } else if (idx == 3) {
        amount = uint256(iter.next().toUint());
      } else if (idx == 4) {
        err = string(iter.next().toBytes());
        success = true;
      } else {
        break;
      }
      idx++;
    }
    if (!success) {
      require(false, "rlp decode ack package failed");
    }

    stakingRecord[delegator] = stakingRecord[delegator].add(amount);
    lockedUndelegated[msg.sender] = lockedUndelegated[msg.sender].sub(amount);

    emit failedUndelegate(delegator, validator, amount, err);
  }

  function _handleRedelegateAckPackage(RLPDecode.Iterator memory iter) internal {
    bool success = false;
    uint256 idx=0;
    address delegator;
    address valSrc;
    address valDst;
    uint256 amount;
    string memory err;
    while (iter.hasNext()) {
      if (idx == 0) {
        continue;
      } else if (idx == 1) {
        delegator = address(uint160(iter.next().toAddress()));
      } else if (idx == 2) {
        valSrc = address(uint160(iter.next().toAddress()));
      } else if (idx == 3) {
        valDst = address(uint160(iter.next().toAddress()));
      } else if (idx == 4) {
        amount = uint256(iter.next().toUint());
      } else if (idx == 5) {
        err = string(iter.next().toBytes());
        success = true;
      } else {
        break;
      }
      idx++;
    }
    if (!success) {
      require(false, "rlp decode ack package failed");
    }

    stakingValidatorsMap[msg.sender][valSrc] = stakingValidatorsMap[msg.sender][valSrc].add(amount);
    stakingValidatorsMap[msg.sender][valDst] = stakingValidatorsMap[msg.sender][valDst].sub(amount);

  emit failedRedelegate(delegator, valSrc, valDst, amount, err);
  }
}
