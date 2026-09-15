pragma solidity ^0.8.17;

import "forge-std/Test.sol";

interface IBEP714ValidatorSet {
    function init() external;
    function tryEnterMaintenance(
        address validator
    ) external;
    function enterMaintenance() external;
    function exitMaintenance() external;
    function updateParam(string calldata key, bytes calldata value) external;
    function getValidators() external view returns (address[] memory);
    function isCurrentValidator(
        address validator
    ) external view returns (bool);
    function getWorkingValidatorCount() external view returns (uint256);
    function getCurrentValidatorIndex(
        address validator
    ) external view returns (uint256);
    function validatorExtraSet(
        uint256 index
    ) external view returns (uint256, bool, bytes memory);
    function getIncoming(
        address validator
    ) external view returns (uint256);
    function deposit(
        address validator
    ) external payable;
    function updateValidatorSetV2(
        address[] calldata validators,
        uint64[] calldata powers,
        bytes[] calldata votes
    ) external;
}

interface IBEP714SlashIndicator {
    function init() external;
    function slash(
        address validator
    ) external;
    function updateParam(string calldata key, bytes calldata value) external;
    function maintenanceThreshold() external view returns (uint256);
    function getSlashIndicator(
        address validator
    ) external view returns (uint256, uint256);
}

// Runs against real system-contract bytecode and fresh storage, without an RPC fork.
contract BEP714Test is Test {
    IBEP714ValidatorSet internal validators = IBEP714ValidatorSet(address(0x1000));
    IBEP714SlashIndicator internal slash = IBEP714SlashIndicator(address(0x1001));
    address internal constant GOV = address(0x1007);
    address internal constant PRODUCER = address(0xbeef);
    address[] internal members;

    function setUp() public {
        vm.roll(1);
        vm.coinbase(PRODUCER);
        vm.txGasPrice(0);
        vm.deal(PRODUCER, 100 ether);
        vm.etch(address(validators), vm.getDeployedCode("BSCValidatorSet.sol:BSCValidatorSet"));
        vm.etch(address(slash), vm.getDeployedCode("SlashIndicator.sol:SlashIndicator"));
        // Downtime jail and reward distribution are tested separately in StakeHub.
        vm.etch(address(0x2002), hex"00");
        vm.mockCall(address(0x2002), abi.encodeWithSignature("consensusToOperator(address)"), abi.encode(address(0)));
        validators.init();
        slash.init();
        _param(address(slash), "felonyThreshold", 600);
        _param(address(slash), "misdemeanorThreshold", 200);
        _param(address(validators), "maxNumOfMaintaining", 3);
        _param(address(validators), "maintainSlashScale", 3);
        // populate validatorExtraSet, which live chains did at the BEP-127 upgrade
        vm.prank(address(slash));
        validators.tryEnterMaintenance(address(0));
        members = validators.getValidators();
    }

    function _param(address target, string memory key, uint256 value) internal {
        vm.prank(GOV);
        IBEP714ValidatorSet(target).updateParam(key, abi.encode(value));
    }

    function _miss(address validator, uint256 n) internal {
        for (uint256 i; i < n; ++i) {
            vm.roll(block.number + 1);
            vm.prank(PRODUCER);
            slash.slash(validator);
        }
    }

    function _count(
        address validator
    ) internal view returns (uint256 count) {
        (, count) = slash.getSlashIndicator(validator);
    }

    function _deposit(
        address validator
    ) internal returns (uint256) {
        vm.prank(PRODUCER);
        validators.deposit{ value: 1 ether }(validator);
        return validators.getIncoming(validator);
    }

    function _advanceMaintenance(address validator, uint256 count) internal {
        (uint256 height,,) = validators.validatorExtraSet(validators.getCurrentValidatorIndex(validator));
        vm.roll(height + count * validators.getWorkingValidatorCount() * 3);
    }

    function _exit(
        address validator
    ) internal {
        vm.prank(validator);
        validators.exitMaintenance();
    }

    /*----------------- admission -----------------*/

    function testThresholdEntryWithoutPenalty() public {
        address validator = members[0];
        uint256 income = _deposit(validator);
        _miss(validator, 39);
        assertTrue(validators.isCurrentValidator(validator));
        _miss(validator, 1); // the 40th miss admits the validator in the same slash transaction
        assertFalse(validators.isCurrentValidator(validator));
        assertEq(validators.getIncoming(validator), income);
        _miss(validator, 4); // misses after entry are not counted
        assertEq(_count(validator), 40);
    }

    function testCapacityIsCheckedAtTheThresholdMissOnly() public {
        for (uint256 i; i < 4; ++i) {
            _miss(members[i], 40);
        }
        for (uint256 i; i < 3; ++i) {
            assertFalse(validators.isCurrentValidator(members[i]));
        }
        assertTrue(validators.isCurrentValidator(members[3])); // capacity 3
        _exit(members[0]);
        _miss(members[3], 159); // no retry after the threshold miss, even with capacity free
        assertTrue(validators.isCurrentValidator(members[3]));
        assertEq(_count(members[3]), 199);
        _miss(members[3], 1); // the misdemeanor path at 200 remains the next automatic entry
        assertFalse(validators.isCurrentValidator(members[3]));
        _miss(members[0], 1); // once per day
        assertTrue(validators.isCurrentValidator(members[0]));
    }

    function testAutomaticMaintenanceRequiresEnabledMaintenance() public {
        _param(address(validators), "maxNumOfMaintaining", 0);
        _miss(members[0], 40);
        assertTrue(validators.isCurrentValidator(members[0])); // BEP-127: zero disables maintenance
        _param(address(validators), "maxNumOfMaintaining", 3);
        _miss(members[0], 1); // the threshold miss has passed; no retry
        assertTrue(validators.isCurrentValidator(members[0]));
        _miss(members[1], 40);
        assertFalse(validators.isCurrentValidator(members[1]));
    }

    function testAutomaticMaintenancePreservesLastWorkingValidator() public {
        address[] memory smallSet = new address[](2);
        smallSet[0] = members[0];
        smallSet[1] = members[1];
        uint64[] memory powers = new uint64[](2);
        bytes[] memory votes = new bytes[](2);
        vm.prank(PRODUCER);
        validators.updateValidatorSetV2(smallSet, powers, votes);
        _miss(smallSet[0], 40);
        assertFalse(validators.isCurrentValidator(smallSet[0]));
        _miss(smallSet[1], 40);
        assertTrue(validators.isCurrentValidator(smallSet[1]));
        assertEq(validators.getValidators().length, 1);
    }

    /*----------------- settlement is unchanged from BEP-127 -----------------*/

    function testMaintenanceKeepsMissedBlockCount() public {
        address validator = members[0];
        uint256 income = _deposit(validator);
        _miss(validator, 40);
        _advanceMaintenance(validator, 199);
        _exit(validator); // 199 < 200: no penalty, the ordinary count is untouched
        assertEq(_count(validator), 40);
        assertEq(validators.getIncoming(validator), income);
        _miss(validator, 1);
        assertEq(_count(validator), 41);
    }

    /*----------------- governance -----------------*/

    function testGovernanceBoundsAndAuthorization() public {
        assertEq(slash.maintenanceThreshold(), 40);
        vm.expectRevert("the message sender must be slash contract");
        validators.tryEnterMaintenance(members[0]);
        vm.expectRevert("the maintenanceThreshold out of range");
        _param(address(slash), "maintenanceThreshold", 0);
        vm.expectRevert("the maintenanceThreshold out of range");
        _param(address(slash), "maintenanceThreshold", 200);
        vm.expectRevert("the misdemeanorThreshold out of range");
        _param(address(slash), "misdemeanorThreshold", 40);
        _param(address(slash), "maintenanceThreshold", 41);
        assertEq(slash.maintenanceThreshold(), 41);
        _miss(members[0], 40);
        assertTrue(validators.isCurrentValidator(members[0]));
        _miss(members[0], 1);
        assertFalse(validators.isCurrentValidator(members[0]));
    }

}
