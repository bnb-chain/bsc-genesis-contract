pragma solidity ^0.8.10;

import "../lib/Deployer.sol";

contract RelayerHubTest is Deployer {
    event relayerRegister(address _relayer);
    event relayerUnRegister(address _relayer);
    event paramChange(string key, bytes value);

    uint256 public requiredDeposit;
    uint256 public dues;

    function setUp() public {
        requiredDeposit = relayerHub.requiredDeposit();
        dues = relayerHub.dues();
    }

    // new relayer register is suspended
    function testRegister() public {
        address newRelayer = addrSet[addrIdx++];
        vm.prank(newRelayer, newRelayer);
        vm.expectRevert(bytes("register suspended"));
        relayerHub.register{value : 100 ether}();
    }

    function testAddManager() public {
        address manager = payable(addrSet[addrIdx++]);
        address newRelayer = payable(addrSet[addrIdx++]);

        // testing if we can update "dues" param which is currently there on mainnet.
        // this works fine in forge test
        bytes memory keyDues = "dues";
        uint256 valueDues = 23;
        bytes memory testValueBytes = abi.encode(valueDues);
        updateParamByGovHub(keyDues, testValueBytes, address(relayerHub));

        // testing if we can update "addManager" param which is currently NOT there on mainnet but exists locally.
        // this gives error of "unknown param" in "forge test -vvvv --match-test testAddManager"
        bytes memory key = "addManager";
        bytes memory valueBytes = abi.encode(manager);
        updateParamByGovHub(key, valueBytes, address(relayerHub));

        // check if manager is there
        vm.prank(manager, manager);
        relayerHub.registerManagerAddRelayer(newRelayer);

    }

    //  function testCannotRegister() public {
    //    address newRelayer = addrSet[addrIdx++];
    //    vm.startPrank(newRelayer, newRelayer);
    //    relayerHub.register{value: 100 ether}();
    //
    //    // re-register
    //    vm.expectRevert(bytes("relayer already exist"));
    //    relayerHub.register{value: 100 ether}();
    //
    //    relayerHub.unregister();
    //    // re-unregister
    //    vm.expectRevert(bytes("relayer do not exist"));
    //    relayerHub.unregister();
    //
    //    vm.stopPrank();
    //    newRelayer = addrSet[addrIdx++];
    //    vm.startPrank(newRelayer, newRelayer);
    //
    //    // send 200 ether
    //    vm.expectRevert(bytes("deposit value is not exactly the same"));
    //    relayerHub.register{value: 200 ether}();
    //
    //    // send 10 ether
    //    vm.expectRevert(bytes("deposit value is not exactly the same"));
    //    relayerHub.register{value: 10 ether}();
    //  }
}
