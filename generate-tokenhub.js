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
program.option("--fromChainId <fromChainId>",
    "fromChainId",
    "0001");

program.option("--toChainId <toChainId>",
    "toChainId",
    "0002");

program.option("--refundRelayReward <refundRelayReward>",
    "refundRelayReward",
    "1e16");

program.option("--minimumRelayFee <minimumRelayFee>",
    "minimumRelayFee",
    "1e16");

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
  fromChainId: program.fromChainId,
  toChainId: program.toChainId,
  maxGasForCallingERC20: program.maxGasForCallingERC20,
  mock: program.mock,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("TokenHub file updated.");
