const program = require("commander");
const fs = require("fs");
const { attempt } = require("lodash");
const nunjucks = require("nunjucks");
const { exit } = require("process");


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

program.option(
    "--initValidatorSetBytes <initValidatorSetBytes>",
    "initValidatorSetBytes",
    ""
)

program.option(
    "--admin <admin>",
    "admin",
    ""
)

program.option(
    "--initBurnRatio <initBurnRatio>",
    "initBurnRatio",
    "0"
)

program.option("--mock <mock>",
    "if use mock",
    false);

program.parse(process.argv);

const validators = require("./validators")
let initValidatorSetBytes = program.initValidatorSetBytes;
if (initValidatorSetBytes == "") {
    initValidatorSetBytes = validators.validatorSetBytes.slice(2);
}

if (program.admin == "") {
    console.log("argument admin is empty");
    exit(2)
}

const data = {
    initValidatorSetBytes: initValidatorSetBytes,
    initBurnRatio: program.initBurnRatio,
    mock: program.mock,
    admin: program.admin,
};

const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log("BSCValidatorSet file updated.");