pragma solidity 0.6.4;

import "./System.sol";
import "./Seriality/TypesToBytes.sol";
import "./Seriality/BytesToTypes.sol";
import "./Seriality/BytesLib.sol";
import "./Seriality/Memory.sol";
import "./interface/ILightClient.sol";
import "./interface/ISlashIndicator.sol";
import "./interface/ITokenHub.sol";
import "./interface/IRelayerHub.sol";
import "./interface/IParamSubscriber.sol";
import "./interface/IBSCValidatorSet.sol";
import "./MerkleProof.sol";



contract BSCValidatorSet is IBSCValidatorSet, System, IParamSubscriber {
  // {20 bytes consensusAddress} + {20 bytes feeAddress} + {20 bytes BBCFeeAddress} + {8 bytes voting power}
  uint constant  VALIDATOR_BYTES_LENGTH = 68;
  // will not transfer value less than 0.1 BNB for validators
  uint256 constant public DUSTY_INCOMING = 1e17;
  // extra fee for cross chain transfer,should keep consistent with cross chain transfer smart contract.
  uint256 constant public EXTRA_FEE = 1e16;

  uint8 public constant JAIL_MESSAGE_TYPE = 1;
  uint8 public constant VALIDATORS_UPDATE_MESSAGE_TYPE = 0;
  uint8 public constant CHANNEL_ID = 0x08;

  // the precision of cross chain value transfer.
  uint256 constant PRECISION = 1e10;
  uint256 constant EXPIRE_TIME_SECOND_GAP = 1000;

  bytes public constant INIT_VALIDATORSET_BYTES = hex"009fb29aac15b9a4b7f17c3385939b007540f4d7919fb29aac15b9a4b7f17c3385939b007540f4d7919fb29aac15b9a4b7f17c3385939b007540f4d7910000000000000064";

  bool public alreadyInit;

  // state of this contract
  Validator[] public currentValidatorSet;
  uint64 public sequence;
  uint64 public felonySequence;
  uint256 public totalInComing;
  uint256 public relayerReward;
  uint256 public extraFee;
  uint256 public expireTimeSecondGap;
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

  modifier onlyNotInit() {
    require(!alreadyInit, "the contract already init");
    _;
  }

  modifier onlyInit() {
    require(alreadyInit, "the contract not init yet");
    _;
  }

  modifier sequenceInOrder(uint64 _sequence) {
    require(_sequence == sequence, "sequence not in order");
    _;
    sequence ++;
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
  event validatorEmptyJailed(address indexed validator);
  event batchTransfer(uint256 amount);
  event batchTransferFailed(uint256 indexed amount, string reason);
  event batchTransferLowerFailed(uint256 indexed amount, bytes reason);
  event systemTransfer(uint256 amount);
  event directTransfer(address payable indexed validator, uint256 amount);
  event directTransferFail(address payable indexed validator, uint256 amount);
  event deprecatedDeposit(address indexed validator, uint256 amount);
  event validatorDeposit(address indexed validator, uint256 amount);
  event validatorMisdemeanor(address indexed validator, uint256 amount);
  event validatorFelony(uint64 indexed sequence, address indexed validator, uint256 amount);
  event failReasonWithStr(string message);
  event paramChange(string key, bytes value);

  function init() external onlyNotInit{
    (Validator[] memory validatorSet, bool valid, string memory errMsg)= parseValidatorSet(INIT_VALIDATORSET_BYTES);
    require(valid, errMsg);
    for(uint i = 0;i<validatorSet.length;i++){
      currentValidatorSet.push(validatorSet[i]);
      currentValidatorSetMap[validatorSet[i].consensusAddress] = i+1;
    }
    relayerReward = RELAYER_REWARD;
    extraFee = EXTRA_FEE;
    expireTimeSecondGap = EXPIRE_TIME_SECOND_GAP;
    alreadyInit = true;
  }

  /*********************** External Functions **************************/

  function deposit(address valAddr) external payable onlyCoinbase onlyInit noEmptyDeposit onlyDepositOnce{
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

  function handlePackage(bytes calldata msgBytes, bytes calldata proof, uint64 height, uint64 packageSequence) external onlyInit onlyRelayer sequenceInOrder(packageSequence) blockSynced(height) doClaimReward(relayerReward){
    // verify key value against light client;
    bytes memory key = generateKey(packageSequence, CHANNEL_ID);
    bytes32 appHash = ILightClient(LIGHT_CLIENT_ADDR).getAppHash(height);
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
    (Validator[] memory validatorSet, bool valid, string memory errMsg) = parseValidatorSet(validatorBytes);
    if(!valid){
      emit failReasonWithStr(errMsg);
      return;
    }
    if(validatorSet.length != 1){
      emit failReasonWithStr("length of jail validators must be one");
      return;
    }
    Validator memory v = validatorSet[0];
    uint256 index = currentValidatorSetMap[v.consensusAddress];
    if (index<=0){
      emit validatorEmptyJailed(v.consensusAddress);
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
      emit validatorEmptyJailed(v.consensusAddress);
      return;
    }
    currentValidatorSet[index-1].jailed = true;
    emit validatorJailed(v.consensusAddress);
    return;
  }

  function updateValidatorSet(bytes memory validatorSetBytes) internal{
    // do deserialize and verify.
    (Validator[] memory validatorSet, bool valid, string memory errMsg)= parseValidatorSet(validatorSetBytes);
    if(!valid){
      emit failReasonWithStr(errMsg);
      return;
    }
    // do calculate distribution
    (address[] memory crossAddrs, uint256[] memory crossAmounts, address[] memory crossRefundAddrs,
      address payable[] memory directAddrs, uint256[] memory directAmounts, uint256 crossTotal) = calDistribute();

    // do cross chain transfer
    if(crossTotal > 0){
      uint256 relayFee = crossAddrs.length*extraFee;
      try ITokenHub(TOKEN_HUB_ADDR).batchTransferOut{value:crossTotal}(crossAddrs, crossAmounts, crossRefundAddrs, address(0x0), block.timestamp + expireTimeSecondGap, relayFee) returns (bool success) {
        if (success) {
           emit batchTransfer(crossTotal);
        }else{
           emit batchTransferFailed(crossTotal, "batch transfer return false");
        }
      }catch Error(string memory reason) {
        emit batchTransferFailed(crossTotal, reason);
      } catch (bytes memory lowLevelData) {
        emit batchTransferLowerFailed(crossTotal, lowLevelData);
      }
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
      address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
      systemPayable.transfer(address(this).balance);
    }

    // do update state
    if(validatorSet.length>0){
      doUpdateState(validatorSet);
    }

    // do claim reward, will reward to account rather than smart contract.
    ISlashIndicator(SLASH_CONTRACT_ADDR).clean();
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

  function misdemeanor(address validator)external onlySlash override{
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

  function felony(address validator)external onlySlash override{
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
    emit validatorFelony(felonySequence,validator,income);
    felonySequence ++;
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
  /*********************** Param update ********************************/
  function updateParam(string calldata key, bytes calldata value) override external onlyInit onlyGov{
    if (Memory.compareStrings(key,"relayerReward")){
      require(value.length == 32, "length of relayerReward mismatch");
      uint256 newRelayerReward = BytesToTypes.bytesToUint256(32, value);
      require(newRelayerReward >0 && newRelayerReward <= 1e18, "the relayerReward out of range");
      relayerReward = newRelayerReward;
    }else if(Memory.compareStrings(key,"extraFee")){
      require(value.length == 32, "length of extraFee mismatch");
      uint256 newExtraFee = BytesToTypes.bytesToUint256(32, value);
      require(newExtraFee >=0 && newExtraFee <= 1e17, "the extraFee out of range");
      extraFee = newExtraFee;
    }else if (Memory.compareStrings(key, "expireTimeSecondGap")){
      require(value.length == 32, "length of expireTimeSecondGap mismatch");
      uint256 newExpireTimeSecondGap = BytesToTypes.bytesToUint256(32, value);
      require(newExpireTimeSecondGap >=100 && newExpireTimeSecondGap <= 1e5, "the extraFee out of range");
      expireTimeSecondGap = newExpireTimeSecondGap;
    }else{
      require(false, "unknown param");
    }
    emit paramChange(key, value);
  }

  /*********************** Internal Functions **************************/

  function parseValidatorSet(bytes memory validatorSetBytes) private pure returns(Validator[] memory, bool, string memory){
    uint length = validatorSetBytes.length-1;
    if(length % VALIDATOR_BYTES_LENGTH != 0){
      return (new Validator[](0), false, "the length of validatorSetBytes should be times of 68");
    }
    uint n = length/VALIDATOR_BYTES_LENGTH;
    Validator[] memory validatorSet = new Validator[](n);
    for(uint i = 0;i<n;i++){
      validatorSet[i].consensusAddress = BytesToTypes.bytesToAddress(1+i*VALIDATOR_BYTES_LENGTH+20,validatorSetBytes);
      validatorSet[i].feeAddress = address(uint160(BytesToTypes.bytesToAddress(1+i*VALIDATOR_BYTES_LENGTH+40,validatorSetBytes)));
      validatorSet[i].BBCFeeAddress = BytesToTypes.bytesToAddress(1+i*VALIDATOR_BYTES_LENGTH+60,validatorSetBytes);
      validatorSet[i].votingPower = BytesToTypes.bytesToUint64(1+i*VALIDATOR_BYTES_LENGTH+68,validatorSetBytes);
    }
    for(uint i = 0;i<n;i++){
      for(uint j = 0;j<i;j++){
        if(validatorSet[i].consensusAddress == validatorSet[j].consensusAddress ){
          return (new Validator[](0), false, "duplicate consensus address of validatorSet");
        }
      }
    }
    return (validatorSet,true,"");
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
        crossAmounts[crossSize] = value-extraFee;
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

    for(uint i = 0;i<n;i++){
      bool stale = true;
      Validator memory oldValidator = currentValidatorSet[i];
      for(uint j = 0;j<m;j++){
        if(oldValidator.consensusAddress == validatorSet[j].consensusAddress){
          stale = false;
          break;
        }
      }
      if (stale){
        delete currentValidatorSetMap[oldValidator.consensusAddress];
      }
    }

    if (n>m){
      for(uint i = m;i<n;i++){
        currentValidatorSet.pop();
      }
    }
    uint k = n < m ? n:m;
    for(uint i = 0;i<k;i++){
      if (!isSameValidator(validatorSet[i], currentValidatorSet[i])){
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

  function isSameValidator(Validator memory v1, Validator memory v2) private pure returns(bool){
    return v1.consensusAddress == v2.consensusAddress && v1.feeAddress == v2.feeAddress && v1.BBCFeeAddress == v2.BBCFeeAddress && v1.votingPower == v2.votingPower;
  }
}
