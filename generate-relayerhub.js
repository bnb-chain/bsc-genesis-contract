const program = require("commander");
const fs = require("fs");
const nunjucks = require("nunjucks");

program.version("0.0.1");
program.option(
    "-t, --template <template>",
    "RelayerHub template file",
    "./contracts/RelayerHub.template"
);

program.option(
    "-o, --output <output-file>",
    "RelayerHub.sol",
    "./contracts/RelayerHub.sol"
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
console.log("RelayerHub file updated.");
