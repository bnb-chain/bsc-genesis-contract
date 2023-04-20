pragma solidity ^0.8.10;

import "../lib/Deployer.sol";
import "../lib/interface/IABCToken.sol";
import "../lib/interface/IDEFToken.sol";
import "../lib/interface/IXYZToken.sol";
import "../lib/interface/IMaliciousToken.sol";
import "../lib/interface/IMiniToken.sol";

contract TokenHubTest is Deployer {
  using RLPEncode for *;
  using RLPDecode for *;
  uint256 constant public INIT_LOCK_PERIOD = 12 hours;

  event bindFailure(address indexed contractAddr, string bep2Symbol, uint32 failedReason);
  event bindSuccess(address indexed contractAddr, string bep2Symbol, uint256 totalSupply, uint256 peggyAmount);
  event mirrorFailure(address indexed bep20Addr, uint8 errCode);
  event mirrorSuccess(address indexed bep20Addr, bytes32 bep2Symbol);
  event syncFailure(address indexed bep20Addr, uint8 errCode);
  event syncSuccess(address indexed bep20Addr);
  event transferInSuccess(address bep20Addr, address refundAddr, uint256 amount);
  event transferOutSuccess(address bep20Addr, address senderAddr, uint256 amount, uint256 relayFee);
  event refundSuccess(address bep20Addr, address refundAddr, uint256 amount, uint32 status);
  event refundFailure(address bep20Addr, address refundAddr, uint256 amount, uint32 status);
  event rewardTo(address to, uint256 amount);
  event receiveDeposit(address from, uint256 amount);
  event unexpectedPackage(uint8 channelId, bytes msgBytes);
  event paramChange(string key, bytes value);
  event crossChainPackage();

  ABCToken public abcToken;
  DEFToken public defToken;
  XYZToken public xyzToken;
  MaliciousToken public maliciousToken;
  MiniToken public miniToken;

  receive() external payable {}

  function setUp() public {
    address abcAddr = deployCode("ABCToken.sol");
    abcToken = ABCToken(abcAddr);
    vm.label(abcAddr, "ABCToken");

    address defAddr = deployCode("DEFToken.sol");
    defToken = DEFToken(defAddr);
    vm.label(defAddr, "DEFToken");

    address xyzAddr = deployCode("XYZToken.sol");
    xyzToken = XYZToken(xyzAddr);
    vm.label(xyzAddr, "XYZToken");

    address maliciousAddr = deployCode("MaliciousToken.sol");
    maliciousToken = MaliciousToken(maliciousAddr);
    vm.label(maliciousAddr, "MaliciousToken");

    address miniAddr = deployCode("MiniToken.sol");
    miniToken = MiniToken(miniAddr);
    vm.label(miniAddr, "MiniToken");


    address deployAddr = deployCode("TokenHub.sol");
    vm.etch(TOKEN_HUB_ADDR, deployAddr.code);
    tokenHub = TokenHub(TOKEN_HUB_ADDR);
    vm.label(address(tokenHub), "TokenHub");

    deployAddr = deployCode("CrossChain.sol");
    vm.etch(CROSS_CHAIN_CONTRACT_ADDR, deployAddr.code);
    crossChain = CrossChain(CROSS_CHAIN_CONTRACT_ADDR);
    vm.label(address(crossChain), "CrossChain");
  }

  function testBindFailed() public {
    bytes memory pack = buildBindPackage(uint8(0), bytes32("ABC-9C7"), address(abcToken), 1e8, 99e6, uint8(18));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);

    (, bytes32 symbol, address addr, uint256 totalSupply, uint256 peggyAmount, uint8 decimal,) = tokenManager.bindPackageRecord(bytes32("ABC-9C7"));
    assertEq(symbol, bytes32("ABC-9C7"), "wrong symbol");
    assertEq(addr, address(abcToken), "wrong token address");
    assertEq(totalSupply, 1e8 * 1e18, "wrong total supply");
    assertEq(peggyAmount, 99e6 * 1e18, "wrong peggy amount");
    assertEq(decimal, 18);

    uint256 lockAmount = tokenManager.queryRequiredLockAmountForBind("ABC-9C7");
    assertEq(lockAmount, 1e6 * 1e18, "wrong lock amount");

    vm.startPrank(relayer);
    vm.expectRevert(bytes("only bep20 owner can approve this bind request"));
    tokenManager.approveBind(address(abcToken), "ABC-9C7");

    vm.expectRevert(bytes("contact address doesn't equal to the contract address in bind request"));
    tokenManager.approveBind(address(0), "ABC-9C7");
    vm.stopPrank();

    vm.expectRevert(bytes("allowance is not enough"));
    tokenManager.approveBind(address(abcToken), "ABC-9C7");

    // Bind expired
    abcToken.approve(address(tokenManager), 1e6 * 1e18);
    vm.warp(block.timestamp + 5);
    vm.expectEmit(true, false, false, true, address(tokenManager));
    emit bindFailure(address(abcToken), "ABC-9C7", 1);
    tokenManager.approveBind{value: 1e16}(address(abcToken), "ABC-9C7");

    pack = buildBindPackage(uint8(0), bytes32("DEF-9C7"), address(abcToken), 1e8, 99e6, uint8(18));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);

    abcToken.approve(address(tokenManager), 1e6 * 1e18);
    vm.expectEmit(true, false, false, true, address(tokenManager));
    emit bindFailure(address(abcToken), "DEF-9C7", 2);
    tokenManager.approveBind{value: 1e16}(address(abcToken), "DEF-9C7");
  }

  function testRejectAndExpireBind() public {
    bytes memory pack = buildBindPackage(uint8(0), bytes32("ABC-9C7"), address(abcToken), 1e8, 99e6, uint8(18));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);

    vm.prank(relayer);
    vm.expectRevert(bytes("only bep20 owner can reject"));
    tokenManager.rejectBind{value: 1e16}(address(abcToken), "ABC-9C7");

    vm.expectEmit(true, false, false, true, address(tokenManager));
    emit bindFailure(address(abcToken), "ABC-9C7", 7);
    tokenManager.rejectBind{value: 1e16}(address(abcToken), "ABC-9C7");

    pack = buildBindPackage(uint8(0), bytes32("ABC-9C7"), address(abcToken), 1e8, 99e6, uint8(18));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);

    vm.prank(relayer);
    vm.expectRevert(bytes("bind request is not expired"));
    tokenManager.expireBind{value: 1e16}("ABC-9C7");

    vm.warp(block.timestamp + 5);
    vm.expectEmit(true, false, false, true, address(tokenManager));
    emit bindFailure(address(abcToken), "ABC-9C7", 1);
    tokenManager.expireBind{value: 1e16}("ABC-9C7");
  }

  function testBindMaliciousToken() public {
    bytes memory pack = buildBindPackage(uint8(0), bytes32("MALICIOU-A09"), address(maliciousToken), 1e8, 99e6, uint8(18));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);

    maliciousToken.approve(address(tokenManager), 1e8 * 1e18);
    tokenManager.approveBind{value: 1e16}(address(maliciousToken), "MALICIOU-A09");
    string memory bep2Symbol = tokenHub.getBoundBep2Symbol(address(maliciousToken));
    assertEq(bep2Symbol, "MALICIOU-A09", "wrong bep2 token symbol");

    address recipient = addrSet[addrIdx++];
    address refundAddr = addrSet[addrIdx++];
    uint256 amount = 115e17;
    assertEq(maliciousToken.balanceOf(recipient), 0);
    pack = buildTransferInPackage(bytes32("MALICIOU-A09"), address(maliciousToken), amount, recipient, refundAddr);
    vm.prank(address(crossChain));
    vm.expectRevert(bytes("malicious method"));
    tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, pack);

    // refund
    bytes[] memory elements = new bytes[](4);
    bytes[] memory amt = new bytes[](1);
    bytes[] memory addr = new bytes[](1);
    amt[0] = amount.encodeUint();
    addr[0] = address(this).encodeAddress();
    elements[0] = address(maliciousToken).encodeAddress();
    elements[1] = amt.encodeList();
    elements[2] = addr.encodeList();
    elements[3] = uint32(1).encodeUint();

    vm.prank(address(crossChain));
    vm.expectRevert(bytes("malicious method"));
    tokenHub.handleAckPackage(TRANSFER_OUT_CHANNELID, elements.encodeList());
  }

  function testBindAndTransferIn() public {
    // Bind
    bytes memory pack = buildBindPackage(uint8(0), bytes32("ABC-9C7"), address(abcToken), 1e8, 99e6, uint8(18));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);
    abcToken.approve(address(tokenManager), 1e6 * 1e18);
    tokenManager.approveBind{value: 1e16}(address(abcToken), "ABC-9C7");

    assertEq(tokenHub.getBoundBep2Symbol(address(abcToken)), "ABC-9C7", "wrong bep2 symbol");
    assertEq(tokenHub.getBoundContract("ABC-9C7"), address(abcToken), "wrong token contract address");
    assertEq(address(tokenManager).balance, 0, "tokenManager balance should be 0");

    // Expired transferIn
    address recipient = addrSet[addrIdx++];
    address refundAddr = addrSet[addrIdx++];
    assertEq(abcToken.balanceOf(recipient), 0);
    pack = buildTransferInPackage(bytes32("ABC-9C7"), address(abcToken), 115e17, recipient, refundAddr);

    vm.warp(block.timestamp + 5);
    vm.prank(address(crossChain));
    bytes memory payload = tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, pack);
    RLPDecode.Iterator memory iter = payload.toRLPItem().iterator();
    bool success;
    uint256 idx;
    bytes32 bep2TokenSymbol;
    uint256 refAmount;
    address refAddr;
    uint32 status;
    while (iter.hasNext()) {
      if (idx == 0) {
        bep2TokenSymbol = bytes32(iter.next().toUint());
        assertEq(bep2TokenSymbol, bytes32("ABC-9C7"), "wrong token symbol in refund package");
      } else if (idx == 1) {
        refAmount = iter.next().toUint();
        assertEq(refAmount, 115e7, "wrong amount in refund package");
      } else if (idx == 2) {
        refAddr = iter.next().toAddress();
        assertEq(refAddr, refundAddr, "wrong refund address in refund package");
      } else if (idx == 3) {
        status = uint32(iter.next().toUint());
        assertEq(status, uint32(0x01), "wrong status code in refund package");
        success = true;
      } else {
        break;
      }
      ++idx;
    }
    require(success, "rlp decode refund package failed");

    // TransferIn succeed
    recipient = addrSet[addrIdx++];
    refundAddr = addrSet[addrIdx++];
    assertEq(abcToken.balanceOf(recipient), 0);
    pack = buildTransferInPackage(bytes32("ABC-9C7"), address(abcToken), 115e17, recipient, refundAddr);
    vm.prank(address(crossChain));
    tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, pack);
    assertEq(abcToken.balanceOf(recipient), 115e17, "wrong balance");

    // BNB transferIn
    recipient = addrSet[addrIdx++];
    refundAddr = addrSet[addrIdx++];
    pack = buildTransferInPackage(bytes32("BNB"), address(0x0), 1e18, recipient, refundAddr);
    uint256 balance = recipient.balance;
    vm.prank(address(crossChain));
    tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, pack);
    assertEq(recipient.balance - balance, 1e18, "wrong balance");

    // TODO try a large relayer fee

    // BNB transferIn to a non-payable address
    recipient = address(lightClient);
    refundAddr = addrSet[addrIdx++];
    pack = buildTransferInPackage(bytes32("BNB"), address(0x0), 1e18, recipient, refundAddr);
    balance = recipient.balance;
    vm.prank(address(crossChain));
    payload = tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, pack);
    assertEq(recipient.balance, balance);
    iter = payload.toRLPItem().iterator();
    success = false;
    idx = 0;
    while (iter.hasNext()) {
      if (idx == 0) {
        bep2TokenSymbol = bytes32(iter.next().toUint());
        assertEq(bep2TokenSymbol, bytes32("BNB"), "wrong token symbol in refund package");
      } else if (idx == 1) {
        refAmount = iter.next().toUint();
        assertEq(refAmount, 1e8, "wrong amount in refund package");
      } else if (idx == 2) {
        refAddr = iter.next().toAddress();
        assertEq(refAddr, refundAddr, "wrong refund address in refund package");
      } else if (idx == 3) {
        status = uint32(iter.next().toUint());
        assertEq(status, uint32(0x04), "wrong status code in refund package");
        success = true;
      } else {
        break;
      }
      ++idx;
    }
    require(success, "rlp decode refund package failed");
  }

  function testLargeTransferIn() public {
    // Bind
    bytes memory pack = buildBindPackage(uint8(0), bytes32("ABC-9C7"), address(abcToken), 1e8, 99e6, uint8(18));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);
    abcToken.approve(address(tokenManager), 1e6 * 1e18);
    tokenManager.approveBind{value: 1e16}(address(abcToken), "ABC-9C7");

    assertEq(tokenHub.getBoundBep2Symbol(address(abcToken)), "ABC-9C7", "wrong bep2 symbol");
    assertEq(tokenHub.getBoundContract("ABC-9C7"), address(abcToken), "wrong token contract address");
    assertEq(address(tokenManager).balance, 0, "tokenManager balance should be 0");

    // Expired transferIn
    address recipient = addrSet[addrIdx++];
    address refundAddr = addrSet[addrIdx++];
    assertEq(abcToken.balanceOf(recipient), 0);
    pack = buildTransferInPackage(bytes32("ABC-9C7"), address(abcToken), 115e17, recipient, refundAddr);

    vm.warp(block.timestamp + 5);
    vm.prank(address(crossChain));
    bytes memory payload = tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, pack);
    RLPDecode.Iterator memory iter = payload.toRLPItem().iterator();
    bool success;
    uint256 idx;
    bytes32 bep2TokenSymbol;
    uint256 refAmount;
    address refAddr;
    uint32 status;
    while (iter.hasNext()) {
      if (idx == 0) {
        bep2TokenSymbol = bytes32(iter.next().toUint());
        assertEq(bep2TokenSymbol, bytes32("ABC-9C7"), "wrong token symbol in refund package");
      } else if (idx == 1) {
        refAmount = iter.next().toUint();
        assertEq(refAmount, 115e7, "wrong amount in refund package");
      } else if (idx == 2) {
        refAddr = iter.next().toAddress();
        assertEq(refAddr, refundAddr, "wrong refund address in refund package");
      } else if (idx == 3) {
        status = uint32(iter.next().toUint());
        assertEq(status, uint32(0x01), "wrong status code in refund package");
        success = true;
      } else {
        break;
      }
      ++idx;
    }
    require(success, "rlp decode refund package failed");

    // TransferIn succeed
    recipient = addrSet[addrIdx++];
    refundAddr = addrSet[addrIdx++];
    assertEq(abcToken.balanceOf(recipient), 0);
    pack = buildTransferInPackage(bytes32("ABC-9C7"), address(abcToken), 115e17, recipient, refundAddr);
    vm.prank(address(crossChain));
    tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, pack);
    assertEq(abcToken.balanceOf(recipient), 115e17, "wrong balance");

    // BNB transferIn without lock
    address _recipient = addrSet[addrIdx++];
    address _refundAddr = addrSet[addrIdx++];
    bytes memory _pack = buildTransferInPackage(bytes32("BNB"), address(0x0), 9999 * 1e18, _recipient, _refundAddr);
    uint256 balance = _recipient.balance;
    vm.prank(address(crossChain));
    tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, _pack);
    assertEq(_recipient.balance - balance, 9999 * 1e18, "wrong balance");

    // BNB transferIn with lock
    _recipient = addrSet[addrIdx++];
    _refundAddr = addrSet[addrIdx++];
    _pack = buildTransferInPackage(bytes32("BNB"), address(0x0), 10000 * 1e18, _recipient, _refundAddr);
    balance = _recipient.balance;
    vm.prank(address(crossChain));
    tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, _pack);
    // while BNB amount >= 10000 ether, locking fixed hours
    assertEq(_recipient.balance - balance, 0, "wrong balance");
    (uint256 amount, uint256 unlockAt) = tokenHub.lockInfoMap(address(0), _recipient);
    assertEq(amount, 10000 * 1e18, "wrong locked amount");
    assertEq(unlockAt, block.timestamp + INIT_LOCK_PERIOD, "wrong unlockAt");

    // withdraw unlocked BNB
    vm.warp(block.timestamp + INIT_LOCK_PERIOD);
    tokenHub.withdrawUnlockedToken(address(0), _recipient);
    assertEq(_recipient.balance - balance, 10000 * 1e18, "wrong balance");

    // BNB transferIn to a non-payable address
    _recipient = address(lightClient);
    _refundAddr = addrSet[addrIdx++];
    _pack = buildTransferInPackage(bytes32("BNB"), address(0x0), 1e18, _recipient, _refundAddr);
    balance = _recipient.balance;
    vm.prank(address(crossChain));
    bytes memory _payload = tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, _pack);
    assertEq(_recipient.balance, balance);
    iter = _payload.toRLPItem().iterator();
    success = false;
    idx = 0;
    while (iter.hasNext()) {
      if (idx == 0) {
        bep2TokenSymbol = bytes32(iter.next().toUint());
        assertEq(bep2TokenSymbol, bytes32("BNB"), "wrong token symbol in refund package");
      } else if (idx == 1) {
        refAmount = iter.next().toUint();
        assertEq(refAmount, 1e8, "wrong amount in refund package");
      } else if (idx == 2) {
        refAddr = iter.next().toAddress();
        assertEq(refAddr, _refundAddr, "wrong refund address in refund package");
      } else if (idx == 3) {
        status = uint32(iter.next().toUint());
        assertEq(status, uint32(0x04), "wrong status code in refund package");
        success = true;
      } else {
        break;
      }
      ++idx;
    }
    require(success, "rlp decode refund package failed");
  }

  function testSuspend() public {
    vm.prank(block.coinbase);
    crossChain.suspend();
    assert(crossChain.isSuspended());

    vm.prank(block.coinbase);
    vm.expectRevert(bytes("suspended"));
    crossChain.suspend();

//    // BNB transferIn with lock
//    address _recipient = addrSet[addrIdx++];
//    address _refundAddr = addrSet[addrIdx++];
//    bytes memory _pack = buildTransferInPackage(bytes32("BNB"), address(0x0), 10000 * 1e18, _recipient, _refundAddr);
//    uint256 balance = _recipient.balance;
//    uint256 amount;
//    uint256 unlockAt;

    address relayer = 0x446AA6E0DC65690403dF3F127750da1322941F3e;
    uint64 height = crossChain.channelSyncedHeaderMap(TRANSFER_IN_CHANNELID);
    uint64 seq = crossChain.channelReceiveSequenceMap(TRANSFER_IN_CHANNELID);
    vm.startPrank(relayer, relayer);
    vm.expectRevert(bytes("suspended"));
    crossChain.handlePackage(
      "",
      "",
      height,
      seq,
      TRANSFER_IN_CHANNELID
    );
    vm.stopPrank();

    address[] memory _validators = validator.getValidators();
    vm.prank(_validators[0]);
    crossChain.reopen();
    assert(crossChain.isSuspended());
    vm.prank(_validators[1]);
    crossChain.reopen();
    assert(!crossChain.isSuspended());
    vm.prank(relayer, relayer);
    vm.expectRevert(bytes("invalid merkle proof"));
    crossChain.handlePackage(
      "",
      "",
      height,
      seq,
      TRANSFER_IN_CHANNELID
    );
    vm.stopPrank();
  }

  function testCancelTransfer() public {
    // BNB transferIn with lock
    address _recipient = addrSet[addrIdx++];
    address _refundAddr = addrSet[addrIdx++];
    bytes memory _pack = buildTransferInPackage(bytes32("BNB"), address(0x0), 10000 * 1e18, _recipient, _refundAddr);
    uint256 balance = _recipient.balance;
    uint256 amount;
    uint256 unlockAt;

    vm.prank(address(crossChain));
    tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, _pack);

    // while BNB amount >= 10000 ether, locking fixed hours
    assertEq(_recipient.balance - balance, 0, "wrong balance");
    (amount, unlockAt) = tokenHub.lockInfoMap(address(0), _recipient);
    assertEq(amount, 10000 * 1e18, "wrong locked amount");
    assertEq(unlockAt, block.timestamp + INIT_LOCK_PERIOD, "wrong unlockAt");

    // cancelTransferIn by validators
    address[] memory _validators = validator.getValidators();
    vm.prank(_validators[0]);
    crossChain.cancelTransfer(address(0), _recipient);
    (amount, unlockAt) = tokenHub.lockInfoMap(address(0), _recipient);
    assertEq(amount, 10000 * 1e18, "wrong locked amount");
    assertEq(unlockAt, block.timestamp + INIT_LOCK_PERIOD, "wrong unlockAt");

    vm.prank(block.coinbase);
    crossChain.cancelTransfer(address(0), _recipient);
    (amount, unlockAt) = tokenHub.lockInfoMap(address(0), _recipient);
    assertEq(amount, 0, "wrong locked amount after cancelTransfer");
  }

  function testTransferOut() public {
    bytes memory pack = buildBindPackage(uint8(0), bytes32("ABC-9C7"), address(abcToken), 1e8, 99e6, uint8(18));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);

    abcToken.approve(address(tokenManager), 1e8 * 1e18);
    tokenManager.approveBind{value: 1e16}(address(abcToken), "ABC-9C7");

    uint64 expireTime = uint64(block.timestamp + 150);
    address recipient = 0xd719dDfA57bb1489A08DF33BDE4D5BA0A9998C60;
    uint256 amount = 1e8;
    uint256 relayerFee = 1e14;

    vm.expectRevert(bytes("received BNB amount should be no less than the minimum relayFee"));
    tokenHub.transferOut{value: relayerFee}(address(abcToken), recipient, amount, expireTime);

    relayerFee = 1e16;
    vm.expectRevert(bytes("invalid transfer amount: precision loss in amount conversion"));
    tokenHub.transferOut{value: relayerFee}(address(abcToken), recipient, amount, expireTime);

    amount = 1e18;
    vm.expectRevert(bytes("invalid received BNB amount: precision loss in amount conversion"));
    tokenHub.transferOut{value: relayerFee + 1}(address(abcToken), recipient, amount, expireTime);

    vm.expectRevert(bytes("BEP20: transfer amount exceeds allowance"));
    tokenHub.transferOut{value: relayerFee}(address(abcToken), recipient, amount, expireTime);

    vm.expectRevert(bytes("the contract has not been bound to any bep2 token"));
    tokenHub.transferOut{value: relayerFee}(address(defToken), recipient, amount, expireTime);

    vm.expectRevert(bytes("received BNB amount should be no less than the minimum relayFee"));
    tokenHub.transferOut(address(abcToken), recipient, amount, expireTime);

    uint256 balance = abcToken.balanceOf(address(this));
    abcToken.approve(address(tokenHub), amount);
    vm.expectEmit(true, false, false, true, address(tokenHub));
    emit transferOutSuccess(address(abcToken), address(this), amount, relayerFee);
    tokenHub.transferOut{value: relayerFee}(address(abcToken), recipient, amount, expireTime);
    assertEq(abcToken.balanceOf(address(this)), balance - amount, "wrong balance");

    // refund
    uint256[] memory amounts = new uint256[](1);
    address[] memory refundAddrs = new address[](1);
    amounts[0] = amount;
    refundAddrs[0] = address(this);
    bytes memory package = buildRefundPackage(address(abcToken), amounts, refundAddrs, uint32(1));

    vm.prank(address(crossChain));
    vm.expectEmit(true, false, false, true, address(tokenHub));
    emit refundSuccess(address(abcToken), address(this), amount, 1);
    tokenHub.handleAckPackage(TRANSFER_OUT_CHANNELID, package);
    assertEq(abcToken.balanceOf(address(this)), balance, "wrong balance");

    // Fail ack refund
    uint256 length = 5;
    uint256[] memory balances = new uint256[](length);
    address[] memory recipients = new address[](length);
    amounts = new uint256[](length);
    refundAddrs = new address[](length);
    for (uint256 i; i < length; ++i) {
      amounts[i] = (i + 1) * 1e6;
      balances[i] = abcToken.balanceOf(addrSet[addrIdx]);
      recipients[i] = addrSet[addrIdx];
      refundAddrs[i] = addrSet[addrIdx++];
    }

    package = buildBatchTransferOutFailAckPackage(bytes32("ABC-9C7"), address(abcToken), amounts, recipients, refundAddrs);
    vm.prank(address(crossChain));
    tokenHub.handleFailAckPackage(TRANSFER_OUT_CHANNELID, package);
    for (uint256 i; i < length; ++i) {
      assertEq(abcToken.balanceOf(recipients[i]) - balances[i], amounts[i] * 1e10, "wrong balance");
    }
  }

  function testBatchTransferOutBNB() public {
    uint64 expireTime = uint64(block.timestamp + 150);
    address[] memory recipients = new address[](2);
    address[] memory refundAddrs = new address[](2);
    uint256[] memory amounts = new uint256[](2);
    for (uint256 i; i < 2; ++i) {
      recipients[i] = addrSet[addrIdx];
      refundAddrs[i] = addrSet[addrIdx++];
      amounts[i] = 5e9;
    }

    vm.expectRevert(bytes("invalid transfer amount: precision loss in amount conversion"));
    tokenHub.batchTransferOutBNB{value: 5e16}(recipients, amounts, refundAddrs, expireTime);

    amounts[0] = 1e16;
    amounts[1] = 2e16;
    vm.expectEmit(true, false, false, true, address(tokenHub));
    emit transferOutSuccess(address(0x0), address(this), 3e16, 2e16);
    tokenHub.batchTransferOutBNB{value: 5e16}(recipients, amounts, refundAddrs, expireTime);
  }

  function testOverflow() public {
    uint64 expireTime = uint64(block.timestamp + 150);
    address recipient = 0xd719dDfA57bb1489A08DF33BDE4D5BA0A9998C60;
    uint256 amount = 115792089237316195423570985008687907853269984665640564039457584007903129639936;
    uint256 relayerFee = 1e16;

    vm.expectRevert(bytes("SafeMath: addition overflow"));
    tokenHub.transferOut{value: relayerFee}(address(0), recipient, amount, expireTime);

    // batch transfer out
    address[] memory recipients = new address[](2);
    address[] memory refundAddrs = new address[](2);
    uint256[] memory amounts = new uint256[](2);
    for (uint256 i; i < 2; ++i) {
      recipients[i] = addrSet[addrIdx];
      refundAddrs[i] = addrSet[addrIdx++];
    }
    amounts[0] = 100000000000000000000000000000000000000000000000000000000000000000000000000000;
    amounts[1] = 15792089237316195423570985008687907853269984665640564039457584007910000000000;

    vm.expectRevert(bytes("SafeMath: addition overflow"));
    tokenHub.batchTransferOutBNB{value: 2e16}(recipients, amounts, refundAddrs, expireTime);
  }

  function testUnbind() public {
    // Bind first
    bytes memory pack = buildBindPackage(uint8(0), bytes32("ABC-9C7"), address(abcToken), 1e8, 99e6, uint8(18));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);

    abcToken.approve(address(tokenManager), 1e8 * 1e18);
    tokenManager.approveBind{value: 1e16}(address(abcToken), "ABC-9C7");

    // Unbind
    pack = buildBindPackage(uint8(1), bytes32("ABC-9C7"), address(abcToken), 0, 0, uint8(0));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);

    assertEq(tokenHub.getBoundBep2Symbol(address(abcToken)), "", "wrong symbol");
    assertEq(tokenHub.getBoundContract("ABC-9C7"), address(0x0), "wrong token contract address");

    // TransferIn failed
    address recipient = addrSet[addrIdx++];
    address refundAddr = addrSet[addrIdx++];
    assertEq(abcToken.balanceOf(recipient), 0);
    pack = buildTransferInPackage(bytes32("ABC-9C7"), address(abcToken), 115e17, recipient, refundAddr);
    vm.prank(address(crossChain));
    tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, pack);
    assertEq(abcToken.balanceOf(recipient), 0, "wrong balance");

    // TransferOut refund
    recipient = addrSet[addrIdx++];
    uint256 amount = 1e18;
    uint256[] memory amounts = new uint256[](1);
    address[] memory refundAddrs = new address[](1);
    amounts[0] = amount;
    refundAddrs[0] = recipient;
    bytes memory package = buildRefundPackage(address(abcToken), amounts, refundAddrs, uint32(1));
    abcToken.transfer(address(tokenHub), amount);

    vm.prank(address(crossChain));
    vm.expectEmit(true, false, false, true, address(tokenHub));
    emit refundSuccess(address(abcToken), recipient, amount, 1);
    tokenHub.handleAckPackage(TRANSFER_OUT_CHANNELID, package);
    assertEq(abcToken.balanceOf(recipient), amount, "wrong balance");

    // TransferOut failed
    uint64 expireTime = uint64(block.timestamp + 150);
    uint256 relayerFee = 1e14;
    recipient = 0xd719dDfA57bb1489A08DF33BDE4D5BA0A9998C60;
    amount = 1e8;

    abcToken.approve(address(tokenHub), amount);
    vm.expectRevert(bytes("the contract has not been bound to any bep2 token"));
    tokenHub.transferOut{value: relayerFee}(address(abcToken), recipient, amount, expireTime);
  }

  function testMiniToken() public {
    // Bind
    bytes memory pack = buildBindPackage(uint8(0), bytes32("XYZ-9C7M"), address(miniToken), 1e4, 5e3, uint8(18));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);

    miniToken.approve(address(tokenManager), 5e3 * 1e18);
    vm.expectEmit(true, false, false, true, address(tokenManager));
    emit bindSuccess(address(miniToken), "XYZ-9C7M", 1e4 * 1e18, 5e3 * 1e18);
    tokenManager.approveBind{value: 1e16}(address(miniToken), "XYZ-9C7M");

    assertEq(tokenHub.getBoundBep2Symbol(address(miniToken)), "XYZ-9C7M", "wrong bep2 symbol");
    assertEq(tokenHub.getBoundContract("XYZ-9C7M"), address(miniToken), "wrong token contract address");

    // TransferIn
    address recipient = addrSet[addrIdx++];
    address refundAddr = addrSet[addrIdx++];
    assertEq(miniToken.balanceOf(recipient), 0);
    pack = buildTransferInPackage(bytes32("XYZ-9C7M"), address(miniToken), 1e18, recipient, refundAddr);
    vm.prank(address(crossChain));
    tokenHub.handleSynPackage(TRANSFER_IN_CHANNELID, pack);
    assertEq(miniToken.balanceOf(recipient), 1e18, "wrong balance");

    // TransferOut
    uint64 expireTime = uint64(block.timestamp + 150);
    uint256 amount = 1e18;
    uint256 relayerFee = 1e16;
    recipient = addrSet[addrIdx++];

    miniToken.approve(address(tokenHub), amount);
    vm.expectEmit(true, false, false, true, address(tokenHub));
    emit transferOutSuccess(address(miniToken), address(this), 1e18, 1e16);
    tokenHub.transferOut{value: relayerFee}(address(miniToken), recipient, amount, expireTime);

    // TransferOut failed
    amount = 5e17;
    recipient = addrSet[addrIdx++];

    miniToken.approve(address(tokenHub), amount);
    vm.expectRevert(bytes("For miniToken, the transfer amount must not be less than 1"));
    tokenHub.transferOut{value: relayerFee}(address(miniToken), recipient, amount, expireTime);
  }

  function testMirrorFailed() public {
    uint256 mirrorFee = 1e20;
    uint256 syncFee = 1e19;

    bytes memory key = "mirrorFee";
    bytes memory valueBytes = abi.encodePacked(mirrorFee);
    updateParamByGovHub(key, valueBytes, address(tokenManager));
    assertEq(tokenManager.mirrorFee(), mirrorFee, "wrong mirrorFee");

    key = "syncFee";
    valueBytes = abi.encodePacked(syncFee);
    updateParamByGovHub(key, valueBytes, address(tokenManager));
    assertEq(tokenManager.syncFee(), syncFee, "wrong syncFee");

    // Bind miniToken
    bytes memory pack = buildBindPackage(uint8(0), bytes32("XYZ-9C7M"), address(miniToken), 1e4, 5e3, uint8(18));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);
    miniToken.approve(address(tokenManager), 5e3 * 1e18);
    tokenManager.approveBind{value: 1e16}(address(miniToken), "XYZ-9C7M");

    // Mirror failed
    uint64 expireTime = uint64(block.timestamp + 300);
    uint256 miniRelayerFee = tokenHub.getMiniRelayFee();
    vm.expectRevert(bytes("already bound"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(miniToken), expireTime);

    expireTime = uint64(block.timestamp + 100);
    vm.expectRevert(bytes("expireTime must be two minutes later and one day earlier"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    xyzToken.setName("");
    expireTime = uint64(block.timestamp + 300);
    vm.expectRevert(bytes("name length must be in [1,32]"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    xyzToken.setName("XYZ TokenXYZ TokenXYZ TokenXYZ Token");
    vm.expectRevert(bytes("name length must be in [1,32]"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    xyzToken.setName("XYZ Token");
    xyzToken.setSymbol("X");
    vm.expectRevert(bytes("symbol length must be in [2,8]"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    xyzToken.setSymbol("XYZXYZXYZ");
    vm.expectRevert(bytes("symbol length must be in [2,8]"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    xyzToken.setSymbol("X-Z");
    vm.expectRevert(bytes("symbol should only contain alphabet and number"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    xyzToken.setSymbol("X_Z");
    vm.expectRevert(bytes("symbol should only contain alphabet and number"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    xyzToken.setSymbol("XYZ");
    xyzToken.setDecimals(1);
    vm.expectRevert(bytes("too large total supply"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    xyzToken.setDecimals(87);
    vm.expectRevert(bytes("too large decimals"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    xyzToken.setDecimals(18);
    xyzToken.setTotalSupply(1e18 * 1e18);
    vm.expectRevert(bytes("too large total supply"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    vm.expectRevert(bytes("msg.value must be N * 1e10 and greater than sum of miniRelayFee and mirrorFee"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee + 1e9}(address(xyzToken), expireTime);

    vm.expectRevert(bytes("msg.value must be N * 1e10 and greater than sum of miniRelayFee and mirrorFee"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee - 1e9}(address(xyzToken), expireTime);

    xyzToken.setTotalSupply(1e8 * 1e18);
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);
    assertEq(address(tokenManager).balance, mirrorFee, "wrong balance in tokenManager");
    vm.expectRevert(bytes("mirror pending"));
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    // Mirror fail ack
    pack = buildMirrorFailAckPackage(address(this), address(xyzToken), bytes32("XYZ Token"), uint8(18), bytes32("XYZ"), 1e8 * 1e18, mirrorFee / 1e10, expireTime);
    vm.prank(address(crossChain));
    tokenManager.handleFailAckPackage(MIRROR_CHANNELID, pack);
    assertEq(address(tokenManager).balance, 0, "wrong balance in tokenManager");

    // Mirror ack
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);
    assertEq(address(tokenManager).balance, mirrorFee, "wrong balance in tokenManager");
    pack = buildMirrorAckPackage(address(this), address(xyzToken), uint8(18), bytes32(""), mirrorFee, uint8(1));
    vm.prank(address(crossChain));
    tokenManager.handleAckPackage(MIRROR_CHANNELID, pack);
    assertEq(address(tokenManager).balance, 0, "wrong balance in tokenManager");
  }

  function testMirrorAndSncSucceed() public {
    uint256 mirrorFee = 1e20;
    uint256 syncFee = 1e19;

    bytes memory key = "mirrorFee";
    bytes memory valueBytes = abi.encodePacked(mirrorFee);
    updateParamByGovHub(key, valueBytes, address(tokenManager));
    assertEq(tokenManager.mirrorFee(), mirrorFee, "wrong mirrorFee");

    key = "syncFee";
    valueBytes = abi.encodePacked(syncFee);
    updateParamByGovHub(key, valueBytes, address(tokenManager));
    assertEq(tokenManager.syncFee(), syncFee, "wrong syncFee");

    uint64 expireTime = uint64(block.timestamp + 150);
    uint256 miniRelayerFee = tokenHub.getMiniRelayFee();
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);
    assertEq(address(tokenManager).balance, mirrorFee, "wrong balance in tokenManager");

    bytes memory pack = buildMirrorAckPackage(address(this), address(xyzToken), uint8(18), bytes32("XYZ-123"), mirrorFee, uint8(0));
    vm.prank(address(crossChain));
    tokenManager.handleAckPackage(MIRROR_CHANNELID, pack);
    assertEq(address(tokenManager).balance, 0, "wrong balance in tokenManager");
    assertEq(tokenHub.getBoundBep2Symbol(address(xyzToken)), "XYZ-123", "wrong bep2 symbol");

    xyzToken.mint(1e8 * 1e18);
    uint256 totalSupply = xyzToken.totalSupply();

    // sync
    tokenManager.sync{value: miniRelayerFee + syncFee}(address(xyzToken), expireTime);
    assertEq(address(tokenManager).balance, syncFee, "wrong balance in tokenManager");

    // sync fail ack
    pack = buildSyncFailAckPackage(address(this), address(xyzToken), bytes32("XYZ"), totalSupply, syncFee / 1e10, expireTime);
    vm.prank(address(crossChain));
    tokenManager.handleFailAckPackage(SYNC_CHANNELID, pack);
    assertEq(address(tokenManager).balance, 0, "wrong balance in tokenManager");

    // sync success
    tokenManager.sync{value: miniRelayerFee + syncFee}(address(xyzToken), expireTime);
    assertEq(address(tokenManager).balance, syncFee, "wrong balance in tokenManager");
    pack = buildSyncAckPackage(address(this), address(xyzToken), syncFee, uint8(0));
    vm.prank(address(crossChain));
    tokenManager.handleAckPackage(SYNC_CHANNELID, pack);
    assertEq(address(tokenManager).balance, 0, "wrong balance in tokenManager");
  }

  function testSyncFailed() public {
    uint256 mirrorFee = 1e20;
    uint256 syncFee = 1e19;

    bytes memory key = "mirrorFee";
    bytes memory valueBytes = abi.encodePacked(mirrorFee);
    updateParamByGovHub(key, valueBytes, address(tokenManager));
    assertEq(tokenManager.mirrorFee(), mirrorFee, "wrong mirrorFee");

    key = "syncFee";
    valueBytes = abi.encodePacked(syncFee);
    updateParamByGovHub(key, valueBytes, address(tokenManager));
    assertEq(tokenManager.syncFee(), syncFee, "wrong syncFee");

    // Bond mini token
    bytes memory pack = buildBindPackage(uint8(0), bytes32("XYZ-9C7M"), address(miniToken), 1e4, 5e3, uint8(18));
    vm.prank(address(crossChain));
    tokenManager.handleSynPackage(BIND_CHANNELID, pack);
    miniToken.approve(address(tokenManager), 5e3 * 1e18);
    tokenManager.approveBind{value: 1e16}(address(miniToken), "XYZ-9C7M");

    // Mirror xyz
    uint64 expireTime = uint64(block.timestamp + 300);
    uint256 miniRelayerFee = tokenHub.getMiniRelayFee();
    tokenManager.mirror{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);
    pack = buildMirrorAckPackage(address(this), address(xyzToken), uint8(18), bytes32("XYZ-123"), mirrorFee, uint8(0));
    vm.prank(address(crossChain));
    tokenManager.handleAckPackage(MIRROR_CHANNELID, pack);

    // Sync failed
    vm.expectRevert(bytes("not bound"));
    tokenManager.sync{value: miniRelayerFee + mirrorFee}(address(defToken), expireTime);

    vm.expectRevert(bytes("not bound by mirror"));
    tokenManager.sync{value: miniRelayerFee + mirrorFee}(address(miniToken), expireTime);

    expireTime = uint64(block.timestamp + 100);
    vm.expectRevert(bytes("expireTime must be two minutes later and one day earlier"));
    tokenManager.sync{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    expireTime = uint64(block.timestamp + 300);
    xyzToken.setTotalSupply(1e18 * 1e18);
    vm.expectRevert(bytes("too large total supply"));
    tokenManager.sync{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);

    xyzToken.setTotalSupply(1e8 * 1e18);
    tokenManager.sync{value: miniRelayerFee + mirrorFee}(address(xyzToken), expireTime);
  }

  function buildBindPackage(uint8 bindType, bytes32 symbol, address addr, uint256 totalSupply, uint256 peggyAmount, uint8 decimal) internal view returns (bytes memory) {
    uint256 timestamp = block.timestamp;
    uint256 expireTime = timestamp + 3;
    bytes[] memory elements = new bytes[](7);
    elements[0] = bindType.encodeUint();
    elements[1] = abi.encodePacked(symbol).encodeBytes();
    elements[2] = addr.encodeAddress();
    elements[3] = (totalSupply * (10 ** decimal)).encodeUint();
    elements[4] = (peggyAmount * (10 ** decimal)).encodeUint();
    elements[5] = decimal.encodeUint();
    elements[6] = expireTime.encodeUint();
    return elements.encodeList();
  }

  function buildTransferInPackage(bytes32 symbol, address tokenAddr, uint256 amount, address recipient, address refundAddr) internal view returns (bytes memory) {
    uint256 timestamp = block.timestamp;
    uint256 expireTime = timestamp + 3;
    bytes[] memory elements = new bytes[](6);
    elements[0] = abi.encodePacked(symbol).encodeBytes();
    elements[1] = tokenAddr.encodeAddress();
    elements[2] = amount.encodeUint();
    elements[3] = recipient.encodeAddress();
    elements[4] = refundAddr.encodeAddress();
    elements[5] = expireTime.encodeUint();
    return elements.encodeList();
  }

  function buildBatchTransferOutFailAckPackage(bytes32 symbol, address tokenAddr, uint256[] memory amounts, address[] memory recipients, address[] memory refundAddrs) internal view returns (bytes memory) {
    uint256 length = amounts.length;
    bytes[] memory amtBytes = new bytes[](length);
    bytes[] memory recipientBytes = new bytes[](length);
    bytes[] memory refundAddrBytes = new bytes[](length);
    for (uint256 i; i < length; ++i) {
      amtBytes[i] = amounts[i].encodeUint();
      recipientBytes[i] = recipients[i].encodeAddress();
      refundAddrBytes[i] = refundAddrs[i].encodeAddress();
    }

    uint256 timestamp = block.timestamp;
    uint256 expireTime = timestamp + 150;
    bytes[] memory elements = new bytes[](6);
    elements[0] = abi.encodePacked(symbol).encodeBytes();
    elements[1] = tokenAddr.encodeAddress();
    elements[2] = amtBytes.encodeList();
    elements[3] = recipientBytes.encodeList();
    elements[4] = refundAddrBytes.encodeList();
    elements[5] = expireTime.encodeUint();
    return elements.encodeList();
  }

  function buildRefundPackage(address tokenAddr, uint256[] memory amounts, address[] memory recipients, uint32 status) internal pure returns (bytes memory) {
    uint256 length = amounts.length;
    bytes[] memory amtBytes = new bytes[](length);
    bytes[] memory recipientBytes = new bytes[](length);
    for (uint256 i; i < length; ++i) {
      amtBytes[i] = amounts[i].encodeUint();
      recipientBytes[i] = recipients[i].encodeAddress();
    }

    bytes[] memory elements = new bytes[](4);
    elements[0] = tokenAddr.encodeAddress();
    elements[1] = amtBytes.encodeList();
    elements[2] = recipientBytes.encodeList();
    elements[3] = status.encodeUint();
    return elements.encodeList();
  }

  function buildMirrorAckPackage(address sender, address tokenAddr, uint8 decimal, bytes32 symbol, uint256 mirrorFee, uint8 errCode) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](6);
    elements[0] = sender.encodeAddress();
    elements[1] = tokenAddr.encodeAddress();
    elements[2] = decimal.encodeUint();
    elements[3] = abi.encodePacked(symbol).encodeBytes();
    elements[4] = mirrorFee.encodeUint();
    elements[5] = errCode.encodeUint();
    return elements.encodeList();
  }

  function buildMirrorFailAckPackage(address sender, address tokenAddr, bytes32 name, uint8 decimal, bytes32 symbol, uint256 supply, uint256 mirrorFee, uint256 expireTime) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](8);
    elements[0] = sender.encodeAddress();
    elements[1] = tokenAddr.encodeAddress();
    elements[2] = abi.encodePacked(name).encodeBytes();
    elements[3] = abi.encodePacked(symbol).encodeBytes();
    elements[4] = supply.encodeUint();
    elements[5] = decimal.encodeUint();
    elements[6] = mirrorFee.encodeUint();
    elements[7] = expireTime.encodeUint();
    return elements.encodeList();
  }

  function buildSyncAckPackage(address sender, address tokenAddr, uint256 syncFee, uint8 errCode) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](6);
    elements[0] = sender.encodeAddress();
    elements[1] = tokenAddr.encodeAddress();
    elements[2] = syncFee.encodeUint();
    elements[3] = errCode.encodeUint();
    return elements.encodeList();
  }

  function buildSyncFailAckPackage(address sender, address tokenAddr, bytes32 symbol, uint256 supply, uint256 syncFee, uint256 expireTime) internal pure returns (bytes memory) {
    bytes[] memory elements = new bytes[](6);
    elements[0] = sender.encodeAddress();
    elements[1] = tokenAddr.encodeAddress();
    elements[2] = abi.encodePacked(symbol).encodeBytes();
    elements[3] = supply.encodeUint();
    elements[4] = syncFee.encodeUint();
    elements[5] = expireTime.encodeUint();
    return elements.encodeList();
  }
}
