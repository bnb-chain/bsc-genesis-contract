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

program.option("--whitelist1Address <whitelist1Address>", "first whitelisted address", "0xb005741528b86F5952469d80A8614591E3c5B632");
program.option("--whitelist2Address <whitelist2Address>", "second whitelisted address", "0x446AA6E0DC65690403dF3F127750da1322941F3e");

program.parse(process.argv);

const data = {
  network: program.network,
  whitelist1Address: program.whitelist1Address,
  whitelist2Address: program.whitelist2Address,
};

const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("RelayerHub file updated.");
