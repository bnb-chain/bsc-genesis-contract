pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

interface IStakePool {
    function balanceOf(address account) external view returns (uint256);
}

contract StakeHubTest is Deployer {
    address public poolImpl = 0xd2C6bAeDB1f32579c5b29f6FE34E0060FA9081b1;

    event ValidatorCreated(address indexed consensusAddress, address indexed operatorAddress, address indexed poolModule, bytes voteAddress);
    event ConsensusAddressEdited(address indexed oldAddress, address indexed newAddress);
    event CommissionRateEdited(address indexed operatorAddress, uint256 commissionRate);
    event DescriptionEdited(address indexed operatorAddress);
    event VoteAddressEdited(address indexed operatorAddress, bytes newVoteAddress);
    event Delegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event Undelegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event Redelegated(address indexed srcValidator, address indexed dstValidator, address indexed delegator, uint256 bnbAmount);
    event ValidatorSlashed(address indexed operatorAddress, uint256 slashAmount, uint256 slashHeight, uint256 jailUntil, uint8 slashType);
    event ValidatorJailed(address indexed operatorAddress);
    event ValidatorUnjailed(address indexed operatorAddress);
    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event StakingPaused();
    event StakingResumed();
    event paramChange(string key, bytes value);

    receive() external payable {}

    function setUp() public {
        bytes memory stakeHubCode = vm.getDeployedCode("StakeHub.sol");
        vm.etch(STAKEHUB_CONTRACT_ADDR, stakeHubCode);

        bytes memory poolCode = vm.getDeployedCode("StakePool.sol");
        vm.etch(poolImpl, poolCode);

        stakeHub.initialize();
    }

    function testCreateAndEditValidator() public {
        // 1. create validator
        StakeHub.Commission memory commission = StakeHub.Commission({
            rate: 10,
            maxRate: 16,
            maxChangeRate: 5
        });
        StakeHub.Description memory description = StakeHub.Description({
            moniker: "test",
            identity: "test",
            website: "test",
            details: "test"
        });
        bytes memory blsPubKey = hex"1234";
        bytes memory blsProof = hex"1234";
        address consensusAddress = address(0x1234);

        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit ValidatorCreated(consensusAddress, address(this), address(0), blsPubKey);
        stakeHub.createValidator{value: 10000 ether}(consensusAddress, blsPubKey, blsProof, commission, description, "TEST");

        // 2. edit consensus address
        vm.warp(block.timestamp + 1 days);
        address newConsensusAddress = address(0x5678);
        vm.expectEmit(true, true, false, true, address(stakeHub));
        emit ConsensusAddressEdited(consensusAddress, newConsensusAddress);
        stakeHub.editConsensusAddress(newConsensusAddress);
        (address realAddr, , , , ) = stakeHub.getValidatorBasicInfo(address(this));
        assertEq(realAddr, newConsensusAddress);

        // 3. edit commission rate
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(bytes("INVALID_COMMISSION_RATE"));
        stakeHub.editCommissionRate(20);
        vm.expectRevert(bytes("INVALID_COMMISSION_CHANGE_RATE"));
        stakeHub.editCommissionRate(16);
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit CommissionRateEdited(address(this), 15);
        stakeHub.editCommissionRate(15);
        StakeHub.Commission memory realComm = stakeHub.getValidatorCommission(address(this));
        assertEq(realComm.rate, 15);

        // 4. edit description
        vm.warp(block.timestamp + 1 days);
        description.moniker = "test2";
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit DescriptionEdited(address(this));
        stakeHub.editDescription(description);
        StakeHub.Description memory realDesc = stakeHub.getValidatorDescription(address(this));
        assertEq(realDesc.moniker, "test2");

        // 5. edit vote address
        vm.warp(block.timestamp + 1 days);
        bytes memory newVoteAddress = hex"5678";
        vm.expectEmit(true, false, false, true, address(stakeHub));
        emit VoteAddressEdited(address(this), newVoteAddress);
        stakeHub.editVoteAddress(newVoteAddress, blsProof);
        (, , bytes memory realVoteAddr, , ) = stakeHub.getValidatorBasicInfo(address(this));
        assertEq(realVoteAddr, newVoteAddress);
    }

    function testDelegate() public {
        address validator = addrSet[addrIdx++];
        address delegator = addrSet[addrIdx++];

        // create validator
        StakeHub.Commission memory commission = StakeHub.Commission({
            rate: 10,
            maxRate: 100,
            maxChangeRate: 5
        });
        StakeHub.Description memory description = StakeHub.Description({
            moniker: "test",
            identity: "test",
            website: "test",
            details: "test"
        });
        bytes memory blsPubKey = hex"1234";
        bytes memory blsProof = hex"1234";
        address consensusAddress = address(0x1234);

        vm.expectEmit(true, true, false, true, address(stakeHub));
        vm.prank(validator);
        emit ValidatorCreated(consensusAddress, validator, address(0), blsPubKey);
        stakeHub.createValidator{value: 2000 ether}(consensusAddress, blsPubKey, blsProof, commission, description, "TEST");
        (, address pool, , , ) = stakeHub.getValidatorBasicInfo(validator);

        // 1. delegate
        // failed with too small delegation amount
        vm.expectRevert(bytes("INVALID_DELEGATION_AMOUNT"));
        vm.prank(delegator);
        stakeHub.delegate{value: 1}(validator);

        // success case
        uint256 bnbAmount = 100 ether;
        vm.expectEmit(true, true, false, true, address(stakeHub));
        vm.prank(delegator);
        emit Delegated(validator, delegator, bnbAmount, bnbAmount);
        stakeHub.delegate{value: bnbAmount}(validator);
        uint256 shares = IStakePool(pool).balanceOf(delegator);
        assertEq(shares, bnbAmount);

        // 2. undelegate
        // failed with too small undelegation amount
        vm.expectRevert(bytes("INVALID_UNDELEGATION_AMOUNT"));
        vm.prank(delegator);
        stakeHub.undelegate(validator, 1);

        // failed with not enough shares
        vm.expectRevert(bytes("INSUFFICIENT_BALANCE"));
        vm.prank(delegator);
        stakeHub.undelegate(validator, shares + 1);

        // success case
        vm.expectEmit(true, true, false, true, address(stakeHub));
        vm.prank(delegator);
        emit Undelegated(validator, delegator, shares/2, bnbAmount/2);
        stakeHub.undelegate(validator, shares/2);
    }
}
