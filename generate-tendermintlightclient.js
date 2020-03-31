const program = require("commander");
const fs = require("fs");
const nunjucks = require("nunjucks");


program.version("0.0.1");
program.option(
    "-t, --template <template>",
    "TendermintLightClient template file",
    "./contracts/TendermintLightClient.template"
);

program.option(
    "-o, --output <output-file>",
    "TendermintLightClient.sol",
    "./contracts/TendermintLightClient.sol"
)

program.option("--chainID <chainID>",
    "chainID",
    "Binance-Chain-Nile");

program.option("--rewardForValidatorSetChange <rewardForValidatorSetChange>",
    "rewardForValidatorSetChange",
    "10000000000000000"); //1e16

program.option("--initConsensusStateBytes <initConsensusStateBytes>",
    "init consensusState bytes, hex encoding, no prefix with 0x",
    "746573742d636861696e00000000000000000000000000000000000000000000000000000000000229eca254b3859bffefaf85f4c95da9fbd26527766b784272789c30ec56b380b6eb96442aaab207bc59978ba3dd477690f5c5872334fc39e627723daa97e441e88ba4515150ec3182bc82593df36f8abb25a619187fcfab7e552b94e64ed2deed000000e8d4a51000");

program.option("--mock <mock>",
    "if use mock",
    false);

program.parse(process.argv);

const data = {
  initConsensusStateBytes: program.initConsensusStateBytes,
  chainID: program.chainID,
  rewardForValidatorSetChange: program.rewardForValidatorSetChange,
  mock: program.mock,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("TendermintLightClient file updated.");
