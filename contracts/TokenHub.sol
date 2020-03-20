pragma solidity 0.5.16;

import "./interface/IERC20.sol";
import "./interface/ILightClient.sol";
import "./interface/IRelayerIncentivize.sol";
import "./mock/MockMerkleProof.sol";
import "./interface/ISystemReward.sol";
import "./interface/ITokenHub.sol";

contract TokenHub is ITokenHub {

    struct BindRequestPackage {
        bytes32 bep2TokenSymbol;
        address contractAddr;
        uint256 totalSupply;
        uint256 peggyAmount;
        uint64  expireTime;
        uint256 relayFee;
    }

    struct RefundPackage {
        uint256 refundAmount;
        address contractAddr;
        address payable refundAddr;
        uint16  reason;
    }

    struct CrossChainTransferPackage {
        bytes32 bep2TokenSymbol;
        address contractAddr;
        address refundAddr;
        address payable recipient;
        uint256 amount;
        uint64  expireTime;
        uint256 relayFee;
    }

    uint8 constant bindChannelID = 0x01;
    uint8 constant transferInChannelID = 0x02;
    uint8 constant refundChannelID=0x03;
    // the store name of the package
    string constant STORE_NAME = "ibc";

    bytes32 constant bep2TokenSymbolForBNB = 0x424E420000000000000000000000000000000000000000000000000000000000; // "BNB"

    uint16 public _sourceChainID;
    uint16 public _destChainID;
    uint256 public _minimumRelayFee; //TODO change minimumRelayFee frequently
    uint256 public _refundRelayReward;

    address public _systemRewardContract;
    address public _lightClientContract;
    address public _incentivizeContractForHeaderSyncRelayers;
    address public _incentivizeContractForTransferRelayers;

    mapping(bytes32 => BindRequestPackage) public _bindRequestRecord;
    mapping(address => bytes32) public _contractAddrToBEP2Symbol;
    mapping(bytes32 => address) public _bep2SymbolToContractAddr;

    uint256 public _bindChannelSequence=0;
    uint256 public _transferInChannelSequence=0;
    uint256 public _refundChannelSequence=0;

    uint256 public _transferOutChannelSequence=0;
    uint256 public _bindResponseChannelSequence=0;
    uint256 public _transferInFailureChannelSequence=0;

    bool public _alreadyInit=false;

    event LogBindRequest(address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);
    event LogBindSuccess(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount, uint256 decimals);
    event LogBindRejected(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);
    event LogBindTimeout(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount, uint256 expireTime);
    event LogBindInvalidParameter(uint256 sequence, address contractAddr, bytes32 bep2TokenSymbol, uint256 totalSupply, uint256 peggyAmount);

    event LogTransferOut(uint256 sequence, address refundAddr, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee);
    event LogBatchTransferOut(uint256 sequence, uint256[] amounts, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime, uint256 relayFee);

    event LogTransferInSuccess(uint256 sequence, address refundAddr, address recipient, uint256 amount, address contractAddr);
    event LogTransferInFailureTimeout(uint256 sequence, address refundAddr, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 expireTime);
    event LogTransferInFailureInsufficientBalance(uint256 sequence, address refundAddr, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol, uint256 auctualBalance);
    event LogTransferInFailureUnboundToken(uint256 sequence, address refundAddr, address recipient, uint256 amount, address contractAddr, bytes32 bep2TokenSymbol);

    event LogRefundSuccess(address contractAddr, address refundAddr, uint256 amount, uint16 reason);
    event LogRefundFailureInsufficientBalance(address contractAddr, address refundAddr, uint256 amount, uint16 reason, uint256 auctualBalance);

    constructor() public {

    }

    modifier onlyNotInit() {
        require(!_alreadyInit, "the contract already init");
        _;
    }

    modifier onlyAlreadyInit() {
        require(_alreadyInit, "the contract not init yet");
        _;
    }

    function initTokenHub(
        address systemRewardContract,
        address lightClientContractAddr,
        address incentivizeContractAddrForHeader,
        address incentivizeContractAddrForTransfer,
        uint16 sourceChainID,
        uint16 destChainID,
        uint256 minimumRelayFee,
        uint256 refundReward) onlyNotInit public payable { //TODO remove payable in testnet and mainnet
        _systemRewardContract = systemRewardContract;
        _lightClientContract = lightClientContractAddr;
        _incentivizeContractForHeaderSyncRelayers = incentivizeContractAddrForHeader;
        _incentivizeContractForTransferRelayers = incentivizeContractAddrForTransfer;
        _sourceChainID=sourceChainID;
        _destChainID=destChainID;
        _minimumRelayFee=minimumRelayFee;
        _refundRelayReward=refundReward;
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
    function verifyKey(bytes memory key, uint8 expectedChannelID, uint256 expectedSequence) internal view returns(bool) {
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
        if (chainID != _sourceChainID) {
            return false;
        }

        ptr+=2;
        assembly {
            chainID := mload(ptr)
        }
        if (chainID != _destChainID) {
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

    // | length   | bep2TokenSymbol | contractAddr | totalSupply | peggyAmount | expireTime | relayFee |
    // | 32 bytes | 32 bytes        | 20 bytes     |  32 bytes   | 32 bytes    | 8 bytes    | 32 bytes    |
    function decodeBindRequestPackage(bytes memory value) internal pure returns(BindRequestPackage memory) {
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
        brPackage.relayFee = tempValue;

        return brPackage;
    }

    function handleBindPackage(uint64 height, bytes calldata key, bytes calldata value, bytes calldata proof) onlyAlreadyInit external returns (bool) {
        require(verifyKey(key, bindChannelID, _bindChannelSequence));
        require(value.length==156, "unexpected bind package size");
        require(ILightClient(_lightClientContract).isHeaderSynced(height));
        bytes32 appHash = ILightClient(_lightClientContract).getAppHash(height);
        require(MockMerkleProof.validateMerkleProof(appHash, STORE_NAME, key, value, proof), "invalid merkle proof");
        _bindChannelSequence++;

        address payable tendermintHeaderSubmitter = ILightClient(_lightClientContract).getSubmitter(height);

        BindRequestPackage memory brPackage = decodeBindRequestPackage(value);

        uint256 reward = calculateRewardForTendermintHeaderRelayer(brPackage.relayFee);
        IRelayerIncentivize(_incentivizeContractForHeaderSyncRelayers).addReward.value(reward)(tendermintHeaderSubmitter);
        reward = brPackage.relayFee-reward;
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
        require(contractAddr==brPackage.contractAddr, "contact address doesn't equal to the contract address in bind request");
        require(IERC20(contractAddr).owner()==msg.sender, "only erc20 owner can approve this bind request");
        require(IERC20(contractAddr).allowance(msg.sender, address(this))==lockedAmount, "allowance doesn't equal to (totalSupply - peggyAmount)");

        if (brPackage.expireTime<block.timestamp) {
            emit LogBindTimeout(_bindResponseChannelSequence++, brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount, brPackage.expireTime);
            delete _bindRequestRecord[bep2TokenSymbol];
            return false;
        }

        string memory erc20Symbol = IERC20(contractAddr).symbol();
        if (!checkSymbol(erc20Symbol, bep2TokenSymbol) ||
            _bep2SymbolToContractAddr[brPackage.bep2TokenSymbol]!=address(0x00)||
            _contractAddrToBEP2Symbol[brPackage.contractAddr]!=bytes32(0x00)||
            IERC20(brPackage.contractAddr).totalSupply()!=brPackage.totalSupply) {
            delete _bindRequestRecord[bep2TokenSymbol];
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
        require(contractAddr==brPackage.contractAddr, "contact address doesn't equal to the contract address in bind request");
        require(IERC20(contractAddr).owner()==msg.sender, "only erc20 owner can reject");
        delete _bindRequestRecord[bep2TokenSymbol];
        emit LogBindRejected(_bindResponseChannelSequence++, brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount);
        return true;
    }

    function expireBind(bytes32 bep2TokenSymbol) onlyAlreadyInit public returns (bool) {
        BindRequestPackage memory brPackage = _bindRequestRecord[bep2TokenSymbol];
        require(brPackage.expireTime<block.timestamp, "bind request is not expired");
        delete _bindRequestRecord[bep2TokenSymbol];
        emit LogBindTimeout(_bindResponseChannelSequence++, brPackage.contractAddr, brPackage.bep2TokenSymbol, brPackage.totalSupply, brPackage.peggyAmount, brPackage.expireTime);
        return true;
    }

    // | length   | bep2TokenSymbol | contractAddr | sender   | recipient | amount   | expireTime | relayFee |
    // | 32 bytes | 32 bytes        | 20 bytes     | 20 bytes | 20 bytes  | 32 bytes | 8 bytes    | 32 bytes    |
    function decodeTransferInPackage(bytes memory value) internal pure returns (CrossChainTransferPackage memory) {
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
        cctp.refundAddr = addr;

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
        cctp.relayFee = tempValue;

        return cctp;
    }

    function handleTransferInPackage(uint64 height, bytes calldata key, bytes calldata value, bytes calldata proof) onlyAlreadyInit external returns (bool) {
        require(verifyKey(key, transferInChannelID, _transferInChannelSequence));
        require(value.length==164, "unexpected transfer package size");
        require(ILightClient(_lightClientContract).isHeaderSynced(height));
        bytes32 appHash = ILightClient(_lightClientContract).getAppHash(height);
        require(MockMerkleProof.validateMerkleProof(appHash, STORE_NAME, key, value, proof), "invalid merkle proof");
        _transferInChannelSequence++;

        address payable tendermintHeaderSubmitter = ILightClient(_lightClientContract).getSubmitter(height);

        CrossChainTransferPackage memory cctp = decodeTransferInPackage(value);

        uint256 reward = calculateRewardForTendermintHeaderRelayer(cctp.relayFee);
        IRelayerIncentivize(_incentivizeContractForHeaderSyncRelayers).addReward.value(reward)(tendermintHeaderSubmitter);
        reward = cctp.relayFee-reward;
        IRelayerIncentivize(_incentivizeContractForTransferRelayers).addReward.value(reward)(msg.sender);

        if (block.timestamp > cctp.expireTime) {
            emit LogTransferInFailureTimeout(_transferInFailureChannelSequence++, cctp.refundAddr, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol, cctp.expireTime);
            return false;
        }

        if (cctp.contractAddr==address(0x0) && cctp.bep2TokenSymbol==bep2TokenSymbolForBNB) {
            if (address(this).balance < cctp.amount) {
                emit LogTransferInFailureInsufficientBalance(_transferInFailureChannelSequence++, cctp.refundAddr, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol, address(this).balance);
                return false;
            }
            cctp.recipient.transfer(cctp.amount);
        } else {
            if (_contractAddrToBEP2Symbol[cctp.contractAddr]!= cctp.bep2TokenSymbol) {
                emit LogTransferInFailureUnboundToken(_transferInFailureChannelSequence++, cctp.refundAddr, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol);
                return false;
            }
            uint256 tokenHubBalance = IERC20(cctp.contractAddr).balanceOf(address(this));
            if (tokenHubBalance<cctp.amount) {
                emit LogTransferInFailureInsufficientBalance(_transferInFailureChannelSequence++, cctp.refundAddr, cctp.recipient, cctp.amount, cctp.contractAddr, cctp.bep2TokenSymbol, tokenHubBalance);
                return false;
            }
            IERC20(cctp.contractAddr).transfer(cctp.recipient, cctp.amount);
        }
        emit LogTransferInSuccess(_transferInChannelSequence, cctp.refundAddr, cctp.recipient, cctp.amount, cctp.contractAddr);
        return true;
    }

    // | length   | refundAmount | contractAddr | refundAddr | failureReason |
    // | 32 bytes | 32 bytes     | 20 bytes     | 20 bytes   | 2 bytes       |
    function decodeRefundPackage(bytes memory value) internal pure returns(RefundPackage memory) {
        RefundPackage memory refundPackage;

        uint256 ptr;
        assembly {
            ptr := value
        }

        ptr+=32;
        uint256 refundAmount;
        assembly {
            refundAmount := mload(ptr)
        }
        refundPackage.refundAmount = refundAmount;

        ptr+=20;
        address contractAddr;
        assembly {
            contractAddr := mload(ptr)
        }
        refundPackage.contractAddr = contractAddr;

        ptr+=20;
        address payable refundAddr;
        assembly {
            refundAddr := mload(ptr)
        }
        refundPackage.refundAddr = refundAddr;

        ptr+=2;
        uint16 reason;
        assembly {
            reason := mload(ptr)
        }
        refundPackage.reason = reason;


        return refundPackage;
    }

    function handleRefundPackage(uint64 height, bytes calldata key, bytes calldata value, bytes calldata proof) onlyAlreadyInit external returns (bool) {
        require(verifyKey(key, refundChannelID, _refundChannelSequence));
        require(value.length==74, "unexpected refund package size");
        require(ILightClient(_lightClientContract).isHeaderSynced(height));
        bytes32 appHash = ILightClient(_lightClientContract).getAppHash(height);
        require(MockMerkleProof.validateMerkleProof(appHash, STORE_NAME, key, value, proof), "invalid merkle proof");
        _refundChannelSequence++;

        address payable tendermintHeaderSubmitter = ILightClient(_lightClientContract).getSubmitter(height);
        //TODO system reward, need further discussion,
        //TODO taking malicious refund cases caused by inconsistent total supply into consideration, so this reward must be less than minimum relay fee
        uint256 reward = calculateRewardForTendermintHeaderRelayer(_refundRelayReward);
        ISystemReward(_systemRewardContract).claimRewards(tendermintHeaderSubmitter, reward);
        reward = _refundRelayReward-reward;
        ISystemReward(_systemRewardContract).claimRewards(msg.sender, reward);

        RefundPackage memory refundPackage = decodeRefundPackage(value);
        if (refundPackage.contractAddr==address(0x0)) {
            uint256 actualBalance = address(this).balance;
            if (actualBalance < refundPackage.refundAmount) {
                emit LogRefundFailureInsufficientBalance(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason, actualBalance);
                return false;
            }
            refundPackage.refundAddr.transfer(refundPackage.refundAmount);
        } else {
            uint256 actualBalance = IERC20(refundPackage.contractAddr).balanceOf(address(this));
            if (actualBalance<refundPackage.refundAmount) {
                emit LogRefundFailureInsufficientBalance(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason, actualBalance);
                return false;
            }
            IERC20(refundPackage.contractAddr).transfer(refundPackage.refundAddr, refundPackage.refundAmount);
        }
        emit LogRefundSuccess(refundPackage.contractAddr, refundPackage.refundAddr, refundPackage.refundAmount, refundPackage.reason);
        return true;
    }

    function transferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime, uint256 relayFee) onlyAlreadyInit external payable returns (bool) {
        require(relayFee%(10**10)==0, "relayFee is must be N*10^10");
        require(relayFee>=_minimumRelayFee, "relayFee is too little");
        require(expireTime > block.timestamp, "expireTime must be future time");
        uint256 convertedRelayFee = relayFee / (10**10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
        bytes32 bep2TokenSymbol;
        uint256 convertedAmount;
        if (contractAddr==address(0x0)) {
            require(msg.value==amount+relayFee, "received BNB amount doesn't equal to the sum of transfer amount and relayFee");
            convertedAmount = amount / (10**10); // native bnb decimals is 8 on BBC, while the native bnb decimals on BSC is 18
            bep2TokenSymbol=bep2TokenSymbolForBNB;
        } else {
            uint256 erc20TokenDecimals=IERC20(contractAddr).decimals();
            if (erc20TokenDecimals > 8) {
                uint256 extraPrecision = 10**(erc20TokenDecimals-8);
                require(amount%extraPrecision==0, "invalid transfer amount: precision loss in amount conversion");
            }
            bep2TokenSymbol = _contractAddrToBEP2Symbol[contractAddr];
            require(bep2TokenSymbol!=bytes32(0x00), "the contract has not been bind to any bep2 token");
            require(msg.value==relayFee, "received BNB amount doesn't equal to relayFee");
            require(IERC20(contractAddr).transferFrom(msg.sender, address(this), amount));
            convertedAmount = amount * (10**8)/ (10**erc20TokenDecimals); // bep2 token decimals is 8 on BBC
        }
        emit LogTransferOut(_transferOutChannelSequence++, msg.sender, recipient, convertedAmount, contractAddr, bep2TokenSymbol, expireTime, convertedRelayFee);
        return true;
    }

    function batchTransferOut(address[] calldata recipientAddrs, uint256[] calldata amounts, address[] calldata refundAddrs, address contractAddr, uint256 expireTime, uint256 relayFee) onlyAlreadyInit external payable returns (bool) {
        require(recipientAddrs.length == amounts.length, "Length of recipientAddrs doesn't equal to length of amounts");
        require(recipientAddrs.length == refundAddrs.length, "Length of recipientAddrs doesn't equal to length of refundAddrs");
        require(relayFee/amounts.length>=_minimumRelayFee, "relayFee is too little");
        require(relayFee%(10**10)==0, "relayFee must be N*10^10");
        require(expireTime > block.timestamp, "expireTime must be future time");
        uint256 totalAmount = 0;
        for (uint i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        uint256[] memory convertedAmounts = new uint256[](amounts.length);
        bytes32 bep2TokenSymbol;
        if (contractAddr==address(0x0)) {
            for (uint8 i = 0; i < amounts.length; i++) {
                require(amounts[i]%10**10==0, "invalid transfer amount");
                convertedAmounts[i] = amounts[i]/10**10;
            }
            require(msg.value==totalAmount+relayFee, "received BNB amount doesn't equal to the sum of transfer amount and relayFee");
            bep2TokenSymbol=bep2TokenSymbolForBNB;
        } else {
            uint256 erc20TokenDecimals=IERC20(contractAddr).decimals();
            for (uint i = 0; i < amounts.length; i++) {
                require((amounts[i]*(10**8)%(10**erc20TokenDecimals))==0, "invalid transfer amount");
                convertedAmounts[i] = amounts[i]*(10**8)/(10**erc20TokenDecimals);
            }
            bep2TokenSymbol = _contractAddrToBEP2Symbol[contractAddr];
            require(bep2TokenSymbol!=bytes32(0x00), "the contract has not been bind to any bep2 token");
            require(msg.value==relayFee, "received BNB amount doesn't equal to relayFee");
            require(IERC20(contractAddr).transferFrom(msg.sender, address(this), totalAmount));
        }
        emit LogBatchTransferOut(_transferOutChannelSequence++, convertedAmounts, contractAddr, bep2TokenSymbol, expireTime, relayFee/(10**10));
        return true;
    }
}