import 'dotenv/config';
import {execSync} from 'child_process';
import * as assert from "assert";
import * as fs from "fs";

const log = console.log;

const work = async () => {
  log('compare current bytecode with latest mainnet contracts')
  let str = (fs.readFileSync(__dirname + '/../genesis.json')).toString();
  const currentGenesis = JSON.parse(str);
  log('currentGenesis size:', JSON.stringify(currentGenesis, null, 2).length)

  const result = execSync('poetry run python -m scripts.generate mainnet')
  const resultStr = result.toString()
  if (resultStr.indexOf('Generate genesis of mainnet successfully') === -1) {
    throw Error(`generate mainnet genesis failed, error result: ${resultStr}`)
  }
  await sleep(5)
  log('generated mainnet genesis')

  str = (fs.readFileSync(__dirname + '/../genesis.json')).toString();
  const generatedGenesis = JSON.parse(str);
  log('generatedGenesis size:', JSON.stringify(generatedGenesis, null, 2).length)

  log('try deepStrictEqual(currentGenesis, generatedGenesis)')
  assert.deepStrictEqual(currentGenesis, generatedGenesis)

  log('Success! genesis bytecode not changed')
};

const sleep = async (seconds: number) => {
  console.log('sleep', seconds, 's');
  await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
};

const main = async () => {
  await work();
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

