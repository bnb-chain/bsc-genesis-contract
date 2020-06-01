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

program.option("--refundRelayReward <refundRelayReward>",
    "refundRelayReward",
    "1e16");

program.option("--minimumRelayFee <minimumRelayFee>",
    "minimumRelayFee",
    "1e16");

program.option("--moleculeForHeaderRelayer <moleculeForHeaderRelayer>",
    "moleculeForHeaderRelayer",
    "1");

program.option("--denominatorForHeaderRelayer <denominatorForHeaderRelayer>",
    "denominatorForHeaderRelayer",
    "5");

program.option("--maxGasForCallingBEP2E <maxGasForCallingBEP2E>",
    "maxGasForCallingBEP2E",
    "50000");

program.option("--mock <mock>",
    "if use mock",
    false);

program.parse(process.argv);

const data = {
  refundRelayReward: program.refundRelayReward,
  minimumRelayFee: program.minimumRelayFee,
  moleculeForHeaderRelayer: program.moleculeForHeaderRelayer,
  denominatorForHeaderRelayer: program.denominatorForHeaderRelayer,
  maxGasForCallingBEP2E: program.maxGasForCallingBEP2E,
  mock: program.mock,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("TokenHub file updated.");
