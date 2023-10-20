pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./utils/Deployer.sol";

interface IStakePool {
    function balanceOf(address account) external view returns (uint256);
    function totalPooledBNB() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function getPooledBNBByShares(uint256 shares) external view returns (uint256);
    function getSharesByPooledBNB(uint256 bnbAmount) external view returns (uint256);
    function remainingSlashBnbAmount() external view returns (uint256);
    function payFine() external payable;
}

contract MockGovBNB is ERC20 {
    constructor() ERC20("MockGovBNB", "MockGovBNB") {}

    function mint(address validator, address delegator, uint256 amount) external {
        _mint(delegator, amount);
    }

    function burn(address validator, address delegator, uint256 amount) external {
        amount = amount < balanceOf(delegator) ? amount : balanceOf(delegator);
        _burn(delegator, amount);
    }
}

contract StakeHubTest is Deployer {
    address public govBNB = address(0xdead01);
    address public poolImpl = address(0xdead02);

    event ValidatorCreated(address indexed consensusAddress, address indexed operatorAddress, address indexed poolModule, bytes voteAddress);
    event ConsensusAddressEdited(address indexed operatorAddress, address indexed oldAddress, address indexed newAddress);
    event CommissionRateEdited(address indexed operatorAddress, uint64 commissionRate);
    event DescriptionEdited(address indexed operatorAddress);
    event VoteAddressEdited(address indexed operatorAddress, bytes newVoteAddress);
    event Delegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event Undelegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event Redelegated(address indexed srcValidator, address indexed dstValidator, address indexed delegator, uint256 oldShares, uint256 newShares, uint256 bnbAmount);
    event RewardDistributed(address indexed operatorAddress, uint256 reward);
    event ValidatorSlashed(address indexed operatorAddress, uint256 jailUntil, uint256 slashAmount, uint248 slashHeight, uint8 slashType);
    event ValidatorJailed(address indexed operatorAddress);
    event ValidatorUnjailed(address indexed operatorAddress);
    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event PayFine(uint256 fine);

    receive() external payable {}

    function setUp() public {
        bytes memory stakeHubCode = vm.getDeployedCode("StakeHub.sol");
        vm.etch(STAKEHUB_CONTRACT_ADDR, stakeHubCode);

        bytes memory poolCode = vm.getDeployedCode("StakePool.sol");
        vm.etch(poolImpl, poolCode);

        address mockGovBNB = address(new MockGovBNB());
        vm.etch(govBNB, mockGovBNB.code);

        stakeHub.initialize();
    }

    function testCreateAndEditValidator() public {
        // 1. create validator
        (address validator, ) = _createValidator(2000 ether);
        vm.startPrank(validator);

        // 2. edit consensus address
        vm.warp(block.timestamp + 1 days);
        (address consensusAddress, , , , ) = stakeHub.getValidatorBasicInfo(validator);
        address newConsensusAddress = address(0x1234);
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit ConsensusAddressEdited(validator, consensusAddress, newConsensusAddress);
        stakeHub.editConsensusAddress(newConsensusAddress);
        (address realAddr, , , , ) = stakeHub.getValidatorBasicInfo(validator);
        assertEq(realAddr, newConsensusAddress);

        // 3. edit commission rate
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(bytes("INVALID_COMMISSION_RATE"));
        stakeHub.editCommissionRate(110);
        vm.expectRevert(bytes("INVALID_COMMISSION_CHANGE_RATE"));
        stakeHub.editCommissionRate(16);
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit CommissionRateEdited(validator, 15);
        stakeHub.editCommissionRate(15);
        StakeHub.Commission memory realComm = stakeHub.getValidatorCommission(validator);
        assertEq(realComm.rate, 15);

        // 4. edit description
        vm.warp(block.timestamp + 1 days);
        StakeHub.Description memory description = stakeHub.getValidatorDescription(validator);
        description.moniker = "test";
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit DescriptionEdited(validator);
        stakeHub.editDescription(description);
        StakeHub.Description memory realDesc = stakeHub.getValidatorDescription(validator);
        assertEq(realDesc.moniker, "test");

        // 5. edit vote address
        vm.warp(block.timestamp + 1 days);
        bytes memory newVoteAddress = hex"1234";
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit VoteAddressEdited(validator, newVoteAddress);
        stakeHub.editVoteAddress(newVoteAddress, bytes(""));
        (, , bytes memory realVoteAddr, , ) = stakeHub.getValidatorBasicInfo(validator);
        assertEq(realVoteAddr, newVoteAddress);

        vm.stopPrank();
    }

    function testDelegate() public {
        address delegator = addrSet[addrIdx++];
        (address validator, address pool) = _createValidator(2000 ether);
        vm.startPrank(delegator);

        // failed with too small delegation amount
        vm.expectRevert(bytes("INVALID_DELEGATION_AMOUNT"));
        stakeHub.delegate{value: 1}(validator);

        // success case
        uint256 bnbAmount = 100 ether;
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit Delegated(validator, delegator, bnbAmount, bnbAmount);
        stakeHub.delegate{value: bnbAmount}(validator);
        uint256 shares = IStakePool(pool).balanceOf(delegator);
        assertEq(shares, bnbAmount);

        vm.stopPrank();
    }

    function testUndelegate() public {
        address delegator = addrSet[addrIdx++];
        (address validator, address pool)= _createValidator(2000 ether);
        vm.startPrank(delegator);

        uint256 bnbAmount = 100 ether;
        stakeHub.delegate{value: bnbAmount}(validator);
        uint256 shares = IStakePool(pool).balanceOf(delegator);

        // failed with too small undelegation amount
        vm.expectRevert(bytes("INVALID_UNDELEGATION_AMOUNT"));
        stakeHub.undelegate(validator, 1);

        // failed with not enough shares
        vm.expectRevert(bytes("INSUFFICIENT_BALANCE"));
        stakeHub.undelegate(validator, shares + 1);

        // success case
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit Undelegated(validator, delegator, shares/2, bnbAmount/2);
        stakeHub.undelegate(validator, shares/2);

        // claim failed
        vm.expectRevert(bytes("NO_CLAIMABLE_UNBOND_REQUEST"));
        stakeHub.claim(validator, 0);

        // claim success
        vm.warp(block.timestamp + 7 days);
        uint256 balanceBefore = delegator.balance;
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit Claimed(validator, delegator, bnbAmount/2);
        stakeHub.claim(validator, 0);
        uint256 balanceAfter = delegator.balance;
        assertEq(balanceAfter - balanceBefore, bnbAmount/2);

        vm.stopPrank();
    }

    function testRedelegate() public {
        address delegator = addrSet[addrIdx++];
        (address validator1, address pool1)= _createValidator(2000 ether);
        (address validator2, address pool2)= _createValidator(2000 ether);
        vm.startPrank(delegator);

        uint256 bnbAmount = 100 ether;
        stakeHub.delegate{value: bnbAmount}(validator1);
        uint256 oldShares = IStakePool(pool1).balanceOf(delegator);

        // failed with too small redelegation amount
        vm.expectRevert(bytes("INVALID_REDELEGATION_AMOUNT"));
        stakeHub.redelegate(validator1, validator2, 1);

        // failed with not enough shares
        vm.expectRevert(bytes("INSUFFICIENT_BALANCE"));
        stakeHub.redelegate(validator1, validator2, oldShares + 1);

        // success case
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit Redelegated(validator1, validator2, delegator, oldShares, oldShares, bnbAmount);
        stakeHub.redelegate(validator1, validator2, oldShares);
        uint256 newShares = IStakePool(pool2).balanceOf(delegator);
        assertEq(newShares, oldShares);

        vm.stopPrank();
    }

    function testDistributeReward() public {
        address delegator = addrSet[addrIdx++];
        uint256 selfDelegation = 2000 ether;
        (address validator, address pool)= _createValidator(selfDelegation);

        // 1. delegate 100 BNB and get 100 * 1e18 shares
        uint256 delegation = 100 ether;
        vm.prank(delegator);
        stakeHub.delegate{value: delegation}(validator);
        uint256 shares = IStakePool(pool).balanceOf(delegator);
        assertEq(shares, delegation);

        // 2. distribute reward
        uint256 reward = 100 ether;
        (address consensusAddress, , , , ) = stakeHub.getValidatorBasicInfo(validator);
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit RewardDistributed(validator, reward);
        vm.prank(VALIDATOR_CONTRACT_ADDR);
        stakeHub.distributeReward{value: reward}(consensusAddress);

        // 3. check shares
        // reward: 100 ether
        // commissionToValidator: reward(100 ether) * commissionRate(10/10000) = 0.1 ether
        // preTotalPooledBNB: selfDelegation(2000 ether) + delegation(100 ether) + (reward - commissionToValidator)(99.9 ether) = 2199.9 ether
        // preTotalShares: selfDelegation(2000 ether) + delegation(100 ether)
        // curTotalShares: preTotalShares + commissionToValidator * preTotalShares  / preTotalPooledBNB = 2100095458884494749761
        // curTotalPooledBNB: preTotalPooledBNB + commissionToValidator = 2200 ether
        // expectedBnbAmount: shares(100 ether) * curTotalPooledBNB / curTotalShares
        uint256 expectedBnbAmount = shares * 2200 ether / 2100095458884494749761;
        uint256 realBnbAmount = IStakePool(pool).getPooledBNBByShares(shares);
        assertEq(realBnbAmount, expectedBnbAmount);

        // 4. undelegate and submit new delegate
        vm.prank(delegator);
        stakeHub.undelegate(validator, shares);

        // totalShares: 2100095458884494749761 - 100 ether
        // totalPooledBNB: 2200 ether - (100 ether + 99.9 ether * 100 / 2000 ) = 2095242857142857142858
        // newShares: 100 ether * totalShares / totalPooledBNB
        uint256 _totalPooledBNB = IStakePool(pool).totalPooledBNB();
        assertEq(_totalPooledBNB, 2095242857142857142858);
        uint256 expectedShares = 100 ether * 2000095458884494749761 / _totalPooledBNB;
        address newDelegator = addrSet[addrIdx++];
        vm.prank(newDelegator);
        stakeHub.delegate{value: delegation}(validator);
        uint256 newShares = IStakePool(pool).balanceOf(newDelegator);
        assertEq(newShares, expectedShares);
    }

    function testDowntimeSlash() public {
        // totalShares: 2000095242630601457212
        // totalPooledBNB: 2100 ether
        uint256 selfDelegation = 2000 ether;
        uint256 reward = 100 ether;
        (address validator, address pool)= _createValidator(selfDelegation);

        address delegator = addrSet[addrIdx++];
        vm.prank(delegator);
        stakeHub.delegate{value: 100 ether}(validator);

        (address consensusAddress, , , , ) = stakeHub.getValidatorBasicInfo(validator);
        vm.prank(VALIDATOR_CONTRACT_ADDR);
        stakeHub.distributeReward{value: reward}(consensusAddress);

        uint256 preDelegatorBnbAmount = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(delegator));
        uint256 preValidatorBnbAmount = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(validator));

        vm.startPrank(SLASH_CONTRACT_ADDR);

        // downtime slash type: 1
        uint256 slashAmt = stakeHub.downtimeSlashAmount();
        uint256 slashTime = stakeHub.downtimeJailTime();
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit ValidatorSlashed(validator, block.timestamp + slashTime, slashAmt, uint248(block.number), 1);
        stakeHub.downtimeSlash(consensusAddress, block.number);
        uint256 curValidatorBnbAmount = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(validator));
        assertEq(preValidatorBnbAmount, curValidatorBnbAmount + slashAmt);

        // check delegator's share
        uint256 curDelegatorBnbAmount = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(delegator));
        assertApproxEqAbs(preDelegatorBnbAmount, curDelegatorBnbAmount, 1); // there may be 1 delta due to the precision

        // slash again failed
        vm.expectRevert(bytes("SLASHED"));
        stakeHub.downtimeSlash(consensusAddress, block.number);

        // unjail
        ( , , , bool jailed, ) = stakeHub.getValidatorBasicInfo(validator);
        assertEq(jailed, true);
        vm.expectRevert(bytes("STILL_JAILED"));
        stakeHub.unjail(validator);
        vm.warp(block.timestamp + slashTime + 1);
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit ValidatorUnjailed(validator);
        stakeHub.unjail(validator);
        ( , , , jailed, ) = stakeHub.getValidatorBasicInfo(validator);
        assertEq(jailed, false);

        vm.stopPrank();
    }

    function testDoubleSignSlash() public {
        // totalShares: 2000095242630601457212
        // totalPooledBNB: 2100 ether
        uint256 selfDelegation = 2000 ether;
        uint256 reward = 100 ether;
        (address validator, address pool)= _createValidator(selfDelegation);

        address delegator = addrSet[addrIdx++];
        vm.prank(delegator);
        stakeHub.delegate{value: 100 ether}(validator);

        (address consensusAddress, , , , ) = stakeHub.getValidatorBasicInfo(validator);
        vm.prank(VALIDATOR_CONTRACT_ADDR);
        stakeHub.distributeReward{value: reward}(consensusAddress);

        uint256 preDelegatorBnbAmount = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(delegator));

        vm.startPrank(SLASH_CONTRACT_ADDR);

        // double sign slash type: 0
        uint256 slashAmt = stakeHub.doubleSignSlashAmount(); // 10_000 ether is more than selfDelegation
        uint256 slashTime = stakeHub.doubleSignJailTime();
        uint256 validatorBnbAmount = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(validator));
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit ValidatorSlashed(validator, block.timestamp + slashTime, validatorBnbAmount, uint248(block.number), 0);
        stakeHub.doubleSignSlash(consensusAddress, block.number, block.timestamp - 1);

        // check delegator's share
        uint256 curDelegatorBnbAmount = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(delegator));
        assertApproxEqAbs(preDelegatorBnbAmount, curDelegatorBnbAmount, 1); // there may be 1 delta due to the precision

        // check remaining fine
        uint256 expectedRemainingFine = slashAmt - validatorBnbAmount;
        assertEq(IStakePool(pool).remainingSlashBnbAmount(), expectedRemainingFine);
    }

    function testMaliciousVoteSlash() public {
        // totalShares: 2000095242630601457212
        // totalPooledBNB: 2100 ether
        uint256 selfDelegation = 2000 ether;
        uint256 reward = 100 ether;
        (address validator, address pool)= _createValidator(selfDelegation);

        address delegator = addrSet[addrIdx++];
        vm.prank(delegator);
        stakeHub.delegate{value: 100 ether}(validator);

        (address consensusAddress, , bytes memory voteAddr, , ) = stakeHub.getValidatorBasicInfo(validator);
        vm.prank(VALIDATOR_CONTRACT_ADDR);
        stakeHub.distributeReward{value: reward}(consensusAddress);

        uint256 preDelegatorBnbAmount = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(delegator));

        vm.startPrank(SLASH_CONTRACT_ADDR);

        // malicious vote slash type: 2
        uint256 slashAmt = stakeHub.doubleSignSlashAmount(); // 10_000 ether is more than selfDelegation
        uint256 slashTime = stakeHub.doubleSignJailTime();
        uint256 validatorBnbAmount = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(validator));
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit ValidatorSlashed(validator, block.timestamp + slashTime, validatorBnbAmount, uint248(block.number), 2);
        stakeHub.maliciousVoteSlash(voteAddr, block.number);

        // check delegator's share
        uint256 curDelegatorBnbAmount = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(delegator));
        assertApproxEqAbs(preDelegatorBnbAmount, curDelegatorBnbAmount, 1); // there may be 1 delta due to the precision

        // check remaining fine
        uint256 expectedRemainingFine = slashAmt - validatorBnbAmount;
        assertEq(IStakePool(pool).remainingSlashBnbAmount(), expectedRemainingFine);
    }

    function testPayFine() public {
        // totalShares: 2000095242630601457212
        // totalPooledBNB: 2100 ether
        uint256 selfDelegation = 2000 ether;
        uint256 reward = 100 ether;
        (address validator, address pool)= _createValidator(selfDelegation);

        address delegator = addrSet[addrIdx++];
        vm.prank(delegator);
        stakeHub.delegate{value: 100 ether}(validator);

        (address consensusAddress, , , , ) = stakeHub.getValidatorBasicInfo(validator);
        vm.prank(VALIDATOR_CONTRACT_ADDR);
        stakeHub.distributeReward{value: reward}(consensusAddress);

        uint256 preDelegatorBnbAmount = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(delegator));

        // undelegate all and slash
        uint256 shares = IStakePool(pool).balanceOf(validator);
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit ValidatorJailed(validator);
        vm.prank(validator);
        stakeHub.undelegate(validator, shares - 1);
        vm.roll(block.number + 1);
        vm.prank(SLASH_CONTRACT_ADDR);
        stakeHub.downtimeSlash(consensusAddress, block.number);

        // check delegator's share
        uint256 curDelegatorBnbAmount = IStakePool(pool).getPooledBNBByShares(IStakePool(pool).balanceOf(delegator));
        assertApproxEqAbs(preDelegatorBnbAmount, curDelegatorBnbAmount, 1); // there may be 1 delta due to the precision

        // claim undelegate fund failed
        vm.warp(block.timestamp + 7 days);
        vm.expectRevert(bytes("VALIDATOR_FROZEN"));
        vm.startPrank(validator);
        stakeHub.claim(validator, 0);

        // pay fine and claim success
        uint256 fine = IStakePool(pool).remainingSlashBnbAmount();
        vm.expectEmit(true, false, false, true, pool);
        emit PayFine(fine);
        IStakePool(pool).payFine{value: fine}();
        vm.expectEmit(true, true, false, false, address(stakeHub)); // no check for amount
        emit Claimed(validator, validator, 0);
        stakeHub.claim(validator, 0);

        vm.stopPrank();
    }

    function testMoniker() public {
        string memory moniker = "test";
        assertFalse(_checkMoniker(moniker));
        moniker = "test12345";
        assertFalse(_checkMoniker(moniker));
        moniker = "test:";
        assertFalse(_checkMoniker(moniker));
        moniker = "test ";
        assertFalse(_checkMoniker(moniker));

        moniker = "Test";
        assertTrue(_checkMoniker(moniker));
        moniker = "Test123";
        assertTrue(_checkMoniker(moniker));
    }

    function _checkMoniker(string memory moniker) internal pure returns (bool) {
        bytes memory bz = bytes(moniker);

        // 1. moniker length should be between 1 and 9
        if (bz.length == 0 || bz.length > 9) {
            return false;
        }

        // 2. first character should be uppercase
        if (uint8(bz[0]) < 65 || uint8(bz[0]) > 90) {
            return false;
        }

        // 3. only alphanumeric characters are allowed
        for (uint256 i = 1; i < bz.length; ++i) {
            // Check if the ASCII value of the character falls outside the range of alphanumeric characters
            if (
                (uint8(bz[i]) < 48 || uint8(bz[i]) > 57) &&
                (uint8(bz[i]) < 65 || uint8(bz[i]) > 90) &&
                (uint8(bz[i]) < 97 || uint8(bz[i]) > 122)
            ) {
                // Character is a special character
                return false;
            }
        }

        // No special characters found
        return true;
    }

    function _createValidator(uint256 delegation) internal returns (address operatorAddress, address pool) {
        operatorAddress = addrSet[addrIdx++];
        StakeHub.Commission memory commission = StakeHub.Commission({
            rate: 10,
            maxRate: 100,
            maxChangeRate: 5
        });
        StakeHub.Description memory description = StakeHub.Description({
            moniker: string.concat("T", vm.toString(uint24(uint160(operatorAddress)))),
            identity: vm.toString(operatorAddress),
            website: vm.toString(operatorAddress),
            details: vm.toString(operatorAddress)
        });
        bytes memory blsPubKey = abi.encodePacked(operatorAddress);
        address consensusAddress = address(uint160(uint256(keccak256(blsPubKey))));

        vm.prank(operatorAddress);
        stakeHub.createValidator{value: delegation}(consensusAddress, blsPubKey, bytes(""), commission, description);

        (, pool, , , ) = stakeHub.getValidatorBasicInfo(operatorAddress);
    }
}
