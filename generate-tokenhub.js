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
    "10000000000000000");

program.option("--minimumRelayFee <minimumRelayFee>",
    "minimumRelayFee",
    "10000000000000000");

program.option("--maxGasForCallingERC20 <maxGasForCallingERC20>",
    "maxGasForCallingERC20",
    "50000");

program.option("--mock <mock>",
    "if use mock",
    false);

program.parse(process.argv);

const data = {
  refundRelayReward: program.refundRelayReward,
  minimumRelayFee: program.minimumRelayFee,
  maxGasForCallingERC20: program.maxGasForCallingERC20,
  mock: program.mock,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("TokenHub file updated.");
