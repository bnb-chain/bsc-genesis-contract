const program = require("commander");
const fs = require("fs");
const nunjucks = require("nunjucks");
const formatChainID = require("./utils");

program.version("0.0.1");
program.option(
    "-t, --template <template>",
    "system template file",
    "./contracts/System.template"
);

program.option(
    "-o, --output <output-file>",
    "System.sol",
    "./contracts/System.sol"
)
program.option("--network <network>",
    "network",
    "mainnet");

program.option("--mock <mock>",
    "if use mock",
    false);


program.parse(process.argv);


const bscChainId = formatChainID(program.chainid);

const data = {
  fromChainId: program.fromChainId,
  bscChainId: bscChainId,
  mock: program.mock,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("System file updated.");
