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

program.option("--mock <mock>",
    "if use mock",
    false);

program.parse(process.argv);

const data = {
  mock: program.mock,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("Govhub file updated.");
