const program = require('commander');
const fs = require('fs');
const nunjucks = require('nunjucks');

nunjucks.configure('views', { autoescape: true });

program.version('0.0.1');
program.option(
  '-t, --template <template>',
  'init holders template file',
  './init_holders.template'
);
program.option('-o, --output <output-file>', 'init_holders.js', './init_holders.js');
program.option(
  '--initHolders <initHolders...>',
  ' A list of addresses separated by comma',
  (value) => {
    return value.split(',');
  }
);
program.parse(process.argv);

const data = {
  initHolders: program.initHolders,
};
const templateString = fs.readFileSync(program.template).toString();
const resultString = nunjucks.renderString(templateString, data);
fs.writeFileSync(program.output, resultString);
console.log('init_holders file updated.');
