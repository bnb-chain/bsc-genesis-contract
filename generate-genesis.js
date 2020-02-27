const { spawn } = require("child_process")
const program = require("commander")
const nunjucks = require("nunjucks")
const fs = require("fs")
const web3 = require("web3")

const validators = require("./validators")
const init_holders = require("./init_holders")

// load and execute generate-system.js
require("./generate-system")

program.version("0.0.1")
program.option("-c, --chain-id <chain-id>", "chain id", "714")
program.option(
  "-o, --output <output-file>",
  "Genesis json file",
  "./genesis.json"
)
program.option(
  "-t, --template <template>",
  "Genesis template json",
  "./genesis-template.json"
)
program.parse(process.argv)

let validatorBytes = validatorsSerialize(validators)
// compile contract
function compileContract(key, contractFile, contractName) {
  return new Promise((resolve, reject) => {
    const ls = spawn("docker", [
      "run",
      "-v",
      "./:/sources",
      "ethereum/solc:0.5.15",
      "--bin-runtime",
      "solidity-bytes-utils/=node_modules/solidity-bytes-utils/",
      "/=/",
      // "--optimize",
      // "--optimize-runs",
      // "200",
      contractFile
    ])

    const result = []
    ls.stdout.on("data", data => {
      result.push(data.toString())
    })

    ls.stderr.on("data", data => {
      // console.log(`stderr: ${data}`)
    })

    ls.on("close", code => {
      console.log(`child process exited with code ${code}`)
      resolve(result.join(""))
    })
  }).then(compiledData => {
    compiledData = compiledData.replace(
      `======= ${contractFile}:${contractName} =======\nBinary of the runtime part: `,
      "@@@@"
    )

    const matched = compiledData.match(/@@@@\n([a-f0-9]+)/)
    return { key, compiledData: matched[1], contractName, contractFile }
  })
}

// compile files
Promise.all([
  compileContract(
    "validatorContract",
    "contracts/BorValidatorSet.sol",
    "BorValidatorSet"
  ),
  compileContract(
    "slashContract",
    "/sources/contracts/BSCValidatorSet.sol",
    "BSCValidatorSet"
  ),
  compileContract(
    "systemRewardContract",
    "/sources/contracts/SystemReward",
    "SystemReward"
  ),
  compileContract(
      "lightClientContract",
      "/sources/contracts/mock/child/LightClient.sol",
      "LightClient"
  ),
  compileContract(
      "crossChainTransferContract",
      "/sources/contracts/mock/CrossChainTransfer.sol",
      "CrossChainTransfer"
  ),
]).then(result => {

  let extraData = we3.utils.bytesToHex(generateExtradata(validators));
  const data = {
    chainId: program.borChainId,
    initHolders: init_holders,
    extraData: extraData
  }
  result.forEach(r => {
    data[r.key] = r.compiledData
  })
  const templateString = fs.readFileSync(program.template).toString()
  const resultString = nunjucks.renderString(templateString, data)
  fs.writeFileSync(program.output, resultString)

})



function generateExtradata(validators) {
  let extraVanity =Buffer.alloc(32);
  let validatorsBytes = extraDataSerialize(validators);
  let extraSeal =Buffer.alloc(65);blur()
  return Buffer.concat([extraVanity,validatorsBytes,extraSeal]);
}

function extraDataSerialize(validators) {
  let n = validators.length;
  let arr = [];
  for(let i = 0;i<n;i++){
    let validator = validators[i];
    arr.push(Buffer.from(web3.utils.hexToBytes(validator.consensusAddrList)));
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
  return Buffer.concat(arr);
}