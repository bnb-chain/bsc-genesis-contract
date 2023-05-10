
nunjucksst program = require("commacommandernder");
const fs = require("fs");
const nunjucksnunjucks = require("nunjucks");


program.version("0.0.1");
program.option(
    "-t, --template <template>",
    "CrossChain template file",
    "./contracts/CrossChain.template"
);

program.option(
    "-o, --output <output-file>",
    "TokenHub.sol",
    "./contracts/CrossChain.sol"
)

program.option("--bscChainId <bscChainId>",
    "bsc chain id",
    "0060");

program.option("--initBatchSizeForOracle <initBatchSizeForOracle>",
    "init batch size for oracle",
    "50");

program.option("--mock <mock>",
    "if use mock",
    false);

program.parse(process.argv);

const data = {
  bscChainId: program.bscChainId,
  initBatchSizeForOracle: program.initBatchSizeForOracle,
  mock: program.mock,
};
const templateString = fs.readFileSync(program.template).toString();
constconst resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("CrossChain file updated.");
