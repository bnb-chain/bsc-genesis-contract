const program = require("commander");
const fs = require("fs");
const nunjucks = require("nunjucks");


program.version("0.0.1");
program.option(
    "-t, --template <template>",
    "TokenHub template file",
    "./contracts/TokenHub.template"
);

program.option(
    "-o, --output <output-file>",
    "TokenHub.sol",
    "./contracts/TokenHub.sol"
)

program.option("--initRelayFee <initRelayFee>",
    "initRelayFee",
    "2e15");

program.option("--rewardUpperLimit <rewardUpperLimit>",
    "rewardUpperLimit",
    "1e18");

program.option("--maxGasForCallingBEP20 <maxGasForCallingBEP20>",
    "maxGasForCallingBEP20",
    "50000");

program.option("--maxGasForTransferringBNB <maxGasForTransferringBNB>",
    "maxGasForTransferringBNB",
    "10000");

program.option("--mock <mock>",
    "if use mock",
    false);

program.parse(process.argv);

const data = {
    initRelayFee: program.initRelayFee,
    rewardUpperLimit: program.rewardUpperLimit,
    maxGasForCallingBEP20: program.maxGasForCallingBEP20,
    maxGasForTransferringBNB: program.maxGasForTransferringBNB,
    mock: program.mock,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("TokenHub file updated.");
