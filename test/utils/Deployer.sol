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
import "./interface/ITokenRecoverPortal.sol";
import "./RLPEncode.sol";
import "./RLPDecode.sol";

contract Deployer is Test {
    using RLPEncode for *;

    // system contract address
    address payable public constant VALIDATOR_CONTRACT_ADDR = payable(0x0000000000000000000000000000000000001000);
    address public constant SLASH_CONTRACT_ADDR = payable(0x0000000000000000000000000000000000001001);
    address payable public constant SYSTEM_REWARD_ADDR = payable(0x0000000000000000000000000000000000001002);
    address public constant LIGHT_CLIENT_ADDR = payable(0x0000000000000000000000000000000000001003);
    address payable public constant TOKEN_HUB_ADDR = payable(0x0000000000000000000000000000000000001004);
    address payable public constant INCENTIVIZE_ADDR = payable(0x0000000000000000000000000000000000001005);
    address public constant RELAYERHUB_CONTRACT_ADDR = payable(0x0000000000000000000000000000000000001006);
    address public constant GOV_HUB_ADDR = payable(0x0000000000000000000000000000000000001007);
    address public constant TOKEN_MANAGER_ADDR = payable(0x0000000000000000000000000000000000001008);
    address public constant CROSS_CHAIN_CONTRACT_ADDR = payable(0x0000000000000000000000000000000000002000);
    address payable public constant STAKING_CONTRACT_ADDR = payable(0x0000000000000000000000000000000000002001);
    address payable public constant STAKE_HUB_ADDR = payable(0x0000000000000000000000000000000000002002);
    address payable public constant STAKE_CREDIT_ADDR = payable(0x0000000000000000000000000000000000002003);
    address payable public constant GOVERNOR_ADDR = payable(0x0000000000000000000000000000000000002004);
    address public constant GOV_TOKEN_ADDR = payable(0x0000000000000000000000000000000000002005);
    address payable public constant TIMELOCK_ADDR = payable(0x0000000000000000000000000000000000002006);
    address public constant TOKEN_RECOVER_PORTAL_ADDR = payable(0x0000000000000000000000000000000000003000);

    uint8 public constant BIND_CHANNELID = 0x01;
    uint8 public constant TRANSFER_IN_CHANNELID = 0x02;
    uint8 public constant TRANSFER_OUT_CHANNELID = 0x03;
    uint8 public constant MIRROR_CHANNELID = 0x04;
    uint8 public constant SYNC_CHANNELID = 0x05;
    uint8 public constant STAKING_CHANNELID = 0x08;
    uint8 public constant GOV_CHANNELID = 0x09;
    uint8 public constant SLASH_CHANNELID = 0x0b;
    uint8 public constant CROSS_STAKE_CHANNELID = 0x10;
    uint8 public constant BC_FUSION_CHANNELID = 0x11;

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
    TokenRecoverPortal public tokenRecoverPortal;

    address payable public relayer;

    bytes32 internal nextUser = keccak256(abi.encodePacked("user address"));

    event paramChange(string key, bytes value);

    constructor() {
        // please use the following command to run the test on mainnet fork instead: forge test --rpc-url ${fork_url}
        // vm.createSelectFork("bsc");
        assertEq(block.chainid, 56);

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
        tokenRecoverPortal = TokenRecoverPortal(TOKEN_RECOVER_PORTAL_ADDR);
        vm.label(address(tokenRecoverPortal), "TokenRecoverPortal");

        // set the latest code
        bytes memory deployedCode = vm.getDeployedCode("BSCValidatorSet.sol:BSCValidatorSet");
        vm.etch(VALIDATOR_CONTRACT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("SlashIndicator.sol:SlashIndicator");
        vm.etch(SLASH_CONTRACT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("SystemReward.sol:SystemReward");
        vm.etch(SYSTEM_REWARD_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("TendermintLightClient.sol:TendermintLightClient");
        vm.etch(LIGHT_CLIENT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("TokenHub.sol:TokenHub");
        vm.etch(TOKEN_HUB_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("RelayerIncentivize.sol:RelayerIncentivize");
        vm.etch(INCENTIVIZE_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("RelayerHub.sol:RelayerHub");
        vm.etch(RELAYERHUB_CONTRACT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("GovHub.sol:GovHub");
        vm.etch(GOV_HUB_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("TokenManager.sol:TokenManager");
        vm.etch(TOKEN_MANAGER_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("CrossChain.sol:CrossChain");
        vm.etch(CROSS_CHAIN_CONTRACT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("Staking.sol:Staking");
        vm.etch(STAKING_CONTRACT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("StakeHub.sol:StakeHub");
        vm.etch(STAKE_HUB_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("StakeCredit.sol:StakeCredit");
        vm.etch(STAKE_CREDIT_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("BSCGovernor.sol:BSCGovernor");
        vm.etch(GOVERNOR_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("GovToken.sol:GovToken");
        vm.etch(GOV_TOKEN_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("BSCTimelock.sol:BSCTimelock");
        vm.etch(TIMELOCK_ADDR, deployedCode);
        deployedCode = vm.getDeployedCode("TokenRecoverPortal.sol:TokenRecoverPortal");
        vm.etch(TOKEN_RECOVER_PORTAL_ADDR, deployedCode);

        relayer = payable(0xb005741528b86F5952469d80A8614591E3c5B632); // whitelabel relayer on mainnet
        vm.label(relayer, "relayer");
    }

    function _getNextUserAddress() internal returns (address payable) {
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

    function _createValidator(uint256 delegation)
        internal
        returns (address operatorAddress, address consensusAddress, address credit, bytes memory voteAddress)
    {
        uint256 toLock = stakeHub.LOCK_AMOUNT();

        operatorAddress = _getNextUserAddress();
        StakeHub.Commission memory commission = StakeHub.Commission({ rate: 10, maxRate: 100, maxChangeRate: 5 });
        StakeHub.Description memory description = StakeHub.Description({
            moniker: string.concat("T", vm.toString(uint24(uint160(operatorAddress)))),
            identity: vm.toString(operatorAddress),
            website: vm.toString(operatorAddress),
            details: vm.toString(operatorAddress)
        });
        voteAddress = bytes.concat(
            hex"00000000000000000000000000000000000000000000000000000000", abi.encodePacked(operatorAddress)
        );
        bytes memory blsProof = new bytes(96);
        consensusAddress = address(uint160(uint256(keccak256(voteAddress))));

        vm.prank(operatorAddress);
        stakeHub.createValidator{ value: delegation + toLock }(
            consensusAddress, voteAddress, blsProof, commission, description
        );

        credit = stakeHub.getValidatorCreditContract(operatorAddress);
    }

    function _batchCreateValidators(uint256 number)
        internal
        returns (
            address[] memory operatorAddrs,
            address[] memory consensusAddrs,
            uint64[] memory votingPowers,
            bytes[] memory voteAddrs
        )
    {
        operatorAddrs = new address[](number);
        consensusAddrs = new address[](number);
        votingPowers = new uint64[](number);
        voteAddrs = new bytes[](number);

        address operatorAddress;
        address consensusAddress;
        uint64 votingPower;
        bytes memory voteAddress;
        for (uint256 i; i < number; ++i) {
            votingPower = 2000 * 1e8;
            (operatorAddress, consensusAddress,, voteAddress) = _createValidator(uint256(votingPower) * 1e10);

            operatorAddrs[i] = operatorAddress;
            consensusAddrs[i] = consensusAddress;
            votingPowers[i] = votingPower;
            voteAddrs[i] = voteAddress;
        }
    }
}
