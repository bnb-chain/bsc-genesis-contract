pragma solidity 0.6.4;

import "./System.sol";
import "./Seriality/TypesToBytes.sol";
import "./Seriality/BytesToTypes.sol";
import "./Seriality/BytesLib.sol";
import "./interface/ILightClient.sol";
import "./interface/ISystemReward.sol";
import "./interface/ISlashIndicator.sol";
import "./interface/ITokenHub.sol";
import "./interface/IRelayerHub.sol";
import "./MerkleProof.sol";


contract BSCValidatorSet is System {
  // keep consistent with the channel id in BBC;
  uint8 public constant CHANNEL_ID =  8;
  // {20 bytes consensusAddress} + {20 bytes feeAddress} + {20 bytes BBCFeeAddress} + {8 bytes voting power}
  uint constant  VALIDATOR_BYTES_LENGTH = 68;
  // will not transfer value less than 0.1 BNB for validators
  uint256 constant public DUSTY_INCOMING = 1e17;
  // extra fee for cross chain transfer,should keep consistent with cross chain transfer smart contract.
  uint256 constant public EXTRA_FEE = 1e16;
  // will reward relayer at most 0.05 BNB.
  uint256 constant public RELAYER_REWARD = 5e16;

  uint8 public constant JAIL_MESSAGE_TYPE = 1;
  uint8 public constant VALIDATORS_UPDATE_MESSAGE_TYPE = 0;

  // the precision of cross chain value transfer.
  uint256 constant PRECISION = 1e10;
  uint256 constant EXPIRE_TIME_SECOND_GAP = 1000;
  // the store name of the package
  string constant STORE_NAME = "ibc";

  address payable public constant INIT_SYSTEM_REWARD_ADDR = 0x0000000000000000000000000000000000001002;
  address public constant  INIT_TOKEN_HUB_ADDR = 0x0000000000000000000000000000000000001004;
  address public constant INIT_LIGHT_CLIENT_ADDR = 0x0000000000000000000000000000000000001003;
  address public constant INIT_SLASH_CONTRACT_ADDR = 0x0000000000000000000000000000000000001001;
  address public constant INIT_RELAYERHUB_CONTRACT_ADDR = 0x0000000000000000000000000000000000001006;
  bytes public constant INIT_VALIDATORSET_BYTES = hex"009fb29aac15b9a4b7f17c3385939b007540f4d7919fb29aac15b9a4b7f17c3385939b007540f4d7919fb29aac15b9a4b7f17c3385939b007540f4d7910000000000000064";
  bytes32 constant crossChainKeyPrefix = 0x0000000000000000000000000000000000000000000000000000000001000208; // last 5 bytes

  bool public alreadyInit;

  // other contract
  ILightClient lightClient;
  ITokenHub tokenHub;
  ISystemReward systemReward;
  ISlashIndicator slash;
  IRelayerHub relayerHub;


  // state of this contract
  Validator[] public currentValidatorSet;
  uint64 public sequence;
  uint64 public felonySequence;
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
    bool jailed;
    uint256 incoming;
  }

  modifier onlyRelayer() {
    require(relayerHub.isRelayer(msg.sender), "the msg sender is not a relayer");
    _;
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
    require(_sequence == sequence, "sequence not in order");
    _;
    sequence ++;
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
  event validatorJailed(address indexed validator);
  event batchTransfer(uint256 indexed amount);
  event systemTransfer(uint256 indexed amount);
  event directTransfer(address payable indexed validator, uint256 indexed amount);
  event directTransferFail(address payable indexed validator, uint256 indexed amount);
  event deprecatedDeposit(address indexed validator, uint256 indexed amount);
  event validatorDeposit(address indexed validator, uint256 indexed amount);
  event validatorMisdemeanor(address indexed validator, uint256 indexed amount);
  event validatorFelony(uint64 indexed sequence, address indexed validator, uint256 indexed amount);

  function init() external onlyNotInit{
    Validator[] memory validatorSet = parseValidatorSet(INIT_VALIDATORSET_BYTES);
    (bool passVerify, string memory errorMsg) = verifyValidatorSet(validatorSet);
    require(passVerify,errorMsg);
    for(uint i = 0;i<validatorSet.length;i++){
      currentValidatorSet.push(validatorSet[i]);
      currentValidatorSetMap[validatorSet[i].consensusAddress] = i+1;
    }
    lightClient = ILightClient(INIT_LIGHT_CLIENT_ADDR);
    tokenHub = ITokenHub(INIT_TOKEN_HUB_ADDR);
    systemReward = ISystemReward(INIT_SYSTEM_REWARD_ADDR);
    slash = ISlashIndicator(INIT_SLASH_CONTRACT_ADDR);
    relayerHub = IRelayerHub(INIT_RELAYERHUB_CONTRACT_ADDR);
    alreadyInit = true;
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

  function update(bytes calldata msgBytes, bytes calldata proof, uint64 height, uint64 packageSequence) external onlyInit onlyRelayer sequenceInOrder(packageSequence) blockSynced(height){
    // verify key value against light client;
    bytes memory key = generateKey(packageSequence);
    bytes32 appHash = lightClient.getAppHash(height);
    bool valid = MerkleProof.validateMerkleProof(appHash, STORE_NAME, key, msgBytes, proof);
    require(valid, "the package is invalid against its proof");
    uint8 msgType = getMsgType(msgBytes);
    if(msgType == VALIDATORS_UPDATE_MESSAGE_TYPE){
      updateValidatorSet(msgBytes);
    }else if(msgType == JAIL_MESSAGE_TYPE){
      jailValidator(msgBytes);
    }else{
       require(false, "unknown message type");
    }
  }

  function jailValidator(bytes memory validatorBytes) internal{
    // do deserialize and verify.
    Validator[] memory validatorSet = parseValidatorSet(validatorBytes);
    require(validatorSet.length == 1, "length of jail validators must be one");
    Validator memory v = validatorSet[0];
    uint256 index = currentValidatorSetMap[v.consensusAddress];
    if (index<=0){
      return;
    }
    bool otherValid = false;
    for(uint i=0;i<currentValidatorSet.length;i++){
      if(!currentValidatorSet[i].jailed && currentValidatorSet[i].consensusAddress != v.consensusAddress){
        otherValid = true;
        break;
      }
    }
    // will not jail if it is the last valid validator
    if(!otherValid){
      return;
    }
    currentValidatorSet[index-1].jailed = true;
    systemReward.claimRewards(msg.sender, RELAYER_REWARD);
    emit validatorJailed(v.consensusAddress);
    return;
  }

  function updateValidatorSet(bytes memory validatorSetBytes) internal{
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

    if(directAddrs.length>0){
      for(uint i = 0;i<directAddrs.length;i++){
        bool success = directAddrs[i].send(directAmounts[i]);
        if (success){
          emit directTransfer(directAddrs[i], directAmounts[i]);
        }else{
          emit directTransferFail(directAddrs[i], directAmounts[i]);
        }
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
    uint valid = 0;
    for(uint i = 0;i<n;i++){
      if(!currentValidatorSet[i].jailed){
        valid ++;
      }
    }
    address[] memory consensusAddrs = new address[](valid);
    delete valid;
    for(uint i = 0;i<n;i++){
      if(!currentValidatorSet[i].jailed){
        consensusAddrs[valid] = currentValidatorSet[i].consensusAddress;
        valid ++;
      }
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

  function misdemeanor(address validator)external onlySlash{
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

  function felony(address validator)external onlySlash{
    uint256 index = currentValidatorSetMap[validator];
    if(index <= 0){
      return;
    }
    // the actually index
    index = index - 1;
    uint256 income = currentValidatorSet[index].incoming;
    uint256 rest = currentValidatorSet.length - 1;
    if(rest==0){
      // will not remove the validator if it is the only one validator.
      currentValidatorSet[index].incoming = 0;
      return;
    }
    felonySequence ++;
    emit validatorFelony(felonySequence,validator,income);
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
    uint length = validatorSetBytes.length-1;
    require(length > 0, "the validatorSetBytes should not be empty");
    require(length % VALIDATOR_BYTES_LENGTH == 0, "the length of validatorSetBytes should be times of 68");
    uint n = length/VALIDATOR_BYTES_LENGTH;
    Validator[] memory validatorSet = new Validator[](n);
    for(uint i = 0;i<n;i++){
      validatorSet[i].consensusAddress = BytesToTypes.bytesToAddress(1+i*VALIDATOR_BYTES_LENGTH+20,validatorSetBytes);
      validatorSet[i].feeAddress = address(uint160(BytesToTypes.bytesToAddress(1+i*VALIDATOR_BYTES_LENGTH+40,validatorSetBytes)));
      validatorSet[i].BBCFeeAddress = BytesToTypes.bytesToAddress(1+i*VALIDATOR_BYTES_LENGTH+60,validatorSetBytes);
      validatorSet[i].votingPower = BytesToTypes.bytesToUint64(1+i*VALIDATOR_BYTES_LENGTH+68,validatorSetBytes);
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


// | length   | prefix | sourceChainID| destinationChainID | channelID | sequence |
// | 32 bytes | 1 byte | 2 bytes    | 2 bytes      |  1 bytes  | 8 bytes  |
  function generateKey(uint256 _sequence) internal pure returns(bytes memory) {
    bytes memory key = new bytes(14);

    uint256 ptr;
    assembly {
      ptr := add(key, 14)
    }
    assembly {
      mstore(ptr, _sequence)
    }
    ptr -= 8;
    assembly {
      mstore(ptr, crossChainKeyPrefix)
    }
    ptr -= 6;
    assembly {
      mstore(ptr, 14)
    }
    return key;
  }

  function getMsgType(bytes memory msgBytes) internal pure returns(uint8){
    uint8 msgType = 0xff;
    assembly {
      msgType := mload(add(msgBytes, 1))
    }
    return msgType;
  }

  function isSameValidator(Validator memory v1, Validator memory v2) private pure returns(bool){
    return v1.consensusAddress == v2.consensusAddress && v1.feeAddress == v2.feeAddress && v1.BBCFeeAddress == v2.BBCFeeAddress && v1.votingPower == v2.votingPower;
  }
}