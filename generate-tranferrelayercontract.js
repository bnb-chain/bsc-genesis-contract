const program = require("commander");
const fs = require("fs");
const nunjucks = require("nunjucks");


program.version("0.0.1");
program.option(
    "-t, --template <template>",
    "TransferRelayerIncentivize template file",
    "./contracts/TransferRelayerIncentivize.template"
);

program.option(
    "-o, --output <output-file>",
    "TransferRelayerIncentivize.sol",
    "./contracts/TransferRelayerIncentivize.sol"
)
program.option("--roundSize <roundSize>",
    "roundSize",
    "1000");

program.option("--maximumWeight <maximumWeight>",
    "maximumWeight",
    "400");

program.parse(process.argv);

const data = {
  roundSize: program.roundSize,
  maximumWeight: program.maximumWeight,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("TransferRelayerIncentivize file updated.");
