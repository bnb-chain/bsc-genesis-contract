pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

contract SystemRewardTest is Deployer {
    event rewardTo(address indexed to, uint256 amount);
    event rewardEmpty();

    function setUp() public { }

    function testReceive(uint256 amount) public {
        vm.assume(amount < 1e20);
        uint256 balance = address(systemReward).balance;

        payable(address(systemReward)).transfer(amount);
        assertEq(address(systemReward).balance, amount + balance);
    }

    function testOperator() public {
        assertTrue(systemReward.isOperator(LIGHT_CLIENT_ADDR), "light client should be operator");
        assertTrue(systemReward.isOperator(INCENTIVIZE_ADDR), "relayer incentivize should be operator");
        assertTrue(!systemReward.isOperator(_getNextUserAddress()), "address should not be operator");
    }

    function testClaimReward() public {
        address payable newAccount = _getNextUserAddress();

        payable(address(systemReward)).transfer(1 ether);
        vm.expectEmit(true, false, false, true, address(systemReward));
        emit rewardTo(newAccount, 1 ether);
        vm.prank(LIGHT_CLIENT_ADDR);
        systemReward.claimRewards(newAccount, 1 ether);

        vm.expectRevert("only operator is allowed to call the method");
        systemReward.claimRewards(newAccount, 1 ether);

        vm.deal(address(systemReward), 0);
        vm.expectEmit(false, false, false, false, address(systemReward));
        emit rewardEmpty();
        vm.prank(LIGHT_CLIENT_ADDR);
        systemReward.claimRewards(newAccount, 1 ether);
    }

    function testGov() public {
        bytes memory key = "addOperator";
        bytes memory valueBytes = abi.encodePacked(address(bscValidatorSet));
        vm.expectEmit(false, false, false, true, address(systemReward));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(systemReward));
        assertTrue(systemReward.isOperator(address(bscValidatorSet)));

        key = "deleteOperator";
        vm.expectEmit(false, false, false, true, address(systemReward));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(systemReward));
        assertFalse(systemReward.isOperator(address(bscValidatorSet)));
    }
}
