pragma solidity ^0.8.10;

import "../lib/Deployer.sol";

contract StakingTest is Deployer {
  using RLPEncode for *;

  event delegateSubmitted(address indexed delegator, address indexed validator, uint256 amount, uint256 oracleRelayerFee);
  event undelegateSubmitted(address indexed delegator, address indexed validator, uint256 amount, uint256 oracleRelayerFee);
  event redelegateSubmitted(address indexed delegator, address indexed validatorSrc, address indexed validatorDst, uint256 amount, uint256 oracleRelayerFee);
  event rewardReceived(address indexed delegator, uint256 amount);
  event rewardClaimed(address indexed delegator, uint256 amount);
  event undelegatedReceived(address indexed delegator, address indexed validator, uint256 amount);
  event undelegatedClaimed(address indexed delegator, uint256 amount);
  event delegateSuccess(address indexed delegator, address indexed validator, uint256 amount);
  event undelegateSuccess(address indexed delegator, address indexed validator, uint256 amount);
  event redelegateSuccess(address indexed delegator, address indexed valSrc, address indexed valDst, uint256 amount);
  event delegateFailed(address indexed delegator, address indexed validator, uint256 amount, uint8 errCode);
  event undelegateFailed(address indexed delegator, address indexed validator, uint256 amount, uint8 errCode);
  event redelegateFailed(address indexed delegator, address indexed valSrc, address indexed valDst, uint256 amount, uint8 errCode);
  event crashResponse(uint8 indexed eventCode);
  event paramChange(string key, bytes valueBytes);

  uint8 public constant EVENT_DELEGATE = 0x01;
  uint8 public constant EVENT_UNDELEGATE = 0x02;
  uint8 public constant EVENT_REDELEGATE = 0x03;
  uint8 public constant EVENT_DISTRIBUTE_REWARD = 0x04;
  uint8 public constant EVENT_DISTRIBUTE_UNDELEGATED = 0x05;

  uint256 public relayFee;
  uint256 public bSCRelayFee;
  uint256 public minDelegation;
  uint256 public decimal;

  receive() external payable {}

  function setUp() public {
    bytes memory stakingCode = vm.getDeployedCode("Staking.sol");
    vm.etch(STAKING_CONTRACT_ADDR, stakingCode);
    staking = Staking(STAKING_CONTRACT_ADDR);
    vm.label(address(staking), "Staking");

    bytes memory tokenHubCode = vm.getDeployedCode("TokenHub.sol");
    vm.etch(address(tokenHub), tokenHubCode);

    bytes memory key = "addOrUpdateChannel";
    bytes memory value = abi.encodePacked(CROSS_STAKE_CHANNELID, uint8(1), address(staking));
    updateParamByGovHub(key, value, address(crossChain));

    // to init the staking contract
    staking.delegate{value: 101 ether}(addrSet[addrIdx], 100 ether);
    relayFee = staking.getRelayerFee();
    bSCRelayFee = staking.bSCRelayerFee();
    minDelegation = staking.getMinDelegation();
    decimal = staking.TEN_DECIMALS();

    bytes[] memory elements = new bytes[](3);
    elements[0] = address(this).encodeAddress();
    elements[1] = addrSet[addrIdx++].encodeAddress();
    elements[2] = (1e20 / decimal).encodeUint();
    bytes memory ackPack = _genAckPack(uint8(1), uint8(0), _RLPEncode(EVENT_DELEGATE, elements.encodeList()));
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);
  }

  function testGov1(uint256 value) public {
    vm.assume(value > relayFee);

    bytes memory key = "minDelegation";
    bytes memory valueBytes = abi.encode(value);
    vm.expectEmit(false, false, false, true, address(staking));
    emit paramChange(string(key), valueBytes);
    updateParamByGovHub(key, valueBytes, address(staking));
    assertEq(value, staking.minDelegation());
  }

  function testGov2(uint32 value) public {
    vm.assume(uint256(value) * decimal > bSCRelayFee);

    bytes memory key = "relayerFee";
    bytes memory valueBytes = abi.encode(uint256(value) * decimal);
    vm.expectEmit(false, false, false, true, address(staking));
    emit paramChange(string(key), valueBytes);
    updateParamByGovHub(key, valueBytes, address(staking));
    assertEq(uint256(value) * decimal, staking.relayerFee());
  }

  function testGov3(uint32 value) public {
    vm.assume(value > 0);
    vm.assume(uint256(value) * decimal < relayFee);

    bytes memory key = "bSCRelayerFee";
    bytes memory valueBytes = abi.encode(uint256(value) * decimal);
    vm.expectEmit(false, false, false, true, address(staking));
    emit paramChange(string(key), valueBytes);
    updateParamByGovHub(key, valueBytes, address(staking));
    assertEq(uint256(value) * decimal, staking.bSCRelayerFee());
  }

  function testDelegate(uint16 amount) public {
    vm.assume(amount > 0);
    uint256 bigAmount = uint256(amount) * minDelegation;
    bytes[] memory elements = new bytes[](3);
    elements[0] = address(this).encodeAddress();
    elements[1] = addrSet[0].encodeAddress();
    elements[2] = (bigAmount / decimal).encodeUint();

    uint256 sendValue = minDelegation + relayFee + 1;
    vm.expectRevert(bytes("precision loss in conversion"));
    staking.delegate{value: sendValue}(addrSet[0], minDelegation);

    sendValue = minDelegation + relayFee;
    vm.expectRevert(bytes("precision loss in conversion"));
    staking.delegate{value: sendValue}(addrSet[0], minDelegation + 1);

    vm.expectRevert(bytes("invalid delegate amount"));
    staking.delegate{value: sendValue}(addrSet[0], 1e18);

    sendValue = minDelegation;
    vm.expectRevert(bytes("not enough msg value"));
    staking.delegate{value: sendValue}(addrSet[0], minDelegation);

    sendValue = minDelegation + relayFee / 2;
    vm.expectRevert(bytes("not enough msg value"));
    staking.delegate{value: sendValue}(addrSet[0], minDelegation);

    sendValue = bigAmount + relayFee;
    vm.expectEmit(true, true, false, true, address(staking));
    emit delegateSubmitted(address(this), addrSet[0], bigAmount, relayFee - bSCRelayFee);
    staking.delegate{value: sendValue}(addrSet[0], bigAmount);

    uint256 delegatedBefore = staking.getDelegated(address(this), addrSet[0]);
    bytes memory ackPack = _genAckPack(uint8(1), uint8(0), _RLPEncode(EVENT_DELEGATE, elements.encodeList()));
    vm.expectEmit(true, true, false, true, address(staking));
    emit delegateSuccess(address(this), addrSet[0], bigAmount);
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);
    assertEq(bigAmount + delegatedBefore, staking.getDelegated(address(this), addrSet[0]));
  }

  function testUndelegate(uint16 amount) public {
    vm.assume(amount > 0);
    address validator = addrSet[addrIdx++];
    uint256 bigAmount = uint256(amount) * minDelegation;
    uint256 sendValue = relayFee + bigAmount + 2 * minDelegation + bSCRelayFee / 10;
    staking.delegate{value: sendValue}(validator, bigAmount + 2 * minDelegation + bSCRelayFee / 10);

    bytes[] memory elements = new bytes[](3);
    elements[0] = address(this).encodeAddress();
    elements[1] = validator.encodeAddress();
    elements[2] = ((bigAmount + 2 * minDelegation + bSCRelayFee / 10) / decimal).encodeUint();
    bytes memory ackPack = _genAckPack(uint8(1), uint8(0), _RLPEncode(EVENT_DELEGATE, elements.encodeList()));
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);

    vm.expectRevert(bytes("precision loss in conversion"));
    staking.undelegate{value: relayFee}(validator, bigAmount + 1);

    vm.expectRevert(bytes("precision loss in conversion"));
    staking.undelegate{value: relayFee + 1}(validator, bigAmount);

    vm.expectRevert(bytes("invalid amount"));
    staking.undelegate{value: relayFee}(validator, minDelegation / 10);

    vm.expectRevert(bytes("not enough relay fee"));
    staking.undelegate{value: relayFee / 10}(validator, bigAmount);

    vm.expectRevert(bytes("not enough funds"));
    staking.undelegate{value: relayFee}(addrSet[addrIdx++], bigAmount);

    vm.expectEmit(true, true, false, true, address(staking));
    emit undelegateSubmitted(address(this), validator, bigAmount, relayFee - bSCRelayFee);
    staking.undelegate{value: relayFee}(validator, bigAmount);

    elements[2] = (bigAmount / decimal).encodeUint();
    ackPack = _genAckPack(uint8(1), uint8(0), _RLPEncode(EVENT_UNDELEGATE, elements.encodeList()));
    vm.expectEmit(true, true, false, true, address(staking));
    emit undelegateSuccess(address(this), validator, bigAmount);
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);

    vm.expectRevert(bytes("pending undelegation exist"));
    staking.undelegate{value: relayFee}(validator, minDelegation);

    skip(8 days);
    vm.expectRevert(bytes("insufficient balance after undelegate"));
    staking.undelegate{value: relayFee}(validator, 2 * minDelegation);

    vm.expectEmit(true, true, false, true, address(staking));
    emit undelegateSubmitted(address(this), validator, minDelegation, relayFee - bSCRelayFee);
    staking.undelegate{value: relayFee}(validator, minDelegation);
  }

  function testRedelegate(uint16 amount) public {
    vm.assume(amount > 0);

    address validator = addrSet[addrIdx++];
    uint256 bigAmount = uint256(amount) * minDelegation;
    uint256 sendValue = relayFee + bigAmount + 2 * minDelegation + bSCRelayFee / 10;
    staking.delegate{value: sendValue}(validator, bigAmount + 2 * minDelegation + bSCRelayFee / 10);

    bytes[] memory elements = new bytes[](3);
    elements[0] = address(this).encodeAddress();
    elements[1] = validator.encodeAddress();
    elements[2] = ((bigAmount + 2 * minDelegation + bSCRelayFee / 10) / decimal).encodeUint();
    bytes memory ackPack = _genAckPack(uint8(1), uint8(0), _RLPEncode(EVENT_DELEGATE, elements.encodeList()));
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);

    vm.expectRevert(bytes("precision loss in conversion"));
    staking.redelegate{value: relayFee}(validator, addrSet[addrIdx++], bigAmount + 1);

    vm.expectRevert(bytes("precision loss in conversion"));
    staking.redelegate{value: relayFee + 1}(validator, addrSet[addrIdx++], bigAmount);

    vm.expectRevert(bytes("invalid redelegation"));
    staking.redelegate{value: relayFee}(validator, validator, bigAmount);

    vm.expectRevert(bytes("invalid amount"));
    staking.redelegate{value: relayFee}(validator, addrSet[addrIdx++], minDelegation / 10);

    console2.log(staking.getDelegated(address(this), validator));
    vm.expectRevert(bytes("not enough funds"));
    staking.redelegate{value: relayFee}(addrSet[addrIdx++], validator, bigAmount);

    vm.expectRevert(bytes("not enough relay fee"));
    staking.redelegate{value: relayFee / 10}(validator, addrSet[addrIdx++], bigAmount);

    vm.expectEmit(true, true, false, true, address(staking));
    emit redelegateSubmitted(address(this), validator, addrSet[addrIdx], bigAmount, relayFee - bSCRelayFee);
    staking.redelegate{value: relayFee}(validator, addrSet[addrIdx], bigAmount);

    bytes[] memory elements1 = new bytes[](4);
    elements1[0] = address(this).encodeAddress();
    elements1[1] = validator.encodeAddress();
    elements1[2] = addrSet[addrIdx].encodeAddress();
    elements1[3] = (bigAmount / decimal).encodeUint();
    ackPack = _genAckPack(uint8(1), uint8(0), _RLPEncode(EVENT_REDELEGATE, elements1.encodeList()));
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);

    vm.expectRevert(bytes("pending redelegation exist"));
    staking.redelegate{value: relayFee}(validator, addrSet[addrIdx], bigAmount);

    skip(8 days);
    vm.expectRevert(bytes("insufficient balance after redelegate"));
    staking.redelegate{value: relayFee}(validator, addrSet[addrIdx], 2 * minDelegation);

    vm.expectEmit(true, true, false, true, address(staking));
    emit redelegateSubmitted(address(this), validator, addrSet[addrIdx], minDelegation, relayFee - bSCRelayFee);
    staking.redelegate{value: relayFee}(validator, addrSet[addrIdx], minDelegation);
  }

  function testHandleRewardSynPackage(uint256 reward) public {
    vm.assume(reward > 0);
    vm.assume(reward <= 1e18);

    uint256 sendValue = minDelegation + relayFee;
    staking.delegate{value: sendValue}(addrSet[0], minDelegation);

    bytes[] memory elements = new bytes[](3);
    elements[0] = EVENT_DISTRIBUTE_REWARD.encodeUint();
    elements[1] = address(this).encodeAddress();
    elements[2] = reward.encodeUint();

    vm.expectEmit(true, false, false, true, address(staking));
    emit rewardReceived(address(this), reward);
    vm.startPrank(address(crossChain));
    staking.handleSynPackage(CROSS_STAKE_CHANNELID, elements.encodeList());
    vm.stopPrank();
    assertEq(reward, staking.getDistributedReward(address(this)));

    vm.expectEmit(true, false, false, true, address(staking));
    emit rewardClaimed(address(this), reward);
    staking.claimReward();
    assertEq(0, staking.getDistributedReward(address(this)));
  }

  function testHandleUndelegatedSynPackage(uint16 amount) public {
    vm.assume(amount > 0);
    uint256 sendValue = amount * minDelegation + relayFee;
    staking.delegate{value: sendValue}(addrSet[0], amount * minDelegation);

    bytes[] memory elements = new bytes[](3);
    elements[0] = address(this).encodeAddress();
    elements[1] = addrSet[0].encodeAddress();
    elements[2] = (amount * minDelegation / decimal).encodeUint();
    bytes memory ackPack = _genAckPack(uint8(1), uint8(0), _RLPEncode(EVENT_DELEGATE, elements.encodeList()));
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);

    bytes[] memory elements1 = new bytes[](4);
    elements1[0] = EVENT_DISTRIBUTE_UNDELEGATED.encodeUint();
    elements1[1] = address(this).encodeAddress();
    elements1[2] = addrSet[0].encodeAddress();
    elements1[3] = (amount * minDelegation).encodeUint();

    vm.expectEmit(true, true, false, true, address(staking));
    emit undelegatedReceived(address(this), addrSet[0], amount * minDelegation);
    vm.startPrank(address(crossChain));
    staking.handleSynPackage(CROSS_STAKE_CHANNELID, elements1.encodeList());
    vm.stopPrank();
    assertEq(amount * minDelegation, staking.getUndelegated(address(this)));

    vm.expectEmit(true, false, false, true, address(staking));
    emit undelegatedClaimed(address(this), amount * minDelegation);
    staking.claimUndelegated();
    assertEq(0, staking.getUndelegated(address(this)));
  }

  function testHandleDelegateAckPackage() public {
    //    vm.assume(amount > 0);
    uint16 amount = 5;
    uint256 sendValue = amount * minDelegation + relayFee;
    staking.delegate{value: sendValue}(addrSet[0], amount * minDelegation);

    bytes[] memory elements = new bytes[](3);
    elements[0] = address(this).encodeAddress();
    elements[1] = addrSet[0].encodeAddress();
    elements[2] = (amount * minDelegation / decimal).encodeUint();

    bytes memory ackPack = _genAckPack(uint8(0), uint8(1), _RLPEncode(EVENT_DELEGATE, elements.encodeList()));
    vm.expectEmit(true, true, false, true, address(staking));
    emit delegateFailed(address(this), addrSet[0], amount * minDelegation, uint8(1));
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);
  }

  function testHandleUndelegateAckPackage(uint16 amount) public {
    vm.assume(amount > 0);
    uint256 sendValue = amount * minDelegation + relayFee;
    staking.delegate{value: sendValue}(addrSet[0], amount * minDelegation);
    bytes[] memory elements = new bytes[](3);
    elements[0] = address(this).encodeAddress();
    elements[1] = addrSet[0].encodeAddress();
    elements[2] = (amount * minDelegation / decimal).encodeUint();
    bytes memory ackPack = _genAckPack(uint8(1), uint8(0), _RLPEncode(EVENT_DELEGATE, elements.encodeList()));
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);
    staking.undelegate{value: relayFee}(addrSet[0], amount * minDelegation);

    ackPack = _genAckPack(uint8(0), uint8(1), _RLPEncode(EVENT_UNDELEGATE, elements.encodeList()));
    vm.expectEmit(true, true, false, true, address(staking));
    emit undelegateFailed(address(this), addrSet[0], amount * minDelegation, uint8(1));
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);
  }

  function testHandleRedelegateAckPackage(uint16 amount) public {
    vm.assume(amount > 0);
    uint256 sendValue = amount * minDelegation + relayFee;
    staking.delegate{value: sendValue}(addrSet[0], amount * minDelegation);
    bytes[] memory elements = new bytes[](3);
    elements[0] = address(this).encodeAddress();
    elements[1] = addrSet[0].encodeAddress();
    elements[2] = (amount * minDelegation / decimal).encodeUint();
    bytes memory ackPack = _genAckPack(uint8(1), uint8(0), _RLPEncode(EVENT_DELEGATE, elements.encodeList()));
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);
    staking.redelegate{value: relayFee}(addrSet[0], addrSet[1], amount * minDelegation);

    bytes[] memory elements1 = new bytes[](4);
    elements1[0] = address(this).encodeAddress();
    elements1[1] = addrSet[0].encodeAddress();
    elements1[2] = addrSet[1].encodeAddress();
    elements1[3] = (amount * minDelegation / decimal).encodeUint();

    ackPack = _genAckPack(uint8(0), uint8(1), _RLPEncode(EVENT_REDELEGATE, elements1.encodeList()));
    vm.expectEmit(true, true, true, true, address(staking));
    emit redelegateFailed(address(this), addrSet[0], addrSet[1], amount * minDelegation, uint8(1));
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);
  }

  function testHandleDelegateFailAckPackage(uint16 amount) public {
    vm.assume(amount > 0);
    uint256 sendValue = amount * minDelegation + relayFee;
    uint256 bcAmount = amount * minDelegation / decimal;
    uint8 eventCode = EVENT_DELEGATE;
    staking.delegate{value: sendValue}(addrSet[0], amount * minDelegation);

    bytes[] memory elements = new bytes[](3);
    elements[0] = address(this).encodeAddress();
    elements[1] = addrSet[0].encodeAddress();
    elements[2] = (bcAmount).encodeUint();

    vm.expectEmit(false, false, false, true, address(staking));
    emit crashResponse(eventCode);
    vm.startPrank(address(crossChain));
    staking.handleFailAckPackage(CROSS_STAKE_CHANNELID, _RLPEncode(eventCode, elements.encodeList()));
    vm.stopPrank();
  }

  function testHandleUndelegateFailAckPackage(uint16 amount) public {
    vm.assume(amount > 0);
    uint256 sendValue = amount * minDelegation + relayFee;
    uint256 bcAmount = amount * minDelegation / decimal;
    uint8 eventCode = EVENT_UNDELEGATE;
    staking.delegate{value: sendValue}(addrSet[0], amount * minDelegation);
    bytes[] memory elements = new bytes[](3);
    elements[0] = address(this).encodeAddress();
    elements[1] = addrSet[0].encodeAddress();
    elements[2] = (bcAmount).encodeUint();
    bytes memory ackPack = _genAckPack(uint8(1), uint8(0), _RLPEncode(EVENT_DELEGATE, elements.encodeList()));
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);
    staking.undelegate{value: relayFee}(addrSet[0], amount * minDelegation);

    vm.expectEmit(false, false, false, true, address(staking));
    emit crashResponse(eventCode);
    vm.startPrank(address(crossChain));
    staking.handleFailAckPackage(CROSS_STAKE_CHANNELID, _RLPEncode(eventCode, elements.encodeList()));
    vm.stopPrank();
  }

  function testHandleRedelegateFailAckPackage(uint16 amount) public {
    vm.assume(amount > 0);
    uint256 sendValue = amount * minDelegation + relayFee;
    uint256 bcAmount = amount * minDelegation / decimal;
    uint8 eventCode = EVENT_REDELEGATE;
    staking.delegate{value: sendValue}(addrSet[0], amount * minDelegation);
    bytes[] memory elements = new bytes[](3);
    elements[0] = address(this).encodeAddress();
    elements[1] = addrSet[0].encodeAddress();
    elements[2] = (bcAmount).encodeUint();
    bytes memory ackPack = _genAckPack(uint8(1), uint8(0), _RLPEncode(EVENT_DELEGATE, elements.encodeList()));
    vm.prank(address(crossChain));
    staking.handleAckPackage(CROSS_STAKE_CHANNELID, ackPack);
    staking.redelegate{value: relayFee}(addrSet[0], addrSet[1], amount * minDelegation);

    bytes[] memory elements1 = new bytes[](4);
    elements1[0] = address(this).encodeAddress();
    elements1[1] = addrSet[0].encodeAddress();
    elements1[2] = addrSet[1].encodeAddress();
    elements1[3] = (bcAmount).encodeUint();

    vm.expectEmit(false, false, false, true, address(staking));
    emit crashResponse(eventCode);
    vm.startPrank(address(crossChain));
    staking.handleFailAckPackage(CROSS_STAKE_CHANNELID, _RLPEncode(eventCode, elements1.encodeList()));
    vm.stopPrank();
  }

  function _RLPEncode(uint8 eventType, bytes memory msgBytes) internal pure returns (bytes memory output) {
    bytes[] memory elements = new bytes[](2);
    elements[0] = eventType.encodeUint();
    elements[1] = msgBytes.encodeBytes();
    output = elements.encodeList();
  }

  function _genAckPack(uint8 status, uint8 errCode, bytes memory paramBytes) internal pure returns (bytes memory output) {
    bytes[] memory elements = new bytes[](3);
    elements[0] = status.encodeUint();
    elements[1] = errCode.encodeUint();
    elements[2] = paramBytes.encodeBytes();
    output = elements.encodeList();
  }
}
