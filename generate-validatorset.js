const program = require("commander");
const fs = require("fs");
const nunjucks = require("nunjucks");


program.version("0.0.1");
program.option(
    "-t, --template <template>",
    "validatorSet template file",
    "./contracts/BSCValidatorSet.template"
);

program.option(
    "-o, --output <output-file>",
    "BSCValidatorSet.sol",
    "./contracts/BSCValidatorSet.sol"
)

program.option("--mock <mock>",
    "if use mock",
    false);

program.parse(process.argv);

const validators = require("./validators")

const data = {
  initValidatorSetBytes: validators.validatorSetBytes.slice(2),
  mock: program.mock,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("BSCValidatorSet file updated.");
