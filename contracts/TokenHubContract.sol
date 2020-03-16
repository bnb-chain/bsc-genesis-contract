pragma solidity 0.5.16;
pragma experimental ABIEncoderV2; //TODO delete later

import "./interface/IERC20.sol";
import "./interface/ILightClient.sol";
import "./interface/IRelayerIncentivize.sol";
import "./Seriality/MerkleProof.sol";

contract TokenHubContract {

    struct BindRequestPackage {
        bytes32 bep2TokenSymbol;
        address contractAddr;
        uint256 totalSupply;
        uint256 peggyAmount;
        uint64  expireTime;
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
        uint64  expireTime;
        uint256 relayReward;
    }

    uint8 constant bindChannelID = 0x01;
    uint8 constant transferInChannelID = 0x02;
    uint8 constant timeoutChannelID=0x03;

    bytes32 constant bep2TokenSymbolForBNB = 0x424E420000000000000000000000000000000000000000000000000000000000; // "BNB"
    uint16 constant sourceChainID         = 3;
    uint16 constant destinationChainID    = 15;
    uint256 constant minimumRelayReward    = 10**16;  // 0.01 BNB

    address public _lightClientContract;
    address public _incentivizeContractForHeaderSyncRelayers;
    address public _incentivizeContractForTransferRelayers;

    mapping(bytes32 => BindRequestPackage) public _bindRequestRecord;
    mapping(address => bytes32) public _contractAddrToBEP2Symbol;
    mapping(bytes32 => address) public _bep2SymbolToContractAddr;

    uint256 public _bindChannelSequence=0;
    uint256 public _transferInChannelSequence=0;
    uint256 public _timeoutChannelSequence=0;

    uint256 public _transferOutChannelSequence=0;
    uint256 public _bindResponseChannelSequence=0;
    uint256 public _transferInFailureChannelSequence=0;

    bool public _alreadyInit=false;

    event LogBindRequest(address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);
    event LogBindSuccess(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount, uint256 decimals);
    event LogBindRejected(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);
    event LogBindTimeout(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount, uint256 expireTime);
    event LogBindInvalidParameter(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);

    event LogCrossChainTransfer(uint256 sequence, address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayReward);

    event LogTransferInSuccess(uint256 sequence, address sender, address recipient, uint256 amount, address contractAddr);
    event LogTransferInFailureTimeout(uint256 sequence, address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime);
    event LogTransferInFailureInsufficientBalance(uint256 sequence, address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 auctualBalance);
    event LogTransferInFailureUnboundedToken(uint256 sequence, address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol);

    event LogRefundTimeoutSuccess(address contractAddr, address refundAddr, uint256 amount);
    event LogRefundTimeoutFailureInsufficientBalance(address contractAddr, address refundAddr, uint256 amount, uint256 auctualBalance);

    constructor() public payable {

    }

    modifier onlyNotInit() {
        require(!_alreadyInit, "the contract already init");
        _;
    }

    modifier onlyAlreadyInit() {
        require(_alreadyInit, "the contract not init yet");
        _;
    }

    function initTokenHub(address lightClientContractAddr,
        address incentivizeContractAddrForHeader,
        address incentivizeContractAddrForTransfer) onlyNotInit public {
        _lightClientContract = lightClientContractAddr;
        _incentivizeContractForHeaderSyncRelayers = incentivizeContractAddrForHeader;
        _incentivizeContractForTransferRelayers = incentivizeContractAddrForTransfer;
        _alreadyInit = true;
    }

    function bep2TokenSymbolConvert(string memory symbol) public view returns(bytes32) {
        bytes32 result;
        assembly {
            result := mload(add(symbol, 32))
        }
        return result;
    }

    //TODO need further discussion
    function calculateRewardForTendermintHeaderRelayer(uint256 reward) internal pure returns (uint256) {
        return reward/5; //20%
    }
    // | length   | prefix | sourceChainID| destinationChainID | channelID | sequence |
    // | 32 bytes | 1 byte | 2 bytes      | 2 bytes            |  1 bytes  | 8 bytes  |
    function verifyKey(bytes memory key, uint8 expectedChannelID, uint256 expectedSequence) public view returns(bool) { // TODO change to internal pure
        if (key.length != 14) {
            return false;
        }

        uint256 ptr;
        assembly {
            ptr := key
        }

        uint8 prefix;
        ptr+=1;
        assembly {
            prefix := mload(ptr)
        }
        if (prefix != 0) {
            return false;
        }

        uint16 chainID;
        ptr+=2;
        assembly {
            chainID := mload(ptr)
        }
        if (chainID != sourceChainID) {
            return false;
        }

        ptr+=2;
        assembly {
            chainID := mload(ptr)
        }
        if (chainID != destinationChainID) {
            return false;
        }

        ptr+=1;
        uint8 channelID;
        assembly {
            channelID := mload(ptr)
        }
        if (channelID != expectedChannelID) {
            return false;
        }

        ptr+=8;
        uint64 sequence;
        assembly {
            sequence := mload(ptr)
        }
        if (sequence != expectedSequence) {
            return false;
        }

        return true;
    }

    // | length   | bep2TokenSymbol | contractAddr | totalSupply | peggyAmount | expireTime | relayReward |
    // | 32 bytes | 32 bytes        | 20 bytes     |  32 bytes   | 32 bytes    | 8 bytes    | 32 bytes    |
    function decodeBindRequestPackage(bytes memory value) public view returns(BindRequestPackage memory) { // TODO change to internal pure
        BindRequestPackage memory brPackage;

        uint256 ptr;
        assembly {
            ptr := value
        }

        bytes32 bep2TokenSymbol;
        ptr+=32;
        assembly {
            bep2TokenSymbol := mload(ptr)
        }
        brPackage.bep2TokenSymbol = bep2TokenSymbol;

        address addr;

        ptr+=20;
        assembly {
            addr := mload(ptr)
        }
        brPackage.contractAddr = addr;

        uint256 tempValue;
        ptr+=32;
        assembly {
            tempValue := mload(ptr)
        }
        brPackage.totalSupply = tempValue;

        ptr+=32;
        assembly {
            tempValue := mload(ptr)
        }
        brPackage.peggyAmount = tempValue;

        ptr+=8;
        uint64 expireTime;
        assembly {
            expireTime := mload(ptr)
        }
        brPackage.expireTime = expireTime;

        ptr+=32;
        assembly {
            tempValue := mload(ptr)
        }
        brPackage.relayReward = tempValue;

        return brPackage;
    }

    function handleBindRequest(uint64 height, bytes memory key, bytes memory value, bytes memory proof) onlyAlreadyInit public returns (bool) {
        require(verifyKey(key, bindChannelID, _bindChannelSequence));
        require(value.length==156, "unexpected bind package size");
        require(ILightClient(_lightClientContract).isHeaderSynced(height));
        bytes32 appHash = ILightClient(_lightClientContract).getAppHash(height);
        require(MerkleProof.validateMerkleProof(appHash, "ibc", key, value, proof), "invalid merkle proof");
        _bindChannelSequence++;

        address payable tendermintHeaderSubmitter = ILightClient(_lightClientContract).getSubmitter(height);

        BindRequestPackage memory brPackage = decodeBindRequestPackage(value);

        uint256 reward = calculateRewardForTendermintHeaderRelayer(brPackage.relayReward);
        IRelayerIncentivize(_incentivizeContractForHeaderSyncRelayers).addReward.value(reward)(tendermintHeaderSubmitter);
        reward = brPackage.relayReward-reward;
        // TODO maybe the reward should be paid to msg.sender directly
        IRelayerIncentivize(_incentivizeContractForTransferRelayers).addReward.value(reward)(msg.sender);

        _bindRequestRecord[brPackage.bep2TokenSymbol]=brPackage;
        emit LogBindRequest(brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount);
        return true;
    }

    function checkSymbol(string memory erc20Symbol, bytes32 bep2TokenSymbol) public view returns(bool) {
        bytes memory erc20SymbolBytes = bytes(erc20Symbol);
        //Upper case string
        for (uint i = 0; i < erc20SymbolBytes.length; i++) {
            if (0x61 <= uint8(erc20SymbolBytes[i]) && uint8(erc20SymbolBytes[i]) <= 0x7A) {
                erc20SymbolBytes[i] = byte(uint8(erc20SymbolBytes[i]) - 0x20);
            }
        }

        bytes memory bep2TokenSymbolBytes = new bytes(32);
        assembly {
            mstore(add(bep2TokenSymbolBytes, 32), bep2TokenSymbol)
        }
        bool symbolMatch = true;
        for(uint256 index=0; index < erc20SymbolBytes.length; index++) {
            if (erc20SymbolBytes[index] != bep2TokenSymbolBytes[index]) {
                symbolMatch = false;
                break;
            }
        }
        return symbolMatch;
    }

    function approveBind(address contractAddr, bytes32 bep2TokenSymbol) onlyAlreadyInit public returns (bool) {
        BindRequestPackage memory brPackage = _bindRequestRecord[bep2TokenSymbol];
        uint256 lockedAmount = brPackage.totalSupply-brPackage.peggyAmount;
        require(contractAddr==brPackage.contractAddr);
        require(brPackage.expireTime>=block.timestamp); // ensure the bind requenst is not expired
        require(IERC20(contractAddr).owner()==msg.sender);
        require(IERC20(contractAddr).allowance(msg.sender, address(this))==lockedAmount);

        string memory erc20Symbol = IERC20(contractAddr).symbol();
        if (!checkSymbol(erc20Symbol, bep2TokenSymbol) ||
            _bep2SymbolToContractAddr[brPackage.bep2TokenSymbol]!=address(0x00)||
            _contractAddrToBEP2Symbol[brPackage.contractAddr]!=bytes32(0x00)||
            IERC20(brPackage.contractAddr).totalSupply()!=brPackage.totalSupply) {
            emit LogBindInvalidParameter(_bindResponseChannelSequence++, brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount);
            return false;
        }
        IERC20(contractAddr).transferFrom(msg.sender, address(this), lockedAmount);
        _contractAddrToBEP2Symbol[brPackage.contractAddr] = brPackage.bep2TokenSymbol;
        _bep2SymbolToContractAddr[brPackage.bep2TokenSymbol] = brPackage.contractAddr;

        delete _bindRequestRecord[bep2TokenSymbol];
        uint256 decimals = IERC20(contractAddr).decimals();
        emit LogBindSuccess(_bindResponseChannelSequence++, brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount, decimals);
        return true;
    }

    function rejectBind(address contractAddr, bytes32 bep2TokenSymbol) onlyAlreadyInit public returns (bool) {
        BindRequestPackage memory brPackage = _bindRequestRecord[bep2TokenSymbol];
        require(contractAddr==brPackage.contractAddr);
        require(IERC20(contractAddr).owner()==msg.sender);
        require(brPackage.expireTime>=block.timestamp); // ensure the bind requenst is not expired
        delete _bindRequestRecord[bep2TokenSymbol];
        emit LogBindRejected(_bindResponseChannelSequence++, brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount);
        return true;
    }

    function expireBind(bytes32 bep2TokenSymbol) onlyAlreadyInit public returns (bool) {
        BindRequestPackage memory brPackage = _bindRequestRecord[bep2TokenSymbol];
        require(brPackage.expireTime!=0); // ensure the brPackage is existing
        require(brPackage.expireTime<block.timestamp);
        delete _bindRequestRecord[bep2TokenSymbol];
        emit LogBindTimeout(_bindResponseChannelSequence++, brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount, brPackage.expireTime);
        return true;
    }

    function crossChainTransferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime, uint256 relayReward) onlyAlreadyInit public payable {
        uint256 erc20TokenDecimals=IERC20(contractAddr).decimals();
        if (erc20TokenDecimals > 8) { // suppose erc20TokenDecimals is 10, then the amount must equal to N*100
            uint256 extraPrecision = 10**(erc20TokenDecimals-8);
            require(amount%extraPrecision==0);
        }
        require(relayReward%(10**10)==0);
        require(relayReward>minimumRelayReward);
        require(_contractAddrToBEP2Symbol[contractAddr]!=0x00);
        if (contractAddr==address(0x0)) {
            require(msg.value==amount+relayReward);
            uint256 calibrateAmount = amount * (10**8) / (10*10); // bep2 token decimals is 8 on BBC
            uint256 calibrateRelayReward = relayReward / (10**10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
            emit LogCrossChainTransfer(_transferOutChannelSequence++, msg.sender, recipient, calibrateAmount, contractAddr, bep2TokenSymbolForBNB, expireTime, calibrateRelayReward); //BNB 32bytes
        } else {
            require(msg.value==relayReward);
            require(IERC20(contractAddr).transferFrom(msg.sender, address(this), amount), "failed to transfer token to this contract");
            uint256 calibrateAmount = amount / (10**erc20TokenDecimals); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
            uint256 calibrateRelayReward = relayReward / (10**10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
            emit LogCrossChainTransfer(_transferOutChannelSequence++, msg.sender, recipient, calibrateAmount, contractAddr, _contractAddrToBEP2Symbol[contractAddr], expireTime, calibrateRelayReward);
        }
    }

    // | length   | bep2TokenSymbol | contractAddr | sender   | recipient | amount   | expireTime | relayReward |
    // | 32 bytes | 32 bytes        | 20 bytes     | 20 bytes | 20 bytes  | 32 bytes | 8 bytes    | 32 bytes    |
    function decodeCrossChainTransferPackage(bytes memory value) public view returns (CrossChainTransferPackage memory) { // TODO change to internal pure
        CrossChainTransferPackage memory cctp;

        uint256 ptr;
        assembly {
            ptr := value
        }

        uint256 tempValue;
        address payable recipient;
        address addr;

        ptr+=32;
        bytes32 bep2TokenSymbol;
        assembly {
            bep2TokenSymbol := mload(ptr)
        }
        cctp.bep2TokenSymbol = bep2TokenSymbol;

        ptr+=20;
        assembly {
            addr := mload(ptr)
        }
        cctp.contractAddr = addr;

        ptr+=20;
        assembly {
            addr := mload(ptr)
        }
        cctp.sender = addr;

        ptr+=20;
        assembly {
            recipient := mload(ptr)
        }
        cctp.recipient = recipient;

        ptr+=32;
        assembly {
            tempValue := mload(ptr)
        }
        cctp.amount = tempValue;

        ptr+=8;
        uint64 expireTime;
        assembly {
            expireTime := mload(ptr)
        }
        cctp.expireTime = expireTime;

        ptr+=32;
        assembly {
            tempValue := mload(ptr)
        }
        cctp.relayReward = tempValue;

        return cctp;
    }

    function handleCrossChainTransferIn(uint64 height, bytes memory key, bytes memory value, bytes memory proof) onlyAlreadyInit public returns (bool) {
        require(verifyKey(key, transferInChannelID, _transferInChannelSequence));
        require(value.length==164, "unexpected transfer package size");
        require(ILightClient(_lightClientContract).isHeaderSynced(height));
        bytes32 appHash = ILightClient(_lightClientContract).getAppHash(height);
        require(MerkleProof.validateMerkleProof(appHash, "ibc", key, value, proof), "invalid merkle proof");

        address payable tendermintHeaderSubmitter = ILightClient(_lightClientContract).getSubmitter(height);

        CrossChainTransferPackage memory cctp = decodeCrossChainTransferPackage(value);

        uint256 reward = calculateRewardForTendermintHeaderRelayer(cctp.relayReward);
        IRelayerIncentivize(_incentivizeContractForHeaderSyncRelayers).addReward.value(reward)(tendermintHeaderSubmitter);
        reward = cctp.relayReward-reward;
        IRelayerIncentivize(_incentivizeContractForTransferRelayers).addReward.value(reward)(msg.sender);

        if (block.timestamp > cctp.expireTime) {
            emit LogTransferInFailureTimeout(_transferInFailureChannelSequence++, cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol, cctp.expireTime);
            return false;
        }

        if (cctp.contractAddr==address(0x0) && cctp.bep2TokenSymbol==bep2TokenSymbolForBNB) {
            if (address(this).balance < cctp.amount) {
                emit LogTransferInFailureInsufficientBalance(_transferInFailureChannelSequence++, cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol, address(this).balance);
                return false;
            }
            cctp.recipient.transfer(cctp.amount);
        } else {
            if (_contractAddrToBEP2Symbol[cctp.contractAddr]!= cctp.bep2TokenSymbol) {
                emit LogTransferInFailureUnboundedToken(_transferInFailureChannelSequence++, cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol);
                return false;
            }
            uint256 tokenHubBalance = IERC20(cctp.contractAddr).balanceOf(address(this));
            if (tokenHubBalance<cctp.amount) {
                emit LogTransferInFailureInsufficientBalance(_transferInFailureChannelSequence++, cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol, tokenHubBalance);
                return false;
            }
            IERC20(cctp.contractAddr).transfer(cctp.recipient, cctp.amount);
        }
        emit LogTransferInSuccess(_transferInChannelSequence++, cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr);
        return true;
    }

    // | length   | refundAmount | contractAddr | refundAddr |
    // | 32 bytes | 32 bytes     | 20 bytes     | 20 bytes   |
    function decodeTimeoutPackage(bytes memory value) public view returns(TimeoutPackage memory) { // TODO change to internal pure
        TimeoutPackage memory timeoutPackage;

        uint256 ptr;
        assembly {
            ptr := value
        }

        ptr+=32;
        uint256 refundAmount;
        assembly {
            refundAmount := mload(ptr)
        }
        timeoutPackage.refundAmount = refundAmount;

        ptr+=20;
        address contractAddr;
        assembly {
            contractAddr := mload(ptr)
        }
        timeoutPackage.contractAddr = contractAddr;

        ptr+=20;
        address payable refundAddr;
        assembly {
            refundAddr := mload(ptr)
        }
        timeoutPackage.refundAddr = refundAddr;


        return timeoutPackage;
    }

    function handleCrossChainTransferOutTimeout(uint64 height, bytes memory key, bytes memory value, bytes memory proof) onlyAlreadyInit public returns (bool) {
        require(verifyKey(key, timeoutChannelID, _timeoutChannelSequence));
        require(value.length==72, "unexpected timeout package size");
        require(ILightClient(_lightClientContract).isHeaderSynced(height));
        bytes32 appHash = ILightClient(_lightClientContract).getAppHash(height);
        require(MerkleProof.validateMerkleProof(appHash, "ibc", key, value, proof), "invalid merkle proof");
        _timeoutChannelSequence++;

        //address payable tendermintHeaderSubmitter = ILightClient(_lightClientContract).getSubmitter(height);

        TimeoutPackage memory timeoutPackage = decodeTimeoutPackage(value);

        //IRelayerIncentivize(_incentivizeContractForHeaderSyncRelayers).addReward.value(reward)(tendermintHeaderSubmitter);
        //reward = timeoutPackage.relayReward-reward;
        //IRelayerIncentivize(_incentivizeContractForTransferRelayers).addReward.value(reward)(msg.sender);

        if (timeoutPackage.contractAddr==address(0x0)) {
            uint256 actualBalance = address(this).balance;
            if (actualBalance < timeoutPackage.refundAmount) {
                emit LogRefundTimeoutFailureInsufficientBalance(timeoutPackage.contractAddr, timeoutPackage.refundAddr, timeoutPackage.refundAmount, actualBalance);
                return false;
            }
            timeoutPackage.refundAddr.transfer(timeoutPackage.refundAmount);
        } else {
            uint256 actualBalance = IERC20(timeoutPackage.contractAddr).balanceOf(address(this));
            if (actualBalance<timeoutPackage.refundAmount) {
                emit LogRefundTimeoutFailureInsufficientBalance(timeoutPackage.contractAddr, timeoutPackage.refundAddr, timeoutPackage.refundAmount, actualBalance);
                return false;
            }
            IERC20(timeoutPackage.contractAddr).transfer(timeoutPackage.refundAddr, timeoutPackage.refundAmount);
        }
        emit LogRefundTimeoutSuccess(timeoutPackage.contractAddr, timeoutPackage.refundAddr, timeoutPackage.refundAmount);
        return true;
    }
}