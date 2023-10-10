pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

contract StakeHubTest is Deployer {
    address public poolImpl = 0xd2C6bAeDB1f32579c5b29f6FE34E0060FA9081b1;

    event ValidatorCreated(address indexed consensusAddress, address indexed operatorAddress, address indexed poolModule, bytes voteAddress);
//    event CommissionRateEdited(address indexed operatorAddress, uint256 commissionRate);
//    event ConsensusAddressEdited(address indexed oldAddress, address indexed newAddress);
//    event VoteAddressEdited(address indexed operatorAddress, bytes newVoteAddress);
//    event DescriptionEdited(address indexed operatorAddress);
//    event Delegated(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
//    event Undelegated(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
//    event Redelegated(address indexed srcValidator, address indexed dstValidator, address indexed delegator, uint256 bnbAmount);
//    event ValidatorSlashed(address indexed operatorAddress, uint256 slashAmount, uint256 slashHeight, uint256 jailUntil, SlashType slashType);
//    event ValidatorJailed(address indexed operatorAddress);
//    event ValidatorUnjailed(address indexed operatorAddress);
//    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
//    event StakingPaused();
//    event StakingResumed();
//    event paramChange(string key, bytes value);

    receive() external payable {}

    function setUp() public {
        bytes memory stakeHubCode = vm.getDeployedCode("StakeHub.sol");
        vm.etch(STAKEHUB_CONTRACT_ADDR, stakeHubCode);

        bytes memory poolCode = vm.getDeployedCode("StakePool.sol");
        vm.etch(poolImpl, poolCode);

        stakeHub.initialize();
    }

    function testCreateAndEditValidator() public {
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
        emit ValidatorCreated(consensusAddress, address(this), address(0), blsPubKey);
        stakeHub.createValidator{value: 10000 ether}(consensusAddress, blsPubKey, blsProof, commission, description);
    }
}
