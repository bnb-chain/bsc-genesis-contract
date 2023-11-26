pragma solidity ^0.8.10;

import "forge-std/Test.sol";

import "./interface/IBSCValidatorSet.sol";
import "./interface/ICrossChain.sol";
import "./interface/IGovHub.sol";
import "./interface/IRelayerHub.sol";
import "./interface/IRelayerIncentivize.sol";
import "./interface/ISlashIndicator.sol";
import "./interface/IStaking.sol";
import "./interface/ISystemReward.sol";
import "./interface/ITokenHub.sol";
import "./interface/ITokenManager.sol";
import "./interface/ITendermintLightClient.sol";
import "./interface/IStakeHub.sol";
import "./interface/IStakeCredit.sol";
import "./interface/IBSCGovernor.sol";
import "./interface/IGovToken.sol";
import "./interface/IBSCTimelock.sol";
import "./RLPEncode.sol";
import "./RLPDecode.sol";

contract Deployer is Test {
    using RLPEncode for *;

    // system contract address
    address payable public constant VALIDATOR_CONTRACT_ADDR = payable(0x0000000000000000000000000000000000001000);
    address payable public constant SLASH_CONTRACT_ADDR = payable(0x0000000000000000000000000000000000001001);
    address payable public constant SYSTEM_REWARD_ADDR = payable(0x0000000000000000000000000000000000001002);
    address payable public constant LIGHT_CLIENT_ADDR = payable(0x0000000000000000000000000000000000001003);
    address payable public constant TOKEN_HUB_ADDR = payable(0x0000000000000000000000000000000000001004);
    address payable public constant INCENTIVIZE_ADDR = payable(0x0000000000000000000000000000000000001005);
    address payable public constant RELAYERHUB_CONTRACT_ADDR = payable(0x0000000000000000000000000000000000001006);
    address payable public constant GOV_HUB_ADDR = payable(0x0000000000000000000000000000000000001007);
    address payable public constant TOKEN_MANAGER_ADDR = payable(0x0000000000000000000000000000000000001008);
    address payable public constant CROSS_CHAIN_CONTRACT_ADDR = payable(0x0000000000000000000000000000000000002000);
    address payable public constant STAKING_CONTRACT_ADDR = payable(0x0000000000000000000000000000000000002001);
    address payable public constant STAKE_HUB_ADDR = payable(0x0000000000000000000000000000000000002002);
    address payable public constant STAKE_CREDIT_ADDR = payable(0x0000000000000000000000000000000000002003);
    address payable public constant GOVERNOR_ADDR = payable(0x0000000000000000000000000000000000002004);
    address payable public constant GOV_TOKEN_ADDR = payable(0x0000000000000000000000000000000000002005);
    address payable public constant TIMELOCK_ADDR = payable(0x0000000000000000000000000000000000002006);

    uint8 public constant BIND_CHANNELID = 0x01;
    uint8 public constant TRANSFER_IN_CHANNELID = 0x02;
    uint8 public constant TRANSFER_OUT_CHANNELID = 0x03;
    uint8 public constant MIRROR_CHANNELID = 0x04;
    uint8 public constant SYNC_CHANNELID = 0x05;
    uint8 public constant STAKING_CHANNELID = 0x08;
    uint8 public constant GOV_CHANNELID = 0x09;
    uint8 public constant SLASH_CHANNELID = 0x0b;
    uint8 public constant CROSS_STAKE_CHANNELID = 0x10;

    BSCValidatorSet public bscValidatorSet;
    SlashIndicator public slashIndicator;
    SystemReward public systemReward;
    TendermintLightClient public lightClient;
    TokenHub public tokenHub;
    RelayerIncentivize public incentivize;
    RelayerHub public relayerHub;
    GovHub public govHub;
    TokenManager public tokenManager;
    CrossChain public crossChain;
    Staking public staking;
    StakeHub public stakeHub;
    StakeCredit public stakeCredit;
    BSCGovernor public governor;
    GovToken public govToken;
    BSCTimelock public timelock;

    address payable public relayer;

    bytes32 internal nextUser = keccak256(abi.encodePacked("user address"));

    event paramChange(string key, bytes value);

    constructor() {
        // create fork
        // you should modify this for your own test, which generally should be the bsc mainnet latest number
        // TODO: wait for foundry to fix this
        // vm.createSelectFork("bsc", 23839447);

        // setup system contracts
        bscValidatorSet = BSCValidatorSet(VALIDATOR_CONTRACT_ADDR);
        vm.label(address(bscValidatorSet), "Validator");
        slashIndicator = SlashIndicator(SLASH_CONTRACT_ADDR);
        vm.label(address(slashIndicator), "SlashIndicator");
        systemReward = SystemReward(SYSTEM_REWARD_ADDR);
        vm.label(address(systemReward), "SystemReward");
        lightClient = TendermintLightClient(LIGHT_CLIENT_ADDR);
        vm.label(address(lightClient), "LightClient");
        tokenHub = TokenHub(TOKEN_HUB_ADDR);
        vm.label(address(tokenHub), "TokenHub");
        incentivize = RelayerIncentivize(INCENTIVIZE_ADDR);
        vm.label(address(incentivize), "RelayerIncentivize");
        relayerHub = RelayerHub(RELAYERHUB_CONTRACT_ADDR);
        vm.label(address(relayerHub), "RelayerHub");
        govHub = GovHub(GOV_HUB_ADDR);
        vm.label(address(govHub), "GovHub");
        tokenManager = TokenManager(TOKEN_MANAGER_ADDR);
        vm.label(address(tokenManager), "TokenManager");
        crossChain = CrossChain(CROSS_CHAIN_CONTRACT_ADDR);
        vm.label(address(crossChain), "CrossChain");
        staking = Staking(STAKING_CONTRACT_ADDR);
        vm.label(address(staking), "Staking");
        stakeHub = StakeHub(STAKE_HUB_ADDR);
        vm.label(address(stakeHub), "StakeHub");
        stakeCredit = StakeCredit(STAKE_CREDIT_ADDR);
        vm.label(address(stakeCredit), "StakeCredit");
        governor = BSCGovernor(GOVERNOR_ADDR);
        vm.label(address(governor), "BSCGovernor");
        govToken = GovToken(GOV_TOKEN_ADDR);
        vm.label(address(govToken), "GovToken");
        timelock = BSCTimelock(TIMELOCK_ADDR);
        vm.label(address(timelock), "BSCTimelock");

        // set the latest code
        bytes memory deployedCode = vm.getDeployedCode("BSCValidatorSet.sol");
        vm.etch(VALIDATOR_CONTRACT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("SlashIndicator.sol");
        vm.etch(SLASH_CONTRACT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("SystemReward.sol");
        vm.etch(SYSTEM_REWARD_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("TendermintLightClient.sol");
        vm.etch(LIGHT_CLIENT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("TokenHub.sol");
        vm.etch(TOKEN_HUB_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("RelayerIncentivize.sol");
        vm.etch(INCENTIVIZE_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("RelayerHub.sol");
        vm.etch(RELAYERHUB_CONTRACT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("GovHub.sol");
        vm.etch(GOV_HUB_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("TokenManager.sol");
        vm.etch(TOKEN_MANAGER_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("CrossChain.sol");
        vm.etch(CROSS_CHAIN_CONTRACT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("Staking.sol");
        vm.etch(STAKING_CONTRACT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("StakeHub.sol");
        vm.etch(STAKE_HUB_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("StakeCredit.sol");
        vm.etch(STAKE_CREDIT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("BSCGovernor.sol");
        vm.etch(GOVERNOR_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("GovToken.sol");
        vm.etch(GOV_TOKEN_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("BSCTimelock.sol");
        vm.etch(TIMELOCK_ADDR, deployedCode);

        relayer = payable(0xb005741528b86F5952469d80A8614591E3c5B632); // whitelabel relayer
        vm.label(relayer, "relayer");
    }

    function _getNextUserAddress() internal returns (address payable) {
        //bytes32 to address conversion
        address payable user = payable(address(uint160(uint256(nextUser))));
        nextUser = keccak256(abi.encodePacked(nextUser));
        vm.deal(user, 10_000 ether);
        return user;
    }

    function _updateParamByGovHub(bytes memory key, bytes memory value, address addr) internal {
        bytes[] memory elements = new bytes[](3);
        elements[0] = key.encodeBytes();
        elements[1] = value.encodeBytes();
        elements[2] = addr.encodeAddress();

        vm.startPrank(address(crossChain));
        govHub.handleSynPackage(GOV_CHANNELID, elements.encodeList());
        vm.stopPrank();
    }

    function _encodeOldValidatorSetUpdatePack(
        uint8 code,
        address[] memory valSet
    ) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = code.encodeUint();

        bytes[] memory vals = new bytes[](valSet.length);
        for (uint256 i; i < valSet.length; ++i) {
            bytes[] memory tmp = new bytes[](4);
            tmp[0] = valSet[i].encodeAddress();
            tmp[1] = valSet[i].encodeAddress();
            tmp[2] = valSet[i].encodeAddress();
            tmp[3] = uint8(0x64).encodeUint();
            vals[i] = tmp.encodeList();
        }

        elements[1] = vals.encodeList();
        return elements.encodeList();
    }

    function _encodeNewValidatorSetUpdatePack(
        uint8 code,
        address[] memory valSet,
        bytes[] memory voteAddrs
    ) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](2);
        elements[0] = code.encodeUint();

        bytes[] memory vals = new bytes[](valSet.length);
        for (uint256 i; i < valSet.length; ++i) {
            bytes[] memory tmp = new bytes[](5);
            tmp[0] = valSet[i].encodeAddress();
            tmp[1] = valSet[i].encodeAddress();
            tmp[2] = valSet[i].encodeAddress();
            tmp[3] = uint8(0x64).encodeUint();
            tmp[4] = voteAddrs[i].encodeBytes();
            vals[i] = tmp.encodeList();
        }

        elements[1] = vals.encodeList();
        return elements.encodeList();
    }
}
