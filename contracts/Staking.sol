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

contract CrossStake is System, IParamSubscriber, IApplication {
  using SafeMath for uint256;
  using RLPEncode for *;

  // Cross-Chain Stake Event type
  uint8 public constant EVENT_DELEGATE = 0x01;
  uint8 public constant EVENT_UNDELEGATE = 0x02;
  uint8 public constant EVENT_CLAIM_REWARD = 0x03;
  uint8 public constant EVENT_CLAIM_UNDELEGATED = 0x04;
  uint8 public constant EVENT_REINVEST = 0x05;
  uint8 public constant EVENT_REDELEGATE = 0x06;

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
  event delegateSuccess(address indexed delAddr, address indexed validator, uint256 amount, uint256 oracleRelayerFee);
  event undelegateSuccess(address indexed delAddr, address indexed validator, uint256 amount, uint256 oracleRelayerFee);
  event claimRewardSuccess(address indexed receiver, uint256 oracleRelayerFee, uint256 BSCRelayerFee);
  event claimUndelegatedSuccess(address indexed receiver, uint256 oracleRelayerFee, uint256 BSCRelayerFee);
  event reinvestSuccess(address indexed delAddr, address indexed validator, uint256 amount, uint256 oracleRelayerFee);
  event redelegateSuccess(address indexed delAddr, address indexed validatorSrc, address indexed validatorDst, uint256 amount, uint256 oracleRelayerFee);
  event paramChange(string key, bytes value);

  /*********************** Implement cross chain app ********************************/
  function handleSynPackage(uint8, bytes calldata) external onlyCrossChainContract onlyInit override returns(bytes memory) {
    //TODO
    return new bytes(0);
  }

  function handleAckPackage(uint8, bytes calldata msgBytes) external onlyCrossChainContract onlyInit override {
    //TODO
  }

  function handleFailAckPackage(uint8, bytes calldata) external onlyCrossChainContract onlyInit override {
    //TODO
  }

  function delegate(address validator, uint256 amount) external payable initRelayerFee {
    require(msg.value >= amount.add(oracleRelayerFee), "received BNB amount should be no less than the sum of stake amount and minimum oracleRelayerFee");
    uint256 _oracleRelayerFee = (msg.value).sub(amount);
    require(amount%TEN_DECIMALS==0, "invalid stake amount: precision loss in amount conversion");
    convertedAmount = amount.div(TEN_DECIMALS); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_DELEGATE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = convertedAmount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee);
    address(TOKEN_HUB_ADDR).transfer(msg.value);
    emit delegateSuccess(msg.sender, validator, amount, _oracleRelayerFee);
  }

  function undelegate(address validator, uint256 amount) external payable initRelayerFee {
    uint256 _oracleRelayerFee = msg.value;
    require(_oracleRelayerFee >= oracleRelayerFee, "received BNB amount should be no less than the minimum oracleRelayerFee");

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_UNDELEGATE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = amount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee);
    address(TOKEN_HUB_ADDR).transfer(msg.value);
    emit undelegateSuccess(msg.sender, validator, amount, _oracleRelayerFee);
  }

  function claimReward(address receiver, uint256 _oracleRelayerFee) external payable initRelayerFee noReentrant {
    uint256 _bSCRelayerFee = (msg.value).sub(_oracleRelayerFee);
    require(_bSCRelayerFee >= BSCRelayerFee && _oracleRelayerFee >= oracleRelayerFee,
      "received BNB amount should be no less than the sum of the minimum BSCRelayerFee and the minimum oracleRelayerFee");

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_CLAIM_REWARD.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = receiver.encodeAddress();
    elements[3] = _bSCRelayerFee.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee);
    address(TOKEN_HUB_ADDR).transfer(msg.value);
    emit claimRewardSuccess(receiver, _oracleRelayerFee, _bSCRelayerFee);
  }

  function claimUndeldegated(address receiver, uint256 _oracleRelayerFee) external payable initRelayerFee noReentrant {
    uint256 _bSCRelayerFee = (msg.value).sub(_oracleRelayerFee);
    require(_bSCRelayerFee >= BSCRelayerFee && _oracleRelayerFee >= oracleRelayerFee,
      "received BNB amount should be no less than the sum of the minimum BSCRelayerFee and the minimum oracleRelayerFee");

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_CLAIM_UNDELEGATED.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = receiver.encodeAddress();
    elements[3] = _bSCRelayerFee.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee);
    address(TOKEN_HUB_ADDR).transfer(msg.value);
    emit claimUndelegatedSuccess(receiver, _oracleRelayerFee, _bSCRelayerFee);
  }

  function reinvest(address validator, uint256 amount) external payable initRelayerFee {
    uint256 _oracleRelayerFee = msg.value;
    require(_oracleRelayerFee >= oracleRelayerFee, "received BNB amount should be no less than the minimum oracleRelayerFee");

    bytes[] memory elements = new bytes[](4);
    elements[0] = EVENT_REINVEST.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validator.encodeAddress();
    elements[3] = amount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee);
    address(TOKEN_HUB_ADDR).transfer(msg.value);
    emit reinvestSuccess(msg.sender, validator, amount, _oracleRelayerFee);
  }

  function redelegate(address validatorSrc, address validatorDst, uint256 amount) external payable initRelayerFee {
    uint256 _oracleRelayerFee = msg.value;
    require(_oracleRelayerFee >= oracleRelayerFee, "received BNB amount should be no less than the minimum oracleRelayerFee");

    bytes[] memory elements = new bytes[](5);
    elements[0] = EVENT_REDELEGATE.encodeUint();
    elements[1] = msg.sender.encodeAddress();
    elements[2] = validatorSrc.encodeAddress();
    elements[3] = validatorDst.encodeAddress();
    elements[4] = amount.encodeUint();
    bytes memory msgBytes = elements.encodeList();
    ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).sendSynPackage(CROSS_STAKE_CHANNELID, msgBytes, _oracleRelayerFee);
    address(TOKEN_HUB_ADDR).transfer(msg.value);
    emit redelegateSuccess(msg.sender, validatorSrc, validatorDst, amount, _oracleRelayerFee);
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
