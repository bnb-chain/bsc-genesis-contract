const { spawn } = require("child_process")
const program = require("commander")
const nunjucks = require("nunjucks")
const fs = require("fs")
const web3 = require("web3")

const validators = require("./validators")
const init_holders = require("./init_holders")

// load and execute generate-system.js
require("./generate-system");
require("./generate-validatorset");

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

// compile contract
function compileContract(key, contractFile, contractName) {
  return new Promise((resolve, reject) => {
    const ls = spawn("solc", [
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
      `======= ${contractFile}:${contractName} =======\nBinary of the runtime part:`,
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
    "contracts/BSCValidatorSet.sol",
    "BSCValidatorSet"
  ),
  compileContract(
    "systemRewardContract",
    "contracts/SystemReward.sol",
    "SystemReward"
  ),
  compileContract(
      "slashContract",
      "contracts/SlashIndicator.sol",
      "SlashIndicator"
  ),
  compileContract(
      "lightClientContract",
      "contracts/mock/LightClient.sol",
      "LightClient"
  ),
  compileContract(
      "crossChainTransferContract",
      "contracts/mock/CrossChainTransfer.sol",
      "CrossChainTransfer"
  ),
]).then(result => {

  const data = {
    chainId: program.chainId,
    initHolders: init_holders,
    extraData: web3.utils.bytesToHex(validators.extraValidatorBytes)
  }
  result.forEach(r => {
    data[r.key] = r.compiledData
  })
  const templateString = fs.readFileSync(program.template).toString()
  const resultString = nunjucks.renderString(templateString, data)
  fs.writeFileSync(program.output, resultString)

})
