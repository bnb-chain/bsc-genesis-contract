const web3 = require("web3")

// Configure
const validators = [
  {
    consensusAddr: "0x9fB29AAc15b9A4B7F17c3385939b007540f4d791",
    feeAddr: "0x9fB29AAc15b9A4B7F17c3385939b007540f4d791",
    bscFeeAddr: "0x9fB29AAc15b9A4B7F17c3385939b007540f4d791",
    votingPower: "0x0000000000000064"
  }
];

// ===============  Do not edit below ====
function generateExtradata(validators) {
  let extraVanity =Buffer.alloc(32);
  let validatorsBytes = extraDataSerialize(validators);
  let extraSeal =Buffer.alloc(65);
  return Buffer.concat([extraVanity,validatorsBytes,extraSeal]);
}

function extraDataSerialize(validators) {
  let n = validators.length;
  let arr = [];
  for(let i = 0;i<n;i++){
    let validator = validators[i];
    arr.push(Buffer.from(web3.utils.hexToBytes(validator.consensusAddr)));
  }
  return Buffer.concat(arr);
}

function validatorsSerialize(validators) {
  let n = validators.length;
  let arr = [];
  arr.push(Buffer.from(web3.utils.hexToBytes("0x00")))
  for(let i = 0;i<n;i++){
    let validator = validators[i];
    arr.push(Buffer.from(web3.utils.hexToBytes(validator.consensusAddr)));
    arr.push(Buffer.from(web3.utils.hexToBytes(validator.feeAddr)));
    arr.push(Buffer.from(web3.utils.hexToBytes(validator.bscFeeAddr)));
    arr.push(Buffer.from(web3.utils.hexToBytes(validator.votingPower)));
  }
  return web3.utils.bytesToHex(Buffer.concat(arr));
}

extraValidatorBytes = generateExtradata(validators);
validatorSetBytes = validatorsSerialize(validators);

exports = module.exports = {
  extraValidatorBytes: extraValidatorBytes,
  validatorSetBytes: validatorSetBytes,
}
