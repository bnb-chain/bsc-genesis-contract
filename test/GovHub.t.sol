pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

contract GovHubTest is Deployer {
    event failReasonWithStr(string message);

    function setUp() public { }

    function testGovValidatorSet(uint16 value) public {
        vm.assume(value >= 100);
        vm.assume(value <= 1e5);

        bytes memory key = "expireTimeSecondGap";
        bytes memory valueBytes = abi.encode(value);
        vm.expectEmit();
        emit failReasonWithStr("unknown param");
        _updateParamByGovHub(key, valueBytes, address(bscValidatorSet));
    }

    function testGovTokenHub(uint256 value) public {
        vm.assume(value > 0);
        vm.assume(value <= 1e8);
        value = value * 1e10;

        bytes memory key = "relayFee";
        bytes memory valueBytes = abi.encode(value);
        vm.expectEmit();
        emit failReasonWithStr("deprecated");
        _updateParamByGovHub(key, valueBytes, address(tokenHub));
    }

    function testGovLightClient(uint256 value) public {
        vm.assume(value > 0);
        vm.assume(value <= 1e18);

        bytes memory key = "rewardForValidatorSetChange";
        bytes memory valueBytes = abi.encode(value);
        vm.expectEmit();
        emit failReasonWithStr("deprecated");
        _updateParamByGovHub(key, valueBytes, address(lightClient));
    }

    function testGovIncentivize(uint256 value1, uint256 value2, uint256 value3) public {
        uint256 denominator = incentivize.headerRelayerRewardRateDenominator();
        vm.assume(value1 <= denominator);
        vm.assume(value2 >= value1);
        vm.assume(value2 > 0);
        vm.assume(value3 > 0);
        vm.assume(value3 >= value1);

        bytes memory key = "headerRelayerRewardRateMolecule";
        bytes memory valueBytes = abi.encode(value1);
        vm.expectEmit();
        emit failReasonWithStr("deprecated");
        _updateParamByGovHub(key, valueBytes, address(incentivize));
    }

    function testGovCrossChain(uint16 value) public {
        vm.assume(value >= 10);
        vm.assume(value <= 10000);

        bytes memory key = "batchSizeForOracle";
        bytes memory valueBytes = abi.encode(value);
        vm.expectEmit();
        emit failReasonWithStr("deprecated");
        _updateParamByGovHub(key, valueBytes, address(crossChain));

        key = "addOrUpdateChannel";
        valueBytes = abi.encodePacked(uint8(0x58), uint8(0x00), address(incentivize));
        vm.expectEmit();
        emit failReasonWithStr("deprecated");
        _updateParamByGovHub(key, valueBytes, address(crossChain));

        key = "enableOrDisableChannel";
        valueBytes = abi.encodePacked(uint8(0x58), uint8(0x00));
        vm.expectEmit();
        emit failReasonWithStr("deprecated");
        _updateParamByGovHub(key, valueBytes, address(crossChain));

        valueBytes = abi.encodePacked(uint8(0x58), uint8(0x01));
        vm.expectEmit();
        emit failReasonWithStr("deprecated");
        _updateParamByGovHub(key, valueBytes, address(crossChain));
    }

    function testGovSlash(uint16 value1, uint16 value2) public {
        uint256 misdemeanorThreshold = slashIndicator.misdemeanorThreshold();
        vm.assume(uint256(value1) > misdemeanorThreshold);
        vm.assume(value1 <= 1000);
        vm.assume(value2 < value1);
        vm.assume(value2 > 0);

        bytes memory key = "felonyThreshold";
        bytes memory valueBytes = abi.encode(value1);
        vm.expectEmit(false, false, false, true, address(slashIndicator));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(slashIndicator));
        assertEq(uint256(value1), slashIndicator.felonyThreshold());

        key = "misdemeanorThreshold";
        valueBytes = abi.encode(value2);
        vm.expectEmit(false, false, false, true, address(slashIndicator));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(slashIndicator));
        assertEq(uint256(value2), slashIndicator.misdemeanorThreshold());
    }
}
