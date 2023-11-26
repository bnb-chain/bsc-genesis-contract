pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

contract RelayerHubTest is Deployer {
    event relayerUpdated(address _from, address _to);
    event managerRemoved(address _manager);
    event relayerAddedProvisionally(address _relayer);

    function setUp() public { }

    function testAddManager() public {
        address manager = addNewManager();
        address newRelayer = _getNextUserAddress();

        // check if manager is there and can add a relayer
        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerAddedProvisionally(newRelayer);
        relayerHub.updateRelayer(newRelayer);
        assertFalse(relayerHub.isRelayer(newRelayer));

        vm.prank(newRelayer, newRelayer);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(payable(address(0)), newRelayer);
        relayerHub.acceptBeingRelayer(manager);

        // do updateRelayer() with the existing relayer
        vm.prank(manager, manager);
        vm.expectRevert(bytes("relayer already exists"));
        relayerHub.updateRelayer(newRelayer);

        // do illegal call
        vm.prank(newRelayer, newRelayer);
        vm.expectRevert(bytes("manager does not exist"));
        relayerHub.updateRelayer(manager);

        // check if relayer is added
        bool isRelayerTrue = relayerHub.isRelayer(newRelayer);
        assertTrue(isRelayerTrue);

        // check if manager is added
        bool isManagerTrue = relayerHub.isManager(manager);
        assertTrue(isManagerTrue);

        // set relayer to something else
        address newRelayer2 = _getNextUserAddress();
        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerAddedProvisionally(newRelayer2);
        relayerHub.updateRelayer(newRelayer2);
        assertFalse(relayerHub.isRelayer(newRelayer2));

        vm.prank(newRelayer2, newRelayer2);
        emit relayerUpdated(newRelayer, newRelayer2);
        relayerHub.acceptBeingRelayer(manager);

        // set relayer to 0
        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(newRelayer2, payable(address(0)));
        relayerHub.updateRelayer(payable(address(0)));

        // ensure 0 address is not a relayer
        assertFalse(relayerHub.isRelayer(address(0)));

        // remove manager test i.e. for removeManager()
        bytes memory keyRemoveManager = "removeManager";
        vm.expectEmit(true, true, false, true);
        emit managerRemoved(manager);
        bytes memory valueManagerBytes = abi.encodePacked(bytes20(uint160(manager)));
        _updateParamByGovHub(keyRemoveManager, valueManagerBytes, address(relayerHub));

        // check if relayer got removed
        bool isRelayerFalse = relayerHub.isRelayer(newRelayer2);
        assertFalse(isRelayerFalse);

        // check if manager got removed
        bool isManagerFalse = relayerHub.isManager(manager);
        assertFalse(isManagerFalse);

        // check if the manager can remove himself
        bytes memory keyAddManager = "addManager";
        _updateParamByGovHub(keyAddManager, valueManagerBytes, address(relayerHub));
        vm.prank(manager, manager);
        relayerHub.removeManagerByHimself();
    }

    function testRelayerAddingRemoving() public {
        address manager = addNewManager();
        address newRelayer = _getNextUserAddress();

        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerAddedProvisionally(newRelayer);
        relayerHub.updateRelayer(newRelayer);
        assertFalse(relayerHub.isRelayer(newRelayer));

        vm.prank(newRelayer, newRelayer);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(payable(address(0)), newRelayer);
        relayerHub.acceptBeingRelayer(manager);

        // set relayer to 0
        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(newRelayer, payable(address(0)));
        relayerHub.updateRelayer(payable(address(0)));

        // get a new manager, have its relayer registered and then try to remove the relayer for this manager
        address manager2 = addNewManager();
        address newRelayer2 = _getNextUserAddress();
        vm.prank(manager2, manager2);
        vm.expectEmit(true, true, false, true);
        emit relayerAddedProvisionally(newRelayer2);
        relayerHub.updateRelayer(newRelayer2);
        assertFalse(relayerHub.isRelayer(newRelayer2));

        vm.prank(newRelayer2, newRelayer2);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(payable(address(0)), newRelayer2);
        relayerHub.acceptBeingRelayer(manager2);

        // set relayer to 0
        vm.prank(manager2, manager2);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(newRelayer2, payable(address(0)));
        relayerHub.updateRelayer(payable(address(0)));
    }

    // this checks if the previously existing unregister() function can support safe exit for existing relayers after hardfork
    function testUnregister() public {
        address existingRelayer1 = 0xb005741528b86F5952469d80A8614591E3c5B632;
        vm.prank(existingRelayer1, existingRelayer1);
        relayerHub.unregister();

        address existingRelayer2 = 0x446AA6E0DC65690403dF3F127750da1322941F3e;
        vm.prank(existingRelayer2, existingRelayer2);
        relayerHub.unregister();

        address nonExistingRelayer = 0x9fB29AAc15b9A4B7F17c3385939b007540f4d791;
        vm.prank(nonExistingRelayer, nonExistingRelayer);
        vm.expectRevert(bytes("relayer do not exist"));
        relayerHub.unregister();
    }

    // deprecated test
    // this checks if the relayer transition can work after hardfork
    //  function testCurrentRelayerTransition() public {
    //    RelayerHub relayerHub = helperGetrelayerHub();
    //
    //    // an existing manager/relayer won't be shown to be valid since update() isn't called
    //    // note that for pre-hardfork, the relayer and manager are the same for simplicity
    //    address existingRelayer1 = 0xb005741528b86F5952469d80A8614591E3c5B632;
    //    bool isManagerFalse = relayerHub.isManager(existingRelayer1);
    //    assertFalse(isManagerFalse);
    //    bool isRelayerFalse = relayerHub.isRelayer(existingRelayer1);
    //    assertFalse(isRelayerFalse);
    //
    //    // now we call update() and the existing relayer/manager should be shown to be valid
    //    vm.expectEmit(true, true, false, true);
    //    emit relayerUpdated(payable(address(0)), relayerHub.WHITELIST_1());
    //    relayerHub.whitelistInit();
    //    bool isManagerTrue = relayerHub.isManager(existingRelayer1);
    //    assertTrue(isManagerTrue);
    //    bool isRelayerTrue = relayerHub.isRelayer(existingRelayer1);
    //    assertTrue(isRelayerTrue);
    //
    //    // for completeness, now we test that a non-existing address isn't a relayer or manager
    //    address nonExistingRelayer = 0x9fB29AAc15b9A4B7F17c3385939b007540f4d791;
    //    bool isManagerFalse2 = relayerHub.isManager(nonExistingRelayer);
    //    assertFalse(isManagerFalse2);
    //    bool isRelayerFalse2 = relayerHub.isRelayer(nonExistingRelayer);
    //    assertFalse(isRelayerFalse2);
    //  }

    //  // helperGetrelayerHub() deploys the new RelayerHub into the existing mainnet data so that we can test
    //  //  data compatibility
    //  function helperGetrelayerHub() internal returns (RelayerHub) {
    //    RelayerHub relayerHub;
    //
    //    bytes memory relayerCode = vm.getDeployedCode("RelayerHub.sol");
    //    vm.etch(RELAYERHUB_CONTRACT_ADDR, relayerCode);
    //    relayerHub = RelayerHub(RELAYERHUB_CONTRACT_ADDR);
    //
    //    return relayerHub;
    //  }

    // Helper function to add a new manager through RelayerHub
    function addNewManager() internal returns (address) {
        bytes memory keyAddManager = "addManager";
        address manager = _getNextUserAddress();
        bytes memory valueManagerBytes = abi.encodePacked(bytes20(uint160(manager)));
        require(valueManagerBytes.length == 20, "length of manager address mismatch in tests");
        _updateParamByGovHub(keyAddManager, valueManagerBytes, address(relayerHub));
        return manager;
    }

    function testRelayerAddingRemoving2() public {
        address manager = addNewManager();
        address newRelayer = _getNextUserAddress();

        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerAddedProvisionally(newRelayer);
        relayerHub.updateRelayer(newRelayer);
        assertFalse(relayerHub.isRelayer(newRelayer));

        vm.prank(newRelayer, newRelayer);
        emit relayerUpdated(payable(address(0)), newRelayer);
        relayerHub.acceptBeingRelayer(manager);

        address manager2 = addNewManager();
        address newRelayer2 = _getNextUserAddress();

        vm.prank(manager2, manager2);
        vm.expectEmit(true, true, false, true);
        emit relayerAddedProvisionally(newRelayer2);
        relayerHub.updateRelayer(newRelayer2);
        assertFalse(relayerHub.isRelayer(newRelayer2));

        vm.prank(newRelayer2, newRelayer2);
        emit relayerUpdated(payable(address(0)), newRelayer2);
        relayerHub.acceptBeingRelayer(manager2);

        // set relayer to 0 for first manager
        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(newRelayer, payable(address(0)));
        relayerHub.updateRelayer(payable(address(0)));

        // set relayer to 0 for second manager
        vm.prank(manager2, manager2);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(newRelayer2, payable(address(0)));
        relayerHub.updateRelayer(payable(address(0)));
    }

    function testContractRelayer() public {
        address manager = addNewManager();

        uint64 nonceManager = vm.getNonce(manager);

        address contractAddress = address(bytes20(keccak256(abi.encodePacked(manager, nonceManager))));

        // add the above address as relayer address which currently doesn't have code
        vm.prank(manager, manager);
        relayerHub.updateRelayer(contractAddress);

        bytes memory bytecode =
            "0x60606040525b600080fd00a165627a7a7230582012c9bd00152fa1c480f6827f81515bb19c3e63bf7ed9ffbb5fda0265983ac7980029";

        vm.etch(contractAddress, bytecode);

        assertEq(bytes32(bytecode), bytes32(address(contractAddress).code));

        // here because the added relayer hasn't done the second step, therefore it shouldn't be added as a relayer
        assertFalse(relayerHub.isRelayer(contractAddress));

        // check if a contract relayer fails
        vm.prank(contractAddress, contractAddress);
        vm.expectRevert(bytes("provisional relayer is a contract"));
        relayerHub.acceptBeingRelayer(manager);
    }

    function testProxyContractRelayer() public {
        address manager = addNewManager();

        uint64 nonceManager = vm.getNonce(manager);

        address contractAddress = address(bytes20(keccak256(abi.encodePacked(manager, nonceManager))));

        // add the above address as relayer address which currently doesn't have code
        vm.prank(manager, manager);
        relayerHub.updateRelayer(contractAddress);

        // here because the added relayer hasn't done the second step, therefore it shouldn't be added as a relayer
        assertFalse(relayerHub.isRelayer(contractAddress));

        // check if a proxy relayer fails
        vm.prank(contractAddress, manager);
        vm.expectRevert(bytes("provisional relayer is a proxy"));
        relayerHub.acceptBeingRelayer(manager);
    }

    // testManagerDeleteProvisionalRelayerRegistration checks the following scenario:
    // If a relayer is added provisionally and the manager gets deleted by governance BEFORE relayer registers itself
    //  then it shouldn't be able to register.
    function testManagerDeleteProvisionalRelayerRegistration() public {
        address manager = addNewManager();
        bytes memory valueManagerBytes = abi.encodePacked(bytes20(uint160(manager)));
        address newRelayer = _getNextUserAddress();

        // add the above address as relayer address which currently doesn't have code
        vm.prank(manager, manager);
        relayerHub.updateRelayer(newRelayer);

        // here because the added relayer hasn't done the second step, therefore it shouldn't be added as a relayer
        assertFalse(relayerHub.isRelayer(newRelayer));

        // now delete manager before the relayer accepts being a relayer
        bytes memory keyRemoveManager = "removeManager";
        _updateParamByGovHub(keyRemoveManager, valueManagerBytes, address(relayerHub));

        assertFalse(relayerHub.isProvisionalRelayer(newRelayer));

        // now the relayer tries to register itself which should fail as its manager is already removed
        vm.prank(newRelayer, newRelayer);
        vm.expectRevert(bytes("relayer is not a provisional relayer"));
        relayerHub.acceptBeingRelayer(manager);
        assertFalse(relayerHub.isRelayer(newRelayer));
    }

    function testDeleteProvisionalRelayerWhileRemovingRelayer() public {
        // Say a manager is there and adds its relayer provisionally and then decides to set it to address(0)
        // In this case the relayer is added as a provisional only and not full relayer
        // So the provisional relayer should also be deleted, especially if the relayer is yet to add itself as a full relayer
        address manager = addNewManager();
        address newRelayer = _getNextUserAddress();

        vm.prank(manager, manager);
        relayerHub.updateRelayer(newRelayer);
        assertTrue(relayerHub.isProvisionalRelayer(newRelayer));

        // Now remove the relayer and ensure that it is deleted being a provisional relayer as well
        vm.prank(manager, manager);
        relayerHub.updateRelayer(address(0));
        assertFalse(relayerHub.isProvisionalRelayer(newRelayer));
    }

    function testCorrectManagerForAcceptRelayer() public {
        address manager = addNewManager();
        address newRelayer = _getNextUserAddress();

        vm.prank(manager, manager);
        relayerHub.updateRelayer(newRelayer);
        assertTrue(relayerHub.isProvisionalRelayer(newRelayer));

        address randomManager = _getNextUserAddress();
        vm.prank(newRelayer, newRelayer);
        vm.expectRevert("provisional is not set for this manager");
        relayerHub.acceptBeingRelayer(randomManager);
    }
}
