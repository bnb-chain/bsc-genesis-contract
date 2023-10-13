const fs = require('fs');
const readline = require('readline');
const nunjucks = require('nunjucks');
const BLSKeys = require('./BLSkeystore.json');

async function processValidatorConf() {
  const fileStream = fs.createReadStream(__dirname + '/../validators.conf');
  const publicKey = BLSKeys.public_key;

  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity,
  });
  let validators = [];
  for await (const line of rl) {
    // Each line in input.txt will be successively available here as `line`.
    let vs = line.split(',');
    validators.push({
      consensusAddr: vs[0],
      feeAddr: vs[1],
      bscFeeAddr: vs[2],
      votingPower: vs[3],
      bLSPublicKey: '0x' + publicKey.pop(),
    });
  }
  return validators;
}

processValidatorConf().then(function (validators, bLSPublicKeys) {
  const data = {
    validators: validators,
    bLSPublicKeys: bLSPublicKeys,
  };
  const templateString = fs.readFileSync(__dirname + '/validators.template').toString();
  const resultString = nunjucks.renderString(templateString, data);
  fs.writeFileSync(__dirname + '/validators.js', resultString);
  console.log('validators.js file updated.');
});
