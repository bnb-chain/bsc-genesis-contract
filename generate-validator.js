const fs = require("fs");
const readline = require('readline');
const nunjucks = require("nunjucks");


async function processValidatorConf() {
  const fileStream = fs.createReadStream(__dirname + '/validators.conf');

  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });
  let validators = [];
  for await (const line of rl) {
    // Each line in input.txt will be successively available here as `line`.
    let vs = line.split(",")
    validators.push({
      consensusAddr: vs[0],
      feeAddr: vs[1],
      bscFeeAddr: vs[2],
      votingPower: vs[3],
    })
  }
  return validators
}

processValidatorConf().then(function (validators) {
  const data = {
    validators: validators
  };
  const templateString = fs.readFileSync(__dirname + '/validators.template').toString();
  const resultString = nunjucks.renderString(templateString, data);
  fs.writeFileSync(__dirname + '/validators.js', resultString);
  console.log("BSCValidatorSet file updated.");
})
