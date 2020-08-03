const program = require("commander");
const fs = require("fs");
const nunjucks = require("nunjucks");


program.version("0.0.1");
program.option(
    "-t, --template <template>",
    "RelayerIncentivize template file",
    "./contracts/RelayerIncentivize.template"
);

program.option(
    "-o, --output <output-file>",
    "RelayerIncentivize.sol",
    "./contracts/RelayerIncentivize.sol"
)
program.option("--roundSize <roundSize>",
    "roundSize",
    "100");

program.option("--maximumWeight <maximumWeight>",
    "maximumWeight",
    "40");

program.option("--moleculeHeaderRelayer <moleculeHeaderRelayer>",
    "moleculeHeaderRelayer",
    "1");

program.option("--denominatorHeaderRelayer <denominatorHeaderRelayer>",
    "denominatorHeaderRelayer",
    "5");

program.option("--moleculeCallerCompensation <moleculeCallerCompensation>",
    "moleculeCallerCompensation",
    "1");

program.option("--denominatorCallerCompensation <denominatorCallerCompensation>",
    "denominatorCallerCompensation",
    "80");

program.option("--mock <mock>",
    "if use mock",
    false);

program.parse(process.argv);

const data = {
  roundSize: program.roundSize,
  maximumWeight: program.maximumWeight,
  moleculeHeaderRelayer: program.moleculeHeaderRelayer,
  denominatorHeaderRelayer: program.denominatorHeaderRelayer,
  moleculeCallerCompensation: program.moleculeCallerCompensation,
  denominatorCallerCompensation: program.denominatorCallerCompensation,
  mock: program.mock,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("RelayerIncentivize file updated.");
