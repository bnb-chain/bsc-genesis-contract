pragma solidity ^0.8.10;

import "../lib/Deployer.sol";

contract RelayerHubTest is Deployer {
    event relayerRegister(address _relayer);
    event relayerUnRegister(address _relayer);
    event paramChange(string key, bytes value);
    event relayerUpdated(address _from, address _to);
    event managerRemoved(address _manager);
    event managerAdded(address _manager);
    event relayerAddedProvisionally(address _relayer);

    uint256 public requiredDeposit;
    uint256 public dues;

    function setUp() public {
        requiredDeposit = relayerHub.requiredDeposit();
        dues = relayerHub.dues();
    }

    function testAddManager() public {
        RelayerHub newRelayerHub = helperGetNewRelayerHub();
        address manager = addNewManager(newRelayerHub);
        address newRelayer = payable(addrSet[addrIdx++]);

        // check if manager is there and can add a relayer
        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerAddedProvisionally(newRelayer);
        newRelayerHub.updateRelayer(newRelayer);
        assertFalse(newRelayerHub.isRelayer(newRelayer));

        vm.prank(newRelayer, newRelayer);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(payable(address(0)), newRelayer);
        newRelayerHub.acceptBeingRelayer(manager);

        // do updateRelayer() with the existing relayer
        vm.prank(manager, manager);
        vm.expectRevert(bytes("relayer already exists"));
        newRelayerHub.updateRelayer(newRelayer);

        // do illegal call
        vm.prank(newRelayer, newRelayer);
        vm.expectRevert(bytes("manager does not exist"));
        newRelayerHub.updateRelayer(manager);

        // check if relayer is added
        bool isRelayerTrue = newRelayerHub.isRelayer(newRelayer);
        assertTrue(isRelayerTrue);

        // check if manager is added
        bool isManagerTrue = newRelayerHub.isManager(manager);
        assertTrue(isManagerTrue);

        // set relayer to something else
        address newRelayer2 = payable(addrSet[addrIdx++]);
        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerAddedProvisionally(newRelayer2);
        newRelayerHub.updateRelayer(newRelayer2);
        assertFalse(newRelayerHub.isRelayer(newRelayer2));

        vm.prank(newRelayer2, newRelayer2);
        emit relayerUpdated(newRelayer, newRelayer2);
        newRelayerHub.acceptBeingRelayer(manager);

        // set relayer to 0
        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(newRelayer2, payable(address(0)));
        newRelayerHub.updateRelayer(payable(address(0)));

        // ensure 0 address is not a relayer
        assertFalse(newRelayerHub.isRelayer(address(0)));

        // remove manager test i.e. for removeManager()
        bytes memory keyRemoveManager = "removeManager";
        vm.expectEmit(true, true, false, true);
        emit managerRemoved(manager);
        bytes memory valueManagerBytes = abi.encodePacked(bytes20(uint160(manager)));
        updateParamByGovHub(keyRemoveManager, valueManagerBytes, address(newRelayerHub));

        // check if relayer got removed
        bool isRelayerFalse = newRelayerHub.isRelayer(newRelayer2);
        assertFalse(isRelayerFalse);

        // check if manager got removed
        bool isManagerFalse = newRelayerHub.isManager(manager);
        assertFalse(isManagerFalse);

        // check if the manager can remove himself
        bytes memory keyAddManager = "addManager";
        updateParamByGovHub(keyAddManager, valueManagerBytes, address(newRelayerHub));
        vm.prank(manager, manager);
        newRelayerHub.removeManagerByHimself();
    }

    function testRelayerAddingRemoving() public {
        RelayerHub newRelayerHub = helperGetNewRelayerHub();
        address manager = addNewManager(newRelayerHub);
        address newRelayer = payable(addrSet[addrIdx++]);

        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerAddedProvisionally(newRelayer);
        newRelayerHub.updateRelayer(newRelayer);
        assertFalse(newRelayerHub.isRelayer(newRelayer));

        vm.prank(newRelayer, newRelayer);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(payable(address(0)), newRelayer);
        newRelayerHub.acceptBeingRelayer(manager);

        // set relayer to 0
        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(newRelayer, payable(address(0)));
        newRelayerHub.updateRelayer(payable(address(0)));

        // get a new manager, have its relayer registered and then try to remove the relayer for this manager
        address manager2 = addNewManager(newRelayerHub);
        address newRelayer2 = payable(addrSet[addrIdx++]);
        vm.prank(manager2, manager2);
        vm.expectEmit(true, true, false, true);
        emit relayerAddedProvisionally(newRelayer2);
        newRelayerHub.updateRelayer(newRelayer2);
        assertFalse(newRelayerHub.isRelayer(newRelayer2));

        vm.prank(newRelayer2, newRelayer2);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(payable(address(0)), newRelayer2);
        newRelayerHub.acceptBeingRelayer(manager2);

        // set relayer to 0
        vm.prank(manager2, manager2);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(newRelayer2, payable(address(0)));
        newRelayerHub.updateRelayer(payable(address(0)));

    }

    // this checks if the previously existing unregister() function can support safe exit for existing relayers after hardfork
    function testunregister() public {
        RelayerHub newRelayerHub = helperGetNewRelayerHub();

        address existingRelayer1 = 0xb005741528b86F5952469d80A8614591E3c5B632;
        vm.prank(existingRelayer1, existingRelayer1);
        newRelayerHub.unregister();

        address existingRelayer2 = 0x446AA6E0DC65690403dF3F127750da1322941F3e;
        vm.prank(existingRelayer2, existingRelayer2);
        newRelayerHub.unregister();

        address nonExistingRelayer = 0x9fB29AAc15b9A4B7F17c3385939b007540f4d791;
        vm.prank(nonExistingRelayer, nonExistingRelayer);
        vm.expectRevert(bytes("relayer do not exist"));
        newRelayerHub.unregister();
    }

    function testCurrentRelayerTransition() public {
        RelayerHub newRelayerHub = helperGetNewRelayerHub();

        // an existing manager/relayer won't be shown to be valid since update() isn't called
        // note that for pre-hardfork, the relayer and manager are the same for simplicity
        address existingRelayer1 = 0xb005741528b86F5952469d80A8614591E3c5B632;
        bool isManagerFalse = newRelayerHub.isManager(existingRelayer1);
        assertFalse(isManagerFalse);
        bool isRelayerFalse = newRelayerHub.isRelayer(existingRelayer1);
        assertFalse(isRelayerFalse);


        // now we call update() and the existing relayer/manager should be shown to be valid
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(payable(address(0)), newRelayerHub.WHITELIST_1());
        newRelayerHub.whitelistInit();
        bool isManagerTrue = newRelayerHub.isManager(existingRelayer1);
        assertTrue(isManagerTrue);
        bool isRelayerTrue = newRelayerHub.isRelayer(existingRelayer1);
        assertTrue(isRelayerTrue);

        // for completeness, now we test that a non-existing address isn't a relayer or manager
        address nonExistingRelayer = 0x9fB29AAc15b9A4B7F17c3385939b007540f4d791;
        bool isManagerFalse2 = newRelayerHub.isManager(nonExistingRelayer);
        assertFalse(isManagerFalse2);
        bool isRelayerFalse2 = newRelayerHub.isRelayer(nonExistingRelayer);
        assertFalse(isRelayerFalse2);
    }

    // helperGetNewRelayerHub() deploys the new RelayerHub into the existing mainnet data so that we can test
    //  data compatibility
    function helperGetNewRelayerHub() internal returns (RelayerHub) {
        RelayerHub newRelayerHub;

        bytes memory relayerCode = vm.getDeployedCode("RelayerHub.sol");
        vm.etch(RELAYERHUB_CONTRACT_ADDR, relayerCode);
        newRelayerHub = RelayerHub(RELAYERHUB_CONTRACT_ADDR);

        return newRelayerHub;
    }

        // Helper function to add a new manager through RelayerHub
    function addNewManager(RelayerHub relayerHub) internal returns (address) {
        bytes memory keyAddManager = "addManager";
        address manager = payable(addrSet[addrIdx++]);
        bytes memory valueManagerBytes = abi.encodePacked(bytes20(uint160(manager)));
        require(valueManagerBytes.length == 20, "length of manager address mismatch in tests");
        updateParamByGovHub(keyAddManager, valueManagerBytes, address(relayerHub));
        return manager;
    }


    function testRelayerAddingRemoving2() public {
        RelayerHub newRelayerHub = helperGetNewRelayerHub();
        address manager = addNewManager(newRelayerHub);
        address newRelayer = payable(addrSet[addrIdx++]);

        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerAddedProvisionally(newRelayer);
        newRelayerHub.updateRelayer(newRelayer);
        assertFalse(newRelayerHub.isRelayer(newRelayer));

        vm.prank(newRelayer, newRelayer);
        emit relayerUpdated(payable(address(0)), newRelayer);
        newRelayerHub.acceptBeingRelayer(manager);

        address manager2 = addNewManager(newRelayerHub);
        address newRelayer2 = payable(addrSet[addrIdx++]);

        vm.prank(manager2, manager2);
        vm.expectEmit(true, true, false, true);
        emit relayerAddedProvisionally(newRelayer2);
        newRelayerHub.updateRelayer(newRelayer2);
        assertFalse(newRelayerHub.isRelayer(newRelayer2));

        vm.prank(newRelayer2, newRelayer2);
        emit relayerUpdated(payable(address(0)), newRelayer2);
        newRelayerHub.acceptBeingRelayer(manager2);

        // set relayer to 0 for first manager
        vm.prank(manager, manager);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(newRelayer, payable(address(0)));
        newRelayerHub.updateRelayer(payable(address(0)));


        // set relayer to 0 for second manager
        vm.prank(manager2, manager2);
        vm.expectEmit(true, true, false, true);
        emit relayerUpdated(newRelayer2, payable(address(0)));
        newRelayerHub.updateRelayer(payable(address(0)));

    }

    function testContractRelayer() public {
        RelayerHub newRelayerHub = helperGetNewRelayerHub();
        address manager = addNewManager(newRelayerHub);

        uint64 nonceManager = vm.getNonce(manager);

        address contractAddress = address(bytes20(keccak256(abi.encodePacked(manager, nonceManager))));

        // add the above address as relayer address which currently doesn't have code
        vm.prank(manager, manager);
        newRelayerHub.updateRelayer(contractAddress);

        bytes memory bytecode = "0x60606040525b600080fd00a165627a7a7230582012c9bd00152fa1c480f6827f81515bb19c3e63bf7ed9ffbb5fda0265983ac7980029";

        vm.etch(contractAddress, bytecode);

        assertEq(bytes32(bytecode), bytes32(address(contractAddress).code));

        // here because the added relayer hasn't done the second step, therefore it shouldn't be added as a relayer
        assertFalse(newRelayerHub.isRelayer(contractAddress));

        // check if a contract relayer fails
        vm.prank(contractAddress, contractAddress);
        vm.expectRevert(bytes("provisional relayer is a contract"));
        newRelayerHub.acceptBeingRelayer(manager);
    }

    function testProxyContractRelayer() public {
        RelayerHub newRelayerHub = helperGetNewRelayerHub();
        address manager = addNewManager(newRelayerHub);

        uint64 nonceManager = vm.getNonce(manager);

        address contractAddress = address(bytes20(keccak256(abi.encodePacked(manager, nonceManager))));

        // add the above address as relayer address which currently doesn't have code
        vm.prank(manager, manager);
        newRelayerHub.updateRelayer(contractAddress);

        // here because the added relayer hasn't done the second step, therefore it shouldn't be added as a relayer
        assertFalse(newRelayerHub.isRelayer(contractAddress));

        // check if a proxy relayer fails
        vm.prank(contractAddress, manager);
        vm.expectRevert(bytes("provisional relayer is a proxy"));
        newRelayerHub.acceptBeingRelayer(manager);

    }

    // testManagerDeleteProvisionalRelayerRegistration checks the following scenario:
    // If a relayer is added provisionally and the manager gets deleted by governance BEFORE relayer registers itself
    //  then it shouldn't be able to register.
    function testManagerDeleteProvisionalRelayerRegistration() public {
        RelayerHub newRelayerHub = helperGetNewRelayerHub();
        address manager = addNewManager(newRelayerHub);
        bytes memory valueManagerBytes = abi.encodePacked(bytes20(uint160(manager)));
        address newRelayer = payable(addrSet[addrIdx++]);

        // add the above address as relayer address which currently doesn't have code
        vm.prank(manager, manager);
        newRelayerHub.updateRelayer(newRelayer);

        // here because the added relayer hasn't done the second step, therefore it shouldn't be added as a relayer
        assertFalse(newRelayerHub.isRelayer(newRelayer));

        // now delete manager before the relayer accepts being a relayer
        bytes memory keyRemoveManager = "removeManager";
        updateParamByGovHub(keyRemoveManager, valueManagerBytes, address(newRelayerHub));

        assertFalse(newRelayerHub.isProvisionalRelayer(newRelayer));

        // now the relayer tries to register itself which should fail as its manager is already removed
        vm.prank(newRelayer, newRelayer);
        vm.expectRevert(bytes("relayer is not a provisional relayer"));
        newRelayerHub.acceptBeingRelayer(manager);
        assertFalse(newRelayerHub.isRelayer(newRelayer));

    }

    function testDeleteProvisionalRelayerWhileRemovingRelayer() public {
        // Say a manager is there and adds its relayer provisionally and then decides to set it to address(0)
        // In this case the relayer is added as a provisional only and not full relayer
        // So the provisional relayer should also be deleted, especially if the relayer is yet to add itself as a full relayer
        RelayerHub newRelayerHub = helperGetNewRelayerHub();
        address manager = addNewManager(newRelayerHub);
        address newRelayer = payable(addrSet[addrIdx++]);

        vm.prank(manager, manager);
        newRelayerHub.updateRelayer(newRelayer);
        assertTrue(newRelayerHub.isProvisionalRelayer(newRelayer));

        // Now remove the relayer and ensure that it is deleted being a provisional relayer as well
        vm.prank(manager, manager);
        newRelayerHub.updateRelayer(address(0));
        assertFalse(newRelayerHub.isProvisionalRelayer(newRelayer));
    }

    function testCorrectManagerForAcceptRelayer() public {
        RelayerHub newRelayerHub = helperGetNewRelayerHub();
        address manager = addNewManager(newRelayerHub);
        address newRelayer = payable(addrSet[addrIdx++]);

        vm.prank(manager, manager);
        newRelayerHub.updateRelayer(newRelayer);
        assertTrue(newRelayerHub.isProvisionalRelayer(newRelayer));

        address randomManager = payable(addrSet[addrIdx++]);
        vm.prank(newRelayer, newRelayer);
        vm.expectRevert("provisional is not set for this manager");
        newRelayerHub.acceptBeingRelayer(randomManager);

    }

}
