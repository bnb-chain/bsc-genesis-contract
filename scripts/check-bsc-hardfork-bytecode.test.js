const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

require('ts-node/register');
const {compareGenesisWithHardforkBytecodes} = require('./check-bsc-hardfork-bytecode.ts');

test('the hardfork check fails when a genesis contract has no matching BSC bytecode file', async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'bsc-bytecode-test-'));
  try {
    const genesis = path.join(directory, 'genesis.json');
    fs.writeFileSync(genesis, JSON.stringify({
      alloc: {'0x0000000000000000000000000000000000001000': {code: '0x1234'}},
    }));

    await assert.rejects(
      compareGenesisWithHardforkBytecodes(genesis, []),
      /cannot find bytecode for ValidatorContract in bsc repo/,
    );

    const similarlyNamedFile = path.join(directory, 'ValidatorContractFakeContract');
    fs.writeFileSync(similarlyNamedFile, '0x1234');
    await assert.rejects(
      compareGenesisWithHardforkBytecodes(genesis, [similarlyNamedFile]),
      /cannot find bytecode for ValidatorContract in bsc repo/,
    );

    const bytecodeFile = path.join(directory, 'ValidatorContract');
    fs.writeFileSync(bytecodeFile, '0x1234');
    await assert.doesNotReject(compareGenesisWithHardforkBytecodes(genesis, [bytecodeFile]));
  } finally {
    fs.rmSync(directory, {recursive: true, force: true});
  }
});
