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
        address contractAddr;
        address payable refundAddr;
        uint256 amount;
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
    uint256 minmumRelayReward     = 10000;//0.01 BNB

    address lightClientContract;
    address tendermintHeaderSyncRelayerIncentivize;
    address crossChainTransferRelayerIncentivize;

    mapping(address => bytes32) contractAddrToBEP2Symbol;
    mapping(bytes32 => address) BEP2SymbolTocontractAddr;

    uint256 peggyChannelSequence=0;
    uint256 inTransferChannelSequence=0;
    uint256 outTransferChannelSequence=0;
    uint256 timeoutChannelSequence=0;

    event LogRegisterERC20ToBEP2(address contractAddr, uint256 peggyAmount, address bep2T0kenOwner, bytes32 bep2TokenSymbol);

    event LogTokenBind(address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);
    event LogInvalidTokenBind(address contractAddr, bytes32 bep2TokenSymbol, address bep2TokenOwner, uint256 totalSupply, uint256 peggyAmount);

    event LogCrossChainTransfer(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayReward, uint256 sequence);

    event LogHandleCrossChainTransferPackageInSuccess(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol);
    event LogHandleCrossChainTransferPackageInTimeout(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 handleTime);
    event LogHandleCrossChainTransferPackageInInsufficientBalance(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol);
    event LogHandleCrossChainTransferPackageInUnbindedToken(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol);

    constructor(address lightClientContractAddr, address tendermintHeaderSyncRelayerIncentivizeContract, address crossChainTransferRelayerIncentivizeContract) public {
        lightClientContract = lightClientContractAddr;
        tendermintHeaderSyncRelayerIncentivize = tendermintHeaderSyncRelayerIncentivizeContract;
        crossChainTransferRelayerIncentivize= crossChainTransferRelayerIncentivizeContract
    }

    function calculateRwardForTendermintHeaderSyncer(uint256 reward) public pure returns (uint256) {
        return reward/5; //20%
    }
    // | sourceChainID | destinationChainID | channelID | sequence |
    // | 32 bytes      | 32 bytes           |  1 bytes  | 32 bytes |
    function verifiyKey(bytes memory key, uint8 expectedChannelID, uint256 expectedSequence) internal view returns(bool) {
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
        require(verifiyKey(key, 0x01, peggyChannelSequence));
        require(ITendermintLightClient(lightClientContract).validateMerkleProof(height, "ibc", key, value, proof), "invalid merkle proof");
        peggyChannelSequence++;

        address payable tendermintHeaderSubmitter = ITendermintLightClient(lightClientContract).getSubmitter(height);

        BindRequestPackage memory brPackage = decodeBindRequestPackage(value);

        uint256 reward = calculateRwardForTendermintHeaderSyncer(brPackage.relayReward);
        IRelayerIncentivize(tendermintHeaderSyncRelayerIncentivize).addReward.value(reward)(tendermintHeaderSubmitter);
        reward = brPackage.relayReward-reward;
        IRelayerIncentivize(crossChainTransferRelayerIncentivize).addReward.value(reward)(msg.sender);

        uint256 bep2TokenDecimals=100000000; // 10^8
        uint256 erc20TokenDecimals=10**IERC20(brPackage.contractAddr).decimals();
        brPackage.totalSupply = brPackage.totalSupply*erc20TokenDecimals/bep2TokenDecimals;
        brPackage.peggyAmount = brPackage.peggyAmount*erc20TokenDecimals/bep2TokenDecimals;

        if (BEP2SymbolTocontractAddr[brPackage.bep2TokenSymbol]!=address(0x00)||
        IERC20(brPackage.contractAddr).totalSupply()!=brPackage.totalSupply||
        IERC20(brPackage.contractAddr).balanceOf(address(this))!=brPackage.peggyAmount||
        IERC20(brPackage.contractAddr).bep2TokenOwner()!=brPackage.bep2TokenOwner) {
            emit LogInvalidTokenBind(brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.bep2TokenOwner, brPackage.totalSupply, brPackage.peggyAmount);
            return false;
        }
        contractAddrToBEP2Symbol[brPackage.contractAddr] = brPackage.bep2TokenSymbol;
        BEP2SymbolTocontractAddr[brPackage.bep2TokenSymbol] = brPackage.contractAddr;
        emit LogTokenBind(brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount);
        return true;
    }

    function crossChainTransferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime, uint256 relayReward) public payable returns(bool) {
        require(relayReward>minmumRelayReward);
        require(contractAddrToBEP2Symbol[contractAddr]!=0x00);
        if (contractAddr==address(0x0)) {
            require(msg.value==amount+relayReward);
            amount = msg.value;
            emit LogCrossChainTransfer(msg.sender, recipient, amount, contractAddr, bep2TokenSymbolForBNB, expireTime, relayReward, outTransferChannelSequence); //BNB 32bytes
        } else {
            require(msg.value==relayReward);
            require(IERC20(contractAddr).transferFrom(msg.sender, address(this), amount), "failed to transfer token to this contract");
            emit LogCrossChainTransfer(msg.sender, recipient, amount, contractAddr, contractAddrToBEP2Symbol[contractAddr], expireTime, relayReward, outTransferChannelSequence);
        }
        outTransferChannelSequence++;
        return true;
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
        require(verifiyKey(key, 0x02, inTransferChannelSequence));
        require(ITendermintLightClient(lightClientContract).validateMerkleProof(height, "ibc", key, value, proof), "invalid merkle proof");
        inTransferChannelSequence++;

        address payable tendermintHeaderSubmitter = ITendermintLightClient(lightClientContract).getSubmitter(height);

        CrossChainTransferPackage memory cctp = decodeCrossChainTransferPackage(value);

        uint256 reward = calculateRwardForTendermintHeaderSyncer(cctp.relayReward);
        IRelayerIncentivize(tendermintHeaderSyncRelayerIncentivize).addReward.value(reward)(tendermintHeaderSubmitter);
        reward = cctp.relayReward-reward;
        IRelayerIncentivize(crossChainTransferRelayerIncentivize).addReward.value(reward)(msg.sender);

        if (block.timestamp > cctp.expireTime) {
            emit LogHandleCrossChainTransferPackageInTimeout(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol, cctp.expireTime, block.timestamp);
            return false;
        }

        if (cctp.contractAddr==address(0x0)) {
            if (address(this).balance < cctp.amount) {
                emit LogHandleCrossChainTransferPackageInInsufficientBalance(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol);
                return false;
            }
            cctp.recipient.transfer(cctp.amount);
        } else {
            if (contractAddrToBEP2Symbol[cctp.contractAddr]==0x00) {
                emit LogHandleCrossChainTransferPackageInUnbindedToken(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol);
                return false;
            }
            if (IERC20(cctp.contractAddr).balanceOf(address(this))<cctp.amount) {
                emit LogHandleCrossChainTransferPackageInInsufficientBalance(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol);
                return false;
            }
            IERC20(cctp.contractAddr).transfer(cctp.recipient, cctp.amount);
        }
        emit LogHandleCrossChainTransferPackageInSuccess(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol);
        return true;
    }

    function decodeTimeoutPackage(bytes memory value) internal pure returns(TimeoutPackage memory) {
        TimeoutPackage memory timeoutPackage;

        uint256 pos=value.length;

        pos-=32;
        uint256 amount;
        assembly {
            amount := mload(add(value, pos))
        }
        timeoutPackage.amount = amount;

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

        return timeoutPackage;
    }

    function handleCrossChainTransferOutTimeout(uint64 height, bytes memory key, bytes memory value, bytes memory proof) public returns (bool) {
        require(verifiyKey(key, 0x03, timeoutChannelSequence));
        require(ITendermintLightClient(lightClientContract).validateMerkleProof(height, "ibc", key, value, proof), "invalid merkle proof");
        timeoutChannelSequence++;

        address payable tendermintHeaderSubmitter = ITendermintLightClient(lightClientContract).getSubmitter(height);

        TimeoutPackage memory timeoutPackage = decodeTimeoutPackage(value);

        //IRelayerIncentivize(tendermintHeaderSyncRelayerIncentivize).addReward.value(reward)(tendermintHeaderSubmitter);
        //reward = timeoutPackage.relayReward-reward;
        //IRelayerIncentivize(crossChainTransferRelayerIncentivize).addReward.value(reward)(msg.sender);

        if (timeoutPackage.contractAddr==address(0x0)) {
            if (address(this).balance < timeoutPackage.amount) {
                return false;
            }
            timeoutPackage.refundAddr.transfer(timeoutPackage.amount);
        } else {
            if (IERC20(timeoutPackage.contractAddr).balanceOf(address(this))<timeoutPackage.amount) {
                return false;
            }
            IERC20(timeoutPackage.contractAddr).transfer(address(this), timeoutPackage.amount);
        }
        return true;
    }
}