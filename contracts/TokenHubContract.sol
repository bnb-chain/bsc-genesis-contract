pragma solidity 0.5.16;

import "IERC20.sol";
import "ITendermintLightClient.sol";
import "IRelayerIncentivize.sol";

contract TokenHubContract {

    //TODO relayer incentive mechanism
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
    bytes32 sourceChainID         = 0x42696e616e63652d436861696e2d4e696c650000000000000000000000000000; // "Binance-Chain-Nile"
    bytes32 destinationChainID    = 0x1500000000000000000000000000000000000000000000000000000000000000; // "15"
    uint256 minimumRelayReward     = 10000;//0.01 BNB

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

    constructor() public {

    }

    function initTokenHub(address lightClientContractAddr,
        address incentivizeContractAddrForHeaderSyncRelayers,
        address incentivizeContractAddrForTransferRelayers) public {
        lightClientContract = lightClientContractAddr;
        incentivizeContractForHeaderSyncRelayers = incentivizeContractAddrForHeaderSyncRelayers;
        incentivizeContractForTransferRelayers = incentivizeContractAddrForTransferRelayers;
    }

    function calculateRewardForTendermintHeaderRelayer(uint256 reward) internal pure returns (uint256) {
        return reward/5; //20%
    }
    // | sourceChainID | destinationChainID | channelID | sequence |
    // | 32 bytes      | 32 bytes           |  1 bytes  | 32 bytes |
    function verifyKey(bytes memory key, uint8 expectedChannelID, uint256 expectedSequence) internal view returns(bool) {
        if (key.length!=97) {
            return false;
        }

        uint256 pos=key.length;

        pos-=32;
        uint256 sequence;
        assembly {
            sequence := mload(add(key, pos))
        }
        if (sequence != expectedSequence) {
            return false;
        }

        pos-=8;
        uint8 channelID;
        assembly {
            channelID := mload(add(key, pos))
        }
        if (channelID != expectedChannelID) {
            return false;
        }

        bytes32 chainID;
        pos-=32;
        assembly {
            chainID := mload(add(key, pos))
        }
        if (chainID != destinationChainID) {
            return false;
        }

        pos-=32;
        assembly {
            chainID := mload(add(key, pos))
        }
        if (chainID != sourceChainID) {
            return false;
        }

        return true;
    }

    function decodeBindRequestPackage(bytes memory value) internal pure returns(BindRequestPackage memory) {
        BindRequestPackage memory brPackage;

        uint256 pos=value.length;

        pos-=32;
        uint256 tempValue;
        assembly {
            tempValue := mload(add(value, pos))
        }
        brPackage.relayReward = tempValue;

        pos-=32;
        assembly {
            tempValue := mload(add(value, pos))
        }
        brPackage.peggyAmount = tempValue;

        pos-=32;
        assembly {
            tempValue := mload(add(value, pos))
        }
        brPackage.totalSupply = tempValue;

        pos-=20;
        address addr;
        assembly {
            addr := mload(add(value, pos))
        }
        brPackage.contractAddr = addr;

        pos-=20;
        assembly {
            addr := mload(add(value, 0))
        }
        brPackage.bep2TokenOwner = addr;

        pos-=32;
        bytes32 bep2TokenSymbol;
        assembly {
            bep2TokenSymbol := mload(add(value, 0))
        }
        brPackage.bep2TokenSymbol = bep2TokenSymbol;

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
        require(relayReward>minimumRelayReward);
        require(contractAddrToBEP2Symbol[contractAddr]!=0x00);
        if (contractAddr==address(0x0)) {
            require(msg.value==amount+relayReward);
            amount = msg.value;
            emit LogCrossChainTransfer(msg.sender, recipient, amount, contractAddr, bep2TokenSymbolForBNB, expireTime, relayReward, transferOutChannelSequence); //BNB 32bytes
        } else {
            require(msg.value==relayReward);
            require(IERC20(contractAddr).transferFrom(msg.sender, address(this), amount), "failed to transfer token to this contract");
            emit LogCrossChainTransfer(msg.sender, recipient, amount, contractAddr, contractAddrToBEP2Symbol[contractAddr], expireTime, relayReward, transferOutChannelSequence);
        }
        transferOutChannelSequence++;
    }

    function decodeCrossChainTransferPackage(bytes memory value) internal pure returns (CrossChainTransferPackage memory) {
        CrossChainTransferPackage memory cctp;

        uint256 pos = value.length;

        uint256 tempValue;

        pos-=32;
        assembly {
            tempValue := mload(add(value, pos))
        }
        cctp.relayReward = tempValue;

        pos-=32;
        assembly {
            tempValue := mload(add(value, pos))
        }
        cctp.expireTime = tempValue;

        pos-=32;
        assembly {
            tempValue := mload(add(value, pos))
        }
        cctp.amount = tempValue;

        address payable recipient;
        pos-=20;
        assembly {
            recipient := mload(add(value, pos))
        }
        cctp.recipient = recipient;

        address addr;
        pos-=20;
        assembly {
            addr := mload(add(value, pos))
        }
        cctp.sender = addr;

        pos-=20;
        assembly {
            addr := mload(add(value, pos))
        }
        cctp.contractAddr = addr;

        pos-=32;
        bytes32 bep2TokenSymbol;
        assembly {
            bep2TokenSymbol := mload(add(value, pos))
        }
        cctp.bep2TokenSymbol = bep2TokenSymbol;

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

    function decodeTimeoutPackage(bytes memory value) internal pure returns(TimeoutPackage memory) {
        TimeoutPackage memory timeoutPackage;

        uint256 pos=value.length;

        pos-=20;
        address contractAddr;
        assembly {
            contractAddr := mload(add(value, pos))
        }
        timeoutPackage.contractAddr = contractAddr;

        pos-=20;
        address payable refundAddr;
        assembly {
            refundAddr := mload(add(value, pos))
        }
        timeoutPackage.refundAddr = refundAddr;

        pos-=32;
        uint256 refundAmount;
        assembly {
            refundAmount := mload(add(value, pos))
        }
        timeoutPackage.refundAmount = refundAmount;

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