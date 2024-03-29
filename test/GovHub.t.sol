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
        vm.expectEmit(false, false, false, true, address(bscValidatorSet));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(bscValidatorSet));
        assertEq(uint256(value), bscValidatorSet.expireTimeSecondGap());
    }

    function testGovTokenHub(uint256 value) public {
        vm.assume(value > 0);
        vm.assume(value <= 1e8);
        value = value * 1e10;

        bytes memory key = "relayFee";
        bytes memory valueBytes = abi.encode(value);
        vm.expectEmit(false, false, false, true, address(tokenHub));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(tokenHub));
        assertEq(value, tokenHub.relayFee());
    }

    function testGovLightClient(uint256 value) public {
        vm.assume(value > 0);
        vm.assume(value <= 1e18);

        bytes memory key = "rewardForValidatorSetChange";
        bytes memory valueBytes = abi.encode(value);
        vm.expectEmit(false, false, false, true, address(lightClient));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(lightClient));
        assertEq(value, lightClient.rewardForValidatorSetChange());
    }

    function testGovRelayerHub() public {
        // removed params
        // uint256 dues = relayerHub.dues();
        // vm.assume(uint256(value) > dues);
        // vm.assume(value <= 1e21);
        //
        // bytes memory key = "requiredDeposit";
        // bytes memory valueBytes = abi.encode(value);
        // vm.expectEmit(false, false, false, true, address(relayerHub));
        // emit paramChange(string(key), valueBytes);
        // _updateParamByGovHub(key, valueBytes, address(relayerHub));
        // assertEq(uint256(value), relayerHub.requiredDeposit());
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
        vm.expectEmit(false, false, false, true, address(incentivize));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(incentivize));
        assertEq(value1, incentivize.headerRelayerRewardRateMolecule());

        key = "headerRelayerRewardRateDenominator";
        valueBytes = abi.encode(value2);
        vm.expectEmit(false, false, false, true, address(incentivize));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(incentivize));
        assertEq(value2, incentivize.headerRelayerRewardRateDenominator());

        key = "callerCompensationDenominator";
        valueBytes = abi.encode(value3);
        vm.expectEmit(false, false, false, true, address(incentivize));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(incentivize));
        assertEq(value3, incentivize.callerCompensationDenominator());
    }

    function testGovCrossChain(uint16 value) public {
        vm.assume(value >= 10);
        vm.assume(value <= 10000);

        bytes memory key = "batchSizeForOracle";
        bytes memory valueBytes = abi.encode(value);
        vm.expectEmit(false, false, false, true, address(crossChain));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(crossChain));
        assertEq(uint256(value), crossChain.batchSizeForOracle());

        key = "addOrUpdateChannel";
        valueBytes = abi.encodePacked(uint8(0x58), uint8(0x00), address(incentivize));
        vm.expectEmit(false, false, false, true, address(crossChain));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(crossChain));
        assertEq(address(incentivize), crossChain.channelHandlerContractMap(0x58));

        key = "enableOrDisableChannel";
        valueBytes = abi.encodePacked(uint8(0x58), uint8(0x00));
        vm.expectEmit(false, false, false, true, address(crossChain));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(crossChain));
        assertEq(false, crossChain.registeredContractChannelMap(address(incentivize), 0x58));

        valueBytes = abi.encodePacked(uint8(0x58), uint8(0x01));
        vm.expectEmit(false, false, false, true, address(crossChain));
        emit paramChange(string(key), valueBytes);
        _updateParamByGovHub(key, valueBytes, address(crossChain));
        assertTrue(crossChain.registeredContractChannelMap(address(incentivize), 0x58));
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

    function testGovFailed(uint256 value) public {
        // unknown key
        bytes memory key = "unknownKey";
        bytes memory valueBytes = abi.encode(value);
        vm.expectEmit(false, false, false, true, address(govHub));
        emit failReasonWithStr("unknown param");
        _updateParamByGovHub(key, valueBytes, address(bscValidatorSet));

        // exceed range
        key = "expireTimeSecondGap";
        valueBytes = abi.encode(uint256(10));
        vm.expectEmit(false, false, false, true, address(govHub));
        emit failReasonWithStr("the expireTimeSecondGap is out of range");
        _updateParamByGovHub(key, valueBytes, address(bscValidatorSet));

        // length mismatch
        key = "expireTimeSecondGap";
        valueBytes = abi.encodePacked(uint128(10));
        vm.expectEmit(false, false, false, true, address(govHub));
        emit failReasonWithStr("length of expireTimeSecondGap mismatch");
        _updateParamByGovHub(key, valueBytes, address(bscValidatorSet));

        // address do not exist
        key = "expireTimeSecondGap";
        valueBytes = abi.encode(uint256(10));
        vm.expectEmit(false, false, false, true, address(govHub));
        emit failReasonWithStr("the target is not a contract");
        _updateParamByGovHub(key, valueBytes, _getNextUserAddress());

        // method do no exist
        key = "expireTimeSecondGap";
        valueBytes = abi.encode(uint256(10));
        vm.expectEmit(false, false, false, true, address(govHub));
        emit failReasonWithStr("unknown param");
        _updateParamByGovHub(key, valueBytes, address(systemReward));
    }
}
