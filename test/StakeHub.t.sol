pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

contract StakeHubTest is Deployer {
    address public poolImpl = 0xd2C6bAeDB1f32579c5b29f6FE34E0060FA9081b1;

    receive() external payable {}

    function setUp() public {
        bytes memory stakeHubCode = vm.getDeployedCode("StakeHub.sol");
        vm.etch(STAKEHUB_CONTRACT_ADDR, stakeHubCode);

        bytes memory poolCode = vm.getDeployedCode("StakePool.sol");
        vm.etch(poolImpl, poolCode);

        stakeHub.initialize();
    }

    function testCreateValidator() public {
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

        stakeHub.createValidator{value: 10000 ether}(consensusAddress, blsPubKey, blsProof, commission, description);
    }
}
