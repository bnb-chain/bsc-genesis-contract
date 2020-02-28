const web3 = require("web3")

// Configure
const validators = [
  {
    consensusAddr: "0xC90AddaAD734106f885807C2D90d34687124f565",
    feeAddr: "0xC90AddaAD734106f885807C2D90d34687124f565",
    bscFeeAddr: "0xC90AddaAD734106f885807C2D90d34687124f565"
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
  for(let i = 0;i<n;i++){
    let validator = validators[i];
    arr.push(Buffer.from(web3.utils.hexToBytes(validator.consensusAddr)));
    arr.push(Buffer.from(web3.utils.hexToBytes(validator.feeAddr)));
    arr.push(Buffer.from(web3.utils.hexToBytes(validator.bscFeeAddr)));
  }
  return web3.utils.bytesToHex(Buffer.concat(arr));
}

extraValidatorBytes = generateExtradata(validators);
validatorSetBytes = validatorsSerialize(validators);

exports = module.exports = {
  extraValidatorBytes: extraValidatorBytes,
  validatorSetBytes: validatorSetBytes,
}
