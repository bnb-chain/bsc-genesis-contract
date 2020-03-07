pragma solidity 0.5.16;

import "IERC20.sol";
import "ITendermintLightClient.sol";
import "IRelayerIncentivize.sol";
import "MerkleProof.sol";

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
        uint64 expireTime;
        uint256 relayReward;
    }

    uint8 constant bindChannelID = 0x01;
    uint8 constant transferInChannelID = 0x02;
    uint8 constant timeoutChannelID=0x03;

    bytes32 constant bep2TokenSymbolForBNB = 0x424E420000000000000000000000000000000000000000000000000000000000; // "BNB"
    bytes2 constant sourceChainID         = 0x0001; // 1
    bytes2 constant destinationChainID    = 0x000f; // 15
    uint256 constant minimumRelayReward    = 10**16;  // 0.01 BNB

    address public _lightClientContract;
    address public _incentivizeContractForHeaderSyncRelayers;
    address public _incentivizeContractForTransferRelayers;

    mapping(bytes32 => BindRequestPackage) public _bindRequestRecord;
    mapping(address => bytes32) public _contractAddrToBEP2Symbol;
    mapping(bytes32 => address) public _bep2SymbolToContractAddr;

    uint256 public _bindChannelSequence=0;
    uint256 public _transferInChannelSequence=0;
    uint256 public _transferOutChannelSequence=0;
    uint256 public _timeoutChannelSequence=0;
    bool public _alreadyInit=false;

    event LogBindRequest(address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);
    event LogBindSuccess(address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);
    event LogBindRejected(address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);
    event LogBindFailure(address contractAddr, bytes32 bep2TokenSymbol, address bep2TokenOwner, uint256 totalSupply, uint256 peggyAmount);

    event LogCrossChainTransfer(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayReward, uint256 sequence);

    event LogTransferInSuccess(address sender, address recipient, uint256 amount, address contractAddr);
    event LogTransferInFailureTimeout(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 handleTime);
    event LogTransferInFailureInsufficientBalance(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 auctualBalance);
    event LogTransferInFailureUnbindedToken(address sender, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol);

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

    //TODO add authority check
    function initTokenHub(address lightClientContractAddr,
        address incentivizeContractAddrForHeader,
        address incentivizeContractAddrForTransfer) public {
        _lightClientContract = lightClientContractAddr;
        _incentivizeContractForHeaderSyncRelayers = incentivizeContractAddrForHeader;
        _incentivizeContractForTransferRelayers = incentivizeContractAddrForTransfer;
    }

    //TODO need further discussion
    function calculateRewardForTendermintHeaderRelayer(uint256 reward) internal pure returns (uint256) {
        return reward/5; //20%
    }
    // | length   | prefix | sourceChainID| destinationChainID | channelID | sequence |
    // | 32 bytes | 1 byte | 2 bytes      | 2 bytes            |  1 bytes  | 8 bytes  |
    function verifyKey(bytes memory key, uint8 expectedChannelID, uint256 expectedSequence) internal view returns(bool) {
        uint256 length;
        assembly {
            length := mload(add(key, 0))
        }
        if (length != 0x4a) { //74
            return false;
        }

        uint256 pos=0;

        bytes2 chainID;
        pos+=2+1;
        assembly {
            chainID := mload(add(key, pos))
        }
        if (chainID != sourceChainID) {
            return false;
        }

        pos+=2;
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
        require(verifyKey(key, bindChannelID, _bindChannelSequence));
        bytes32 appHash = ITendermintLightClient(_lightClientContract).getAppHash(height);
        require(MerkleProof.validateMerkleProof(appHash, "ibc", key, value, proof), "invalid merkle proof");
        _bindChannelSequence++;

        address payable tendermintHeaderSubmitter = ITendermintLightClient(_lightClientContract).getSubmitter(height);

        BindRequestPackage memory brPackage = decodeBindRequestPackage(value);

        uint256 reward = calculateRewardForTendermintHeaderRelayer(brPackage.relayReward);
        IRelayerIncentivize(_incentivizeContractForHeaderSyncRelayers).addReward.value(reward)(tendermintHeaderSubmitter);
        reward = brPackage.relayReward-reward;
        // TODO maybe the reward should be paid to msg.sender directly
        IRelayerIncentivize(_incentivizeContractForTransferRelayers).addReward.value(reward)(msg.sender);

        if (_bindRequestRecord[brPackage.bep2TokenSymbol].bep2TokenSymbol == brPackage.bep2TokenSymbol) {
            return false;
        }
        _bindRequestRecord[brPackage.bep2TokenSymbol]=brPackage;
        emit LogBindRequest(brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount);
        return true;
    }

    function approveBind(address contractAddr, bytes32 bep2TokenSymbol) public returns (bool) {
        BindRequestPackage memory brPackage = _bindRequestRecord[bep2TokenSymbol];
        require(contractAddr==brPackage.contractAddr);
        require(IERC20(contractAddr).owner()==msg.sender);
        //TODO add bep2 token symbol and erc20 contract symbol checking
        if (_bep2SymbolToContractAddr[brPackage.bep2TokenSymbol]!=address(0x00)||
            IERC20(brPackage.contractAddr).totalSupply()!=brPackage.totalSupply||
            IERC20(brPackage.contractAddr).balanceOf(address(this))+brPackage.peggyAmount!=brPackage.totalSupply) {
            emit LogBindFailure(brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.bep2TokenOwner, brPackage.totalSupply, brPackage.peggyAmount);
            return false;
        }
        _contractAddrToBEP2Symbol[brPackage.contractAddr] = brPackage.bep2TokenSymbol;
        _bep2SymbolToContractAddr[brPackage.bep2TokenSymbol] = brPackage.contractAddr;

        delete _bindRequestRecord[bep2TokenSymbol];
        emit LogBindSuccess(brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount);
        return true;
    }

    function rejectBind(address contractAddr, bytes32 bep2TokenSymbol) public returns (bool) {
        BindRequestPackage memory brPackage = _bindRequestRecord[bep2TokenSymbol];
        require(contractAddr==brPackage.contractAddr);
        require(IERC20(contractAddr).owner()==msg.sender);
        delete _bindRequestRecord[bep2TokenSymbol];
        emit LogBindRejected(brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount);
        return true;
    }

    function crossChainTransferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime, uint256 relayReward) public payable {
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
            emit LogCrossChainTransfer(msg.sender, recipient, calibrateAmount, contractAddr, bep2TokenSymbolForBNB, expireTime, calibrateRelayReward, _transferOutChannelSequence); //BNB 32bytes
        } else {
            require(msg.value==relayReward);
            require(IERC20(contractAddr).transferFrom(msg.sender, address(this), amount), "failed to transfer token to this contract");
            uint256 calibrateAmount = amount / (10**erc20TokenDecimals); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
            uint256 calibrateRelayReward = relayReward / (10**10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
            emit LogCrossChainTransfer(msg.sender, recipient, calibrateAmount, contractAddr, _contractAddrToBEP2Symbol[contractAddr], expireTime, calibrateRelayReward, _transferOutChannelSequence);
        }
        _transferOutChannelSequence++;
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

        pos+=8;
        uint64 expireTime;
        assembly {
            expireTime := mload(add(value, pos))
        }
        cctp.expireTime = expireTime;

        pos+=32;
        assembly {
            tempValue := mload(add(value, pos))
        }
        cctp.relayReward = tempValue;

        return cctp;
    }

    function handleCrossChainTransferIn(uint64 height, bytes memory key, bytes memory value, bytes memory proof) public returns (bool) {
        require(verifyKey(key, transferInChannelID, _transferInChannelSequence));
        bytes32 appHash = ITendermintLightClient(_lightClientContract).getAppHash(height);
        require(MerkleProof.validateMerkleProof(appHash, "ibc", key, value, proof), "invalid merkle proof");
        _transferInChannelSequence++;

        address payable tendermintHeaderSubmitter = ITendermintLightClient(_lightClientContract).getSubmitter(height);

        CrossChainTransferPackage memory cctp = decodeCrossChainTransferPackage(value);

        uint256 reward = calculateRewardForTendermintHeaderRelayer(cctp.relayReward);
        IRelayerIncentivize(_incentivizeContractForHeaderSyncRelayers).addReward.value(reward)(tendermintHeaderSubmitter);
        reward = cctp.relayReward-reward;
        IRelayerIncentivize(_incentivizeContractForTransferRelayers).addReward.value(reward)(msg.sender);

        if (block.timestamp > cctp.expireTime) {
            emit LogTransferInFailureTimeout(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol, cctp.expireTime, block.timestamp);
            return false;
        }

        if (cctp.contractAddr==address(0x0) && cctp.bep2TokenSymbol==bep2TokenSymbolForBNB) {
            if (address(this).balance < cctp.amount) {
                emit LogTransferInFailureInsufficientBalance(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol, address(this).balance);
                return false;
            }
            cctp.recipient.transfer(cctp.amount);
        } else {
            if (_contractAddrToBEP2Symbol[cctp.contractAddr]!= cctp.bep2TokenSymbol) {
                emit LogTransferInFailureUnbindedToken(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol);
                return false;
            }
            uint256 tokenHubBalance = IERC20(cctp.contractAddr).balanceOf(address(this));
            if (tokenHubBalance<cctp.amount) {
                emit LogTransferInFailureInsufficientBalance(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol, tokenHubBalance);
                return false;
            }
            IERC20(cctp.contractAddr).transfer(cctp.recipient, cctp.amount);
        }
        emit LogTransferInSuccess(cctp.sender, cctp.recipient, cctp.amount, cctp.contractAddr);
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
        require(verifyKey(key, timeoutChannelID, _timeoutChannelSequence));
        bytes32 appHash = ITendermintLightClient(_lightClientContract).getAppHash(height);
        require(MerkleProof.validateMerkleProof(appHash, "ibc", key, value, proof), "invalid merkle proof");
        _timeoutChannelSequence++;

        //address payable tendermintHeaderSubmitter = ITendermintLightClient(_lightClientContract).getSubmitter(height);

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