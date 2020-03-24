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
program.option("--sourceChainId <sourceChainId>",
    "sourceChainId",
    "0x0003");

program.option("--destChainId <destChainId>",
    "destChainId",
    "0x000f");

program.option("--mock <mock>",
    "if use mock",
    false);

program.parse(process.argv);

const data = {
  sourceChainId: program.fromChainId,
  destChainId: program.destChainId,
  mock: program.mock,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("TokenHub file updated.");
