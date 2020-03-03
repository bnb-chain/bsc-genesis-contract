pragma solidity 0.5.16;

import "IERC20.sol";
import "ITendermintLightClient.sol";
import "IRelayerIncentivize.sol";

contract TokenHubContract {

    struct BindRequestPackage {
        bytes32 bep2TokenSymbol;
        address bep2TokenOwner;
        address contractAddr;
        uint256 totalSupply;
        uint256 peggyAmount;
        uint256 relayReward;
    }

    struct TimeoutPackage {
        uint256 refundAmount;
        address contractAddr;
        address payable refundAddr;
    }

    struct CrossChainTransferPackage {
        bytes32 bep2TokenSymbol;
        address contractAddr;
        address sender;
        address payable recipient;
        uint256 amount;
        uint256 expireTime;
        uint256 relayReward;
    }

    bytes32 bep2TokenSymbolForBNB = 0x424E420000000000000000000000000000000000000000000000000000000000; // "BNB"
    bytes32 sourceChainID         = 0x746573742d636861696e00000000000000000000000000000000000000000000; // "test-chain"
    bytes32 destinationChainID    = 0x3135000000000000000000000000000000000000000000000000000000000000; // "15"
    uint256 minimumRelayReward    = 10000;//0.01 BNB

    address lightClientContract;
    address incentivizeContractForHeaderSyncRelayers;
    address incentivizeContractForTransferRelayers;

    mapping(address => bytes32) contractAddrToBEP2Symbol;
    mapping(bytes32 => address) BEP2SymbolToContractAddr;

    uint256 bindChannelSequence=0;
    uint256 transferInChannelSequence=0;
    uint256 transferOutChannelSequence=0;
    uint256 timeoutChannelSequence=0;

    event LogRegisterERC20ToBEP2(address contractAddr, uint256 peggyAmount, address bep2T0kenOwner, bytes32 bep2TokenSymbol);

    event LogTokenBind(address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);
    event LogInvalidTokenBind(address contractAddr, bytes32 bep2TokenSymbol, address bep2TokenOwner, uint256 totalSupply, uint256 peggyAmount);

    event LogCrossChainTransfer(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayReward, uint256 sequence);

    event LogTransferInSuccess(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol);
    event LogTransferInFailureTimeout(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 handleTime);
    event LogTransferInFailureInsufficientBalance(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol);
    event LogTransferInFailureUnbindedToken(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol);

    constructor() public payable {

    }

    //TODO add authority check
    function initTokenHub(address lightClientContractAddr,
        address incentivizeContractAddrForHeaderSyncRelayers,
        address incentivizeContractAddrForTransferRelayers) public {
        lightClientContract = lightClientContractAddr;
        incentivizeContractForHeaderSyncRelayers = incentivizeContractAddrForHeaderSyncRelayers;
        incentivizeContractForTransferRelayers = incentivizeContractAddrForTransferRelayers;
    }

    //TODO need further discussion
    function calculateRewardForTendermintHeaderRelayer(uint256 reward) internal pure returns (uint256) {
        return reward/5; //20%
    }
    // | length   | prefix | sourceChainID | destinationChainID | channelID | sequence |
    // | 32 bytes | 1 byte | 32 bytes      | 32 bytes           |  1 bytes  | 8 bytes  |
    function verifyKey(bytes memory key, uint8 expectedChannelID, uint256 expectedSequence) internal view returns(bool) {
        uint256 length;
        assembly {
            length := mload(add(key, 0))
        }
        if (length != 0x4a) { //74
            return false;
        }

        uint256 pos=0;

        bytes32 chainID;
        pos+=32+1;
        assembly {
            chainID := mload(add(key, pos))
        }
        if (chainID != sourceChainID) {
            return false;
        }

        pos+=32;
        assembly {
            chainID := mload(add(key, pos))
        }
        if (chainID != destinationChainID) {
            return false;
        }

        pos+=1;
        uint8 channelID;
        assembly {
            channelID := mload(add(key, pos))
        }
        if (channelID != expectedChannelID) {
            return false;
        }

        pos+=8;
        uint64 sequence;
        assembly {
            sequence := mload(add(key, pos))
        }
        if (sequence != expectedSequence) {
            return false;
        }

        return true;
    }

    // | length   | bep2TokenSymbol | bep2TokenOwner | contractAddr | totalSupply | peggyAmount | relayReward |
    // | 32 bytes | 32 bytes        | 20 bytes       | 20 bytes     |  32 bytes   | 32 bytes    | 32 bytes    |
    function decodeBindRequestPackage(bytes memory value) internal pure returns(BindRequestPackage memory) {
        BindRequestPackage memory brPackage;

        uint256 pos=0;

        bytes32 bep2TokenSymbol;
        pos+=32;
        assembly {
            bep2TokenSymbol := mload(add(value, pos))
        }
        brPackage.bep2TokenSymbol = bep2TokenSymbol;

        address addr;

        pos+=20;
        assembly {
            addr := mload(add(value, pos))
        }
        brPackage.bep2TokenOwner = addr;

        pos+=20;
        assembly {
            addr := mload(add(value, pos))
        }
        brPackage.contractAddr = addr;


        uint256 tempValue;
        pos+=32;
        assembly {
            tempValue := mload(add(value, pos))
        }
        brPackage.totalSupply = tempValue;

        pos+=32;
        assembly {
            tempValue := mload(add(value, pos))
        }
        brPackage.peggyAmount = tempValue;

        pos+=32;
        assembly {
            tempValue := mload(add(value, pos))
        }
        brPackage.relayReward = tempValue;

        return brPackage;
    }

    function handleBindRequest(uint64 height, bytes memory key, bytes memory value, bytes memory proof) public returns (bool) {
        require(verifyKey(key, 0x01, bindChannelSequence));
        require(ITendermintLightClient(lightClientContract).validateMerkleProof(height, "ibc", key, value, proof), "invalid merkle proof");
        bindChannelSequence++;

        address payable tendermintHeaderSubmitter = ITendermintLightClient(lightClientContract).getSubmitter(height);

        BindRequestPackage memory brPackage = decodeBindRequestPackage(value);

        uint256 reward = calculateRewardForTendermintHeaderRelayer(brPackage.relayReward);
        IRelayerIncentivize(incentivizeContractForHeaderSyncRelayers).addReward.value(reward)(tendermintHeaderSubmitter);
        reward = brPackage.relayReward-reward;
        IRelayerIncentivize(incentivizeContractForTransferRelayers).addReward.value(reward)(msg.sender);

        uint256 bep2TokenDecimals=100000000; // 10^8
        uint256 erc20TokenDecimals=10**IERC20(brPackage.contractAddr).decimals();
        brPackage.totalSupply = brPackage.totalSupply*erc20TokenDecimals/bep2TokenDecimals;
        brPackage.peggyAmount = brPackage.peggyAmount*erc20TokenDecimals/bep2TokenDecimals;

        //TODO add bep2 token symbol and erc20 contract symbol checking

        if (BEP2SymbolToContractAddr[brPackage.bep2TokenSymbol]!=address(0x00)||
        IERC20(brPackage.contractAddr).totalSupply()!=brPackage.totalSupply||
        IERC20(brPackage.contractAddr).balanceOf(address(this))!=brPackage.peggyAmount||
        IERC20(brPackage.contractAddr).bep2TokenOwner()!=brPackage.bep2TokenOwner) {
            emit LogInvalidTokenBind(brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.bep2TokenOwner, brPackage.totalSupply, brPackage.peggyAmount);
            return false;
        }
        contractAddrToBEP2Symbol[brPackage.contractAddr] = brPackage.bep2TokenSymbol;
        BEP2SymbolToContractAddr[brPackage.bep2TokenSymbol] = brPackage.contractAddr;
        emit LogTokenBind(brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount);
        return true;
    }

    function crossChainTransferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime, uint256 relayReward) public payable {
        uint256 erc20TokenDecimals=IERC20(contractAddr).decimals();
        if (erc20TokenDecimals > 8) { // suppose erc20TokenDecimals is 10, then the amount must equal to N*100
            uint256 extraPrecision = 10**(erc20TokenDecimals-8);
            require(amount%extraPrecision==0);
        }
        require(relayReward>minimumRelayReward);
        require(contractAddrToBEP2Symbol[contractAddr]!=0x00);
        if (contractAddr==address(0x0)) {
            require(msg.value==amount+relayReward);
            amount = msg.value;
            uint256 calibrateAmount = amount * 100000000 / (10**erc20TokenDecimals); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
            emit LogCrossChainTransfer(msg.sender, recipient, calibrateAmount, contractAddr, bep2TokenSymbolForBNB, expireTime, relayReward, transferOutChannelSequence); //BNB 32bytes
        } else {
            require(msg.value==relayReward);
            require(IERC20(contractAddr).transferFrom(msg.sender, address(this), amount), "failed to transfer token to this contract");
            uint256 calibrateAmount = amount / (10**10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
            emit LogCrossChainTransfer(msg.sender, recipient, calibrateAmount, contractAddr, contractAddrToBEP2Symbol[contractAddr], expireTime, relayReward, transferOutChannelSequence);
        }
        transferOutChannelSequence++;
    }

    // | length   | bep2TokenSymbol | contractAddr | sender   | recipient | amount   | expireTime | relayReward |
    // | 32 bytes | 32 bytes        | 20 bytes     | 20 bytes | 20 bytes  | 32 bytes | 32 bytes   | 32 bytes    |
    function decodeCrossChainTransferPackage(bytes memory value) internal pure returns (CrossChainTransferPackage memory) {
        CrossChainTransferPackage memory cctp;

        uint256 pos = 0;
        uint256 tempValue;
        address payable recipient;
        address addr;

        pos+=32;
        bytes32 bep2TokenSymbol;
        assembly {
            bep2TokenSymbol := mload(add(value, pos))
        }
        cctp.bep2TokenSymbol = bep2TokenSymbol;

        pos+=20;
        assembly {
            addr := mload(add(value, pos))
        }
        cctp.contractAddr = addr;

        pos+=20;
        assembly {
            addr := mload(add(value, pos))
        }
        cctp.sender = addr;

        pos+=20;
        assembly {
            recipient := mload(add(value, pos))
        }
        cctp.recipient = recipient;

        pos+=32;
        assembly {
            tempValue := mload(add(value, pos))
        }
        cctp.amount = tempValue;

        pos+=32;
        assembly {
            tempValue := mload(add(value, pos))
        }
        cctp.expireTime = tempValue;

        pos+=32;
        assembly {
            tempValue := mload(add(value, pos))
        }
        cctp.relayReward = tempValue;

        return cctp;
    }

    function handleCrossChainTransferIn(uint64 height, bytes memory key, bytes memory value, bytes memory proof) public returns (bool) {
        require(verifyKey(key, 0x02, transferInChannelSequence));
        require(ITendermintLightClient(lightClientContract).validateMerkleProof(height, "ibc", key, value, proof), "invalid merkle proof");
        transferInChannelSequence++;

        address payable tendermintHeaderSubmitter = ITendermintLightClient(lightClientContract).getSubmitter(height);

        CrossChainTransferPackage memory cctp = decodeCrossChainTransferPackage(value);

        uint256 reward = calculateRewardForTendermintHeaderRelayer(cctp.relayReward);
        IRelayerIncentivize(incentivizeContractForHeaderSyncRelayers).addReward.value(reward)(tendermintHeaderSubmitter);
        reward = cctp.relayReward-reward;
        IRelayerIncentivize(incentivizeContractForTransferRelayers).addReward.value(reward)(msg.sender);

        if (block.timestamp > cctp.expireTime) {
            emit LogTransferInFailureTimeout(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol, cctp.expireTime, block.timestamp);
            return false;
        }

        if (cctp.contractAddr==address(0x0)) {
            if (address(this).balance < cctp.amount) {
                emit LogTransferInFailureInsufficientBalance(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol);
                return false;
            }
            cctp.recipient.transfer(cctp.amount);
        } else {
            if (contractAddrToBEP2Symbol[cctp.contractAddr]==0x00) {
                emit LogTransferInFailureUnbindedToken(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol);
                return false;
            }
            if (IERC20(cctp.contractAddr).balanceOf(address(this))<cctp.amount) {
                emit LogTransferInFailureInsufficientBalance(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol);
                return false;
            }
            IERC20(cctp.contractAddr).transfer(cctp.recipient, cctp.amount);
        }
        emit LogTransferInSuccess(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol);
        return true;
    }

    // | length   | refundAmount | contractAddr | refundAddr |
    // | 32 bytes | 32 bytes     | 20 bytes     | 20 bytes   |
    function decodeTimeoutPackage(bytes memory value) internal pure returns(TimeoutPackage memory) {
        TimeoutPackage memory timeoutPackage;

        uint256 pos=0;

        pos+=32;
        uint256 refundAmount;
        assembly {
            refundAmount := mload(add(value, pos))
        }
        timeoutPackage.refundAmount = refundAmount;

        pos+=20;
        address contractAddr;
        assembly {
            contractAddr := mload(add(value, pos))
        }
        timeoutPackage.contractAddr = contractAddr;

        pos+=20;
        address payable refundAddr;
        assembly {
            refundAddr := mload(add(value, pos))
        }
        timeoutPackage.refundAddr = refundAddr;


        return timeoutPackage;
    }

    function handleCrossChainTransferOutTimeout(uint64 height, bytes memory key, bytes memory value, bytes memory proof) public returns (bool) {
        require(verifyKey(key, 0x03, timeoutChannelSequence));
        require(ITendermintLightClient(lightClientContract).validateMerkleProof(height, "ibc", key, value, proof), "invalid merkle proof");
        timeoutChannelSequence++;

        //address payable tendermintHeaderSubmitter = ITendermintLightClient(lightClientContract).getSubmitter(height);

        TimeoutPackage memory timeoutPackage = decodeTimeoutPackage(value);

        //IRelayerIncentivize(incentivizeContractForHeaderSyncRelayers).addReward.value(reward)(tendermintHeaderSubmitter);
        //reward = timeoutPackage.relayReward-reward;
        //IRelayerIncentivize(incentivizeContractForTransferRelayers).addReward.value(reward)(msg.sender);

        if (timeoutPackage.contractAddr==address(0x0)) {
            if (address(this).balance < timeoutPackage.refundAmount) {
                return false;
            }
            timeoutPackage.refundAddr.transfer(timeoutPackage.refundAmount);
        } else {
            if (IERC20(timeoutPackage.contractAddr).balanceOf(address(this))<timeoutPackage.refundAmount) {
                return false;
            }
            IERC20(timeoutPackage.contractAddr).transfer(address(this), timeoutPackage.refundAmount);
        }
        return true;
    }
}