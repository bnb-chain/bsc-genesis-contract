pragma solidity 0.6.4;

import "./System.sol";
import "./Seriality/TypesToBytes.sol";
import "./Seriality/BytesToTypes.sol";
import "./Seriality/BytesLib.sol";
import "./interface/ILightClient.sol";
import "./interface/ISystemReward.sol";
import "./interface/ISlashIndicator.sol";
import "./interface/ITokenHub.sol";
import "./MerkleProof.sol";


contract BSCValidatorSet is System {
  // keep consistent with the channel id in BBC;
  uint8 public constant CHANNEL_ID =  8;
  // {20 bytes consensusAddress} + {20 bytes feeAddress} + {20 bytes BBCFeeAddress} + {8 bytes voting power}
  uint constant  VALIDATOR_BYTES_LENGTH = 68;
  // will not transfer value less than 0.1 BNB for validators
  uint256 constant public DUSTY_INCOMING = 1e17;
  // extra fee for cross chain transfer,should keep consistent with cross chain transfer smart contract.
  uint256 constant public EXTRA_FEE = 1e12;
  // will reward relayer at most 0.01 BNB.
  uint256 constant public RELAYER_REWARD = 1e16;

  // the precision of cross chain value transfer.
  uint256 constant PRECISION = 1e8;
  uint256 constant EXPIRE_TIME_SECOND_GAP = 1000;
  // the store name of the package
  string constant STORE_NAME = "ibc";

  uint16 public constant fromChainId = 0x0001;
  uint16 public constant toChainId = 0x0002;
  address payable public constant initSystemRewardAddr = 0x0000000000000000000000000000000000001002;
  address public constant  initTokenHubAddr = 0x0000000000000000000000000000000000001004;
  address public constant initLightClientAddr = 0x0000000000000000000000000000000000001003;
  address public constant initSlashContract = 0x0000000000000000000000000000000000001001;
  bytes public constant initValidatorSetBytes = hex"9fb29aac15b9a4b7f17c3385939b007540f4d7919fb29aac15b9a4b7f17c3385939b007540f4d7919fb29aac15b9a4b7f17c3385939b007540f4d7910000000000000064";

  bool public alreadyInit;
  // used for generate key
  bytes public keyPrefix;

  // other contract
  ILightClient lightClient;
  ITokenHub tokenHub;
  ISystemReward systemReward;
  ISlashIndicator slash;


  // state of this contract
  Validator[] public currentValidatorSet;
  uint64 public sequence;
  uint256 public totalInComing;
  uint64 public previousDepositHeight;
  // key is the `consensusAddress` of `Validator`,
  // value is the index of the element in `currentValidatorSet`.
  mapping(address =>uint256) currentValidatorSetMap;

  struct Validator{
    address consensusAddress;
    address payable feeAddress;
    address BBCFeeAddress;
    uint64  votingPower;
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

  modifier onlySlash() {
    require(msg.sender == address(slash) , "the message sender must be slash contract");
    _;
  }

  modifier sequenceInOrder(uint64 _sequence) {
    require(_sequence == sequence+1, "sequence not in order");
    _;
  }

  modifier blockSynced(uint64 _height) {
    require(lightClient.isHeaderSynced(_height), "light client not sync the block yet");
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
    previousDepositHeight = uint64(block.number);
  }

  event validatorSetUpdated();
  event batchTransfer(uint256 indexed amount);
  event systemTransfer(uint256 indexed amount);
  event directTransfer(address payable indexed validator, uint256 indexed amount);
  event deprecatedDeposit(address indexed validator, uint256 indexed amount);
  event validatorDeposit(address indexed validator, uint256 indexed amount);
  event validatorMisdemeanor(address indexed validator, uint256 indexed amount);
  event validatorFelony(address indexed validator, uint256 indexed amount);
  event contractAddrUpdate(address systemRewardAddr, address tokenHubAddr, address lightClientAddr, address slashAddr);


  function init() external onlyNotInit{
    Validator[] memory validatorSet = parseValidatorSet(initValidatorSetBytes);
    (bool passVerify, string memory errorMsg) = verifyValidatorSet(validatorSet);
    require(passVerify,errorMsg);
    for(uint i = 0;i<validatorSet.length;i++){
      currentValidatorSet.push(validatorSet[i]);
      currentValidatorSetMap[validatorSet[i].consensusAddress] = i+1;
    }
    lightClient = ILightClient(initLightClientAddr);
    tokenHub = ITokenHub(initTokenHubAddr);
    systemReward = ISystemReward(initSystemRewardAddr);
    slash = ISlashIndicator(initSlashContract);
    keyPrefix = generatePrefixKey();
    alreadyInit = true;
  }

  function updateContractAddr(address _systemRewardAddr, address _tokenHub, address _lightClientAddr, address _slashContract) external onlyInit onlySystem{
    lightClient = ILightClient(_lightClientAddr);
    tokenHub = ITokenHub(_tokenHub);
    systemReward = ISystemReward(_systemRewardAddr);
    slash = ISlashIndicator(_slashContract);
    emit contractAddrUpdate(_systemRewardAddr,_tokenHub,_lightClientAddr,_slashContract);
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

  function updateValidatorSet(bytes calldata validatorSetBytes, bytes calldata proof, uint64 height, uint64 packageSequence) external onlyInit sequenceInOrder(packageSequence) blockSynced(height){
    // verify key value against light client;
    bytes memory key = generateKey(packageSequence);
    bytes32 appHash = lightClient.getAppHash(height);
    bool valid = MerkleProof.validateMerkleProof(appHash, STORE_NAME, key, validatorSetBytes, proof);

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
      uint256 relayFee = crossAddrs.length*EXTRA_FEE;
      tokenHub.batchTransferOut{value:crossTotal}(crossAddrs, crossAmounts, crossRefundAddrs, address(0x0), block.timestamp + EXPIRE_TIME_SECOND_GAP, relayFee);
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
    slash.clean();
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

  function getIncoming(address validator)external view returns(uint256) {
    uint256 index = currentValidatorSetMap[validator];
    if (index<=0){
      return 0;
    }
    return currentValidatorSet[index-1].incoming;
  }

  /*********************** For slash **************************/

  function misdemeanor(address validator)external onlySlash onlyInit{
    uint256 index = currentValidatorSetMap[validator];
    if(index <= 0){
      return;
    }
    // the actually index
    index = index - 1;
    uint256 income = currentValidatorSet[index].incoming;
    currentValidatorSet[index].incoming = 0;
    uint256 rest = currentValidatorSet.length - 1;
    emit validatorMisdemeanor(validator,income);
    if(rest==0){
      // should not happen, but still protect
      return;
    }
    uint256 averageDistribute = income/rest;
    if(averageDistribute!=0){
      for(uint i=0;i<index;i++){
        currentValidatorSet[i].incoming = currentValidatorSet[i].incoming + averageDistribute;
      }
      for(uint i=index+1;i<currentValidatorSet.length;i++){
        currentValidatorSet[i].incoming = currentValidatorSet[i].incoming + averageDistribute;
      }
    }
    // averageDistribute*rest may less than income, but it is ok, the dust income will go to system reward eventually.
  }

  function felony(address validator)external onlySlash onlyInit{
    uint256 index = currentValidatorSetMap[validator];
    if(index <= 0){
      return;
    }
    // the actually index
    index = index - 1;
    uint256 income = currentValidatorSet[index].incoming;
    uint256 rest = currentValidatorSet.length - 1;
    emit validatorFelony(validator,income);
    if(rest==0){
      // will not remove the validator if it is the only one validator.
      currentValidatorSet[index].incoming = 0;
      return;
    }
    delete currentValidatorSetMap[validator];
    // It is ok that the validatorSet is not in order.
    if (index != currentValidatorSet.length-1){
      currentValidatorSet[index] = currentValidatorSet[currentValidatorSet.length-1];
      currentValidatorSetMap[currentValidatorSet[index].consensusAddress] = index + 1;
    }
    currentValidatorSet.pop();
    uint256 averageDistribute = income/rest;
    if(averageDistribute!=0){
      for(uint i=0;i<currentValidatorSet.length;i++){
        currentValidatorSet[i].incoming = currentValidatorSet[i].incoming + averageDistribute;
      }
    }
    // averageDistribute*rest may less than income, but it is ok, the dust income will go to system reward eventually.
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
      validatorSet[i].votingPower = BytesToTypes.bytesToUint64(i*VALIDATOR_BYTES_LENGTH+68,validatorSetBytes);
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
      for(uint i = m;i<n;i++){
        currentValidatorSet.pop();
      }
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


  function generateKey(uint64 packageSequence) internal view returns (bytes memory){
    // A copy of keyPrefix
    bytes memory sequenceBytes = new bytes(8);
    TypesToBytes.uintToBytes(32, packageSequence, sequenceBytes);
    return BytesLib.concat(keyPrefix, sequenceBytes);
  }



  function generatePrefixKey() private pure returns(bytes memory prefix){

    prefix = new bytes(5);
    uint256 pos=prefix.length;

    assembly {
      mstore(add(prefix, pos), CHANNEL_ID)
    }
    pos -=1;
    assembly {
      mstore(add(prefix, pos), toChainId)
    }
    pos -=2;

    assembly {
      mstore(add(prefix, pos), fromChainId)
    }
    pos -=2;
    assembly {
      mstore(add(prefix, pos), 0x5)
    }
    return prefix;
  }


  function isSameValidator(Validator memory v1, Validator memory v2) private pure returns(bool){
    return v1.consensusAddress == v2.consensusAddress && v1.feeAddress == v2.feeAddress && v1.BBCFeeAddress == v2.BBCFeeAddress && v1.votingPower == v2.votingPower;
  }
}