pragma solidity ^0.5.15;

import {System} from "./System.sol";
import "./Seriality/TypesToBytes.sol";
import "./Seriality/BytesToTypes.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";
import "./interface/ILightClient.sol";
import "./interface/ICrossChainTransfer.sol";
import "./interface/ISystemReward.sol";


contract BSCValidatorSet is System {
  // keep consistent with the channel id in BBC;
  uint8 public constant CHANNEL_ID =  8;

  // use '_' as connector
  bytes constant CONNECTOR = "_";
  // {20 bytes consensusAddress} + {20 bytes feeAddress} + {20 bytes BBCFeeAddress}
  uint constant  VALIDATOR_BYTES_LENGTH = 60;
  // will not transfer value less than 0.1 BNB for validators
  uint256 constant public DUSTY_INCOMING = 1e17;
  // extra fee for cross chain transfer,should keep consistent with cross chain transfer smart contract.
  uint256 constant public EXTRA_FEE = 1e16;
  // will reward relayer at most 0.1 BNB.
  uint256 constant public RELAYER_REWARD = 1e17;

  // the precision of cross chain value transfer.
  uint256 constant PRECISION = 1e8;
  uint256 constant EXPIRE_TIME_SECOND_GAP = 1000;
  // the store name of the package
  string constant STORE_NAME = "ibc";

  string public constant fromChainId = "Binance-Chain-Tigris"; // means Binance-Chain-Tigris
  string public constant toChainId = "714";  // means "714"
  address payable public constant initSystemRewardAddr = 0x0000000000000000000000000000000000001002;
  address public constant  initCrossTransferAddr = 0x0000000000000000000000000000000000001004;
  address public constant initLightClientAddr = 0x0000000000000000000000000000000000001003;
  address public constant initTokenContract = 0x0000000000000000000000000000000000001005;
  bytes public constant initValidatorSetBytes = hex"acf8eccdca12a0eb6ae4fb1431e26c44e66decdbacf8eccdca12a0eb6ae4fb1431e26c44e66decdbacf8eccdca12a0eb6ae4fb1431e26c44e66decdb";

  bool public alreadyInit;
  // used for generate key
  bytes public keyPrefix;

  // other contract
  address public  tokenContract;
  ILightClient lightClient;
  ICrossChainTransfer crossTransfer;
  ISystemReward systemReward;


  // state of this contract
  Validator[] public currentValidatorSet;
  uint256 public sequence;
  uint256 public totalInComing;
  uint256 public previousDepositHeight;
  // key is the `consensusAddress` of `Validator`,
  // value is the index of the element in `currentValidatorSet`.
  mapping(address =>uint256) currentValidatorSetMap;

  struct Validator{
    address consensusAddress;
    address payable feeAddress;
    address BBCFeeAddress;
    uint256 incoming;
  }

  modifier onlyNotInit() {
    require(!alreadyInit, "the contract already init");
    _;
  }

  modifier onlyInit() {
    require(alreadyInit, "the contract not init yet");
    _;
  }

  modifier sequenceInOrder(uint256 _sequence) {
    require(_sequence == sequence+1, "sequence not in order");
    _;
  }

  modifier blockSynced(uint256 _height) {
    require(lightClient.isBlockSynced(_height), "light client not sync the block yet");
    _;
  }

  modifier enoughInComing() {
    require(address(this).balance>=totalInComing, "panic: no enough incoming to distribute");
    _;
  }

  modifier noEmptyDeposit() {
    require(msg.value > 0, "deposit value is zero");
    _;
  }

  modifier onlyDepositOnce() {
    require(block.number > previousDepositHeight, "can not deposit twice in one block");
    _;
    previousDepositHeight = block.number;
  }

  event validatorSetUpdated();
  event batchTransfer(uint256 indexed amount);
  event systemTransfer(uint256 indexed amount);
  event directTransfer(address payable indexed validator, uint256 indexed amount);
  event deprecatedDeposit(address indexed validator, uint256 indexed amount);
  event validatorDeposit(address indexed validator, uint256 indexed amount);
  event contractAddrUpdate(address systemRewardAddr, address crossTransferAddr, address lightClientAddr, address tokenContract);


  function init() external onlyNotInit{
    Validator[] memory validatorSet = parseValidatorSet(initValidatorSetBytes);
    (bool passVerify, string memory errorMsg) = verifyValidatorSet(validatorSet);
    require(passVerify,errorMsg);
    for(uint i = 0;i<validatorSet.length;i++){
      currentValidatorSet.push(validatorSet[i]);
      currentValidatorSetMap[validatorSet[i].consensusAddress] = i+1;
    }
    tokenContract = initTokenContract;
    lightClient = ILightClient(initLightClientAddr);
    crossTransfer = ICrossChainTransfer(initCrossTransferAddr);
    systemReward = ISystemReward(initSystemRewardAddr);
    keyPrefix = generatePrefixKey(fromChainId, toChainId);
    alreadyInit = true;
  }

  function updateContractAddr(address _systemRewardAddr, address _crossTransferAddr, address _lightClientAddr, address _tokenContract) external onlyInit onlySystem{
    tokenContract = _tokenContract;
    lightClient = ILightClient(_lightClientAddr);
    crossTransfer = ICrossChainTransfer(_crossTransferAddr);
    systemReward = ISystemReward(_systemRewardAddr);
    emit contractAddrUpdate(_systemRewardAddr,_crossTransferAddr,_lightClientAddr,_tokenContract);
  }

  /*********************** External Functions **************************/

  function deposit(address valAddr) external payable onlySystem onlyInit noEmptyDeposit onlyDepositOnce{
    uint256 value = msg.value;
    uint256 index = currentValidatorSetMap[valAddr];
    if (index>0){
      Validator storage validator = currentValidatorSet[index-1];
      validator.incoming += value;
      totalInComing += value;
      emit validatorDeposit(valAddr,value);
    }else{
      // get incoming from deprecated validator;
      // will not add it to the `totalInComing`;
      emit deprecatedDeposit(valAddr,value);
    }
  }

  function updateValidatorSet(bytes calldata validatorSetBytes, bytes calldata proof, uint256 height, uint256 packageSequence) external onlyInit sequenceInOrder(packageSequence) blockSynced(height){
    // verify key value against light client;
    bytes memory key = generateKey(packageSequence);
    bool valid = lightClient.validateMerkleProof(height, STORE_NAME, key, validatorSetBytes, proof);
    require(valid, "the package is invalid against its proof");

    // do deserialize and verify.
    Validator[] memory validatorSet = parseValidatorSet(validatorSetBytes);
    (bool passVerify, string memory errorMsg) = verifyValidatorSet(validatorSet);
    require(passVerify,errorMsg);

    // do calculate distribution
    (address[] memory crossAddrs, uint256[] memory crossAmounts, address[] memory crossRefundAddrs,
      address payable[] memory directAddrs, uint256[] memory directAmounts, uint256 crossTotal) = calDistribute();

    // do cross chain transfer
    if(crossTotal > 0){
      crossTransfer.batchCrossChainTransfer.value(crossTotal)(crossAddrs, crossAmounts, crossRefundAddrs, tokenContract, block.timestamp + EXPIRE_TIME_SECOND_GAP);
      emit batchTransfer(crossTotal);
    }

    // do direct transfer
    if(directAddrs.length>0){
      for(uint i = 0;i<directAddrs.length;i++){
        directAddrs[i].transfer(directAmounts[i]);
        emit directTransfer(directAddrs[i], directAmounts[i]);
      }
    }

    // do dusk transfer
    if(address(this).balance>0){
      emit systemTransfer(address(this).balance);
      address payable systemPayable = address(uint160(address(systemReward)));
      systemPayable.transfer(address(this).balance);
    }

    // do update state
    doUpdateState(validatorSet);

    // do claim reward, will reward to account rather than smart contract.
    systemReward.claimRewards(msg.sender, RELAYER_REWARD);
    emit validatorSetUpdated();
  }

  function getValidators()external view returns(address[] memory) {
    uint n = currentValidatorSet.length;
    address[] memory consensusAddrs = new address[](n);
    for(uint i = 0;i<n;i++){
      consensusAddrs[i] = currentValidatorSet[i].consensusAddress;
    }
    return consensusAddrs;
  }

  /*********************** Internal Functions **************************/

  function parseValidatorSet(bytes memory validatorSetBytes) private pure returns(Validator[] memory){
    uint length = validatorSetBytes.length;
    require(length > 0, "the validatorSetBytes should not be empty");
    require(length % VALIDATOR_BYTES_LENGTH == 0, "the length of validatorSetBytes should be times of 60");
    uint n = length/VALIDATOR_BYTES_LENGTH;
    Validator[] memory validatorSet = new Validator[](n);
    for(uint i = 0;i<n;i++){
      validatorSet[i].consensusAddress = BytesToTypes.bytesToAddress(i*VALIDATOR_BYTES_LENGTH+20,validatorSetBytes);
      validatorSet[i].feeAddress = address(uint160(BytesToTypes.bytesToAddress(i*VALIDATOR_BYTES_LENGTH+40,validatorSetBytes)));
      validatorSet[i].BBCFeeAddress = BytesToTypes.bytesToAddress(i*VALIDATOR_BYTES_LENGTH+60,validatorSetBytes);
    }
    return validatorSet;
  }

  function verifyValidatorSet(Validator[] memory validatorSet) private pure returns(bool,string memory){
    uint n = validatorSet.length;
    for(uint i = 0;i<n;i++){
      for(uint j = 0;j<i;j++){
        if(validatorSet[i].consensusAddress == validatorSet[j].consensusAddress ){
          return (false, "duplicate consensus address of validatorSet");
        }
      }
    }
    return (true,"");
  }

  function calDistribute() private view enoughInComing returns (address[] memory, uint256[] memory,
      address[] memory, address payable[]memory, uint256[] memory, uint256){
    uint n = currentValidatorSet.length;
    uint crossSize;
    uint directSize;
    for(uint i = 0;i<n;i++){
      if(currentValidatorSet[i].incoming >= DUSTY_INCOMING){
        crossSize ++;
      }else if (currentValidatorSet[i].incoming > 0){
        directSize ++;
      }
    }
    //cross transfer
    address[] memory crossAddrs = new address[](crossSize);
    uint256[] memory crossAmounts = new uint256[](crossSize);
    address[] memory crossRefundAddrs = new address[](crossSize);
    uint256 crossTotal;
    // direct transfer
    address payable[] memory directAddrs = new address payable[](directSize);
    uint256[] memory directAmounts = new uint256[](directSize);
    delete crossSize;
    delete directSize;
    for(uint i = 0;i<n;i++){
      if(currentValidatorSet[i].incoming >= DUSTY_INCOMING){
        crossAddrs[crossSize] = currentValidatorSet[i].BBCFeeAddress;
        uint256 value = currentValidatorSet[i].incoming - currentValidatorSet[i].incoming % PRECISION;
        crossAmounts[crossSize] = value-EXTRA_FEE;
        crossRefundAddrs[crossSize] = currentValidatorSet[i].BBCFeeAddress;
        crossTotal += value;
        crossSize ++;
      }else if (currentValidatorSet[i].incoming > 0){
        directAddrs[directSize] = currentValidatorSet[i].feeAddress;
        directAmounts[directSize] = currentValidatorSet[i].incoming;
        directSize ++;
      }
    }
    return (crossAddrs, crossAmounts, crossRefundAddrs, directAddrs, directAmounts, crossTotal);
  }

  function doUpdateState(Validator[] memory validatorSet) private{
    sequence ++;
    totalInComing = 0;
    uint n = currentValidatorSet.length;
    uint m = validatorSet.length;
    uint k = n < m ? n:m;
    if (n>m){
      for(uint i = m;i<n;i++){
        delete currentValidatorSetMap[currentValidatorSet[i].consensusAddress];
      }
      currentValidatorSet.length -= n-m;
    }
    for(uint i = 0;i<k;i++){
      if (!isSameValidator(validatorSet[i], currentValidatorSet[i])){
        delete currentValidatorSetMap[currentValidatorSet[i].consensusAddress];
        currentValidatorSetMap[validatorSet[i].consensusAddress] = i+1;
        currentValidatorSet[i] = validatorSet[i];
      }else{
        currentValidatorSet[i].incoming = 0;
      }
    }
    if (m>n){
      for(uint i = n;i<m;i++){
        currentValidatorSet.push(validatorSet[i]);
        currentValidatorSetMap[validatorSet[i].consensusAddress] = i+1;
      }
    }
  }


  function generateKey(uint256 packageSequence) internal view returns (bytes memory){
    // A copy of keyPrefix
    bytes memory sequenceBytes = new bytes(32);
    TypesToBytes.uintToBytes(32, packageSequence, sequenceBytes);
    return BytesLib.concat(keyPrefix, sequenceBytes);
  }



  function generatePrefixKey(string memory _fromChainId, string memory _toChainId) private pure returns(bytes memory prefix){
    prefix = new bytes(65);
    uint256 pos=prefix.length;

    assembly {
      mstore(add(prefix, pos), CHANNEL_ID)
    }
    pos -=1;
    bytes memory toChainIDBytes = bytes(_toChainId);
    assembly {
      mstore(add(prefix, pos), mload(add(toChainIDBytes, 32)))
    }
    pos -=32;
    bytes memory fromChainIDBytes = bytes(_fromChainId);
    assembly {
      mstore(add(prefix, pos), mload(add(fromChainIDBytes, 32)))
    }
    return prefix;
  }


  function isSameValidator(Validator memory v1, Validator memory v2) private pure returns(bool){
    return v1.consensusAddress == v2.consensusAddress && v1.feeAddress == v2.feeAddress && v1.BBCFeeAddress == v2.BBCFeeAddress;
  }
}