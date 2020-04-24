const program = require("commander");
const fs = require("fs");
const nunjucks = require("nunjucks");


program.version("0.0.1");
program.option(
    "-t, --template <template>",
    "validatorSet template file",
    "./contracts/GovHub.template"
);

program.option(
    "-o, --output <output-file>",
    "BSCValidatorSet.sol",
    "./contracts/GovHub.sol"
)
program.option("--fromChainId <fromChainId>",
    "fromChainId",
    "0001");

program.option("--toChainId <toChainId>",
    "toChainId",
    "0002");

program.option("--mock <mock>",
    "if use mock",
    false);

program.parse(process.argv);

const data = {
  fromChainId: program.fromChainId,
  toChainId: program.toChainId,
  mock: program.mock,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("Govhub file updated.");
