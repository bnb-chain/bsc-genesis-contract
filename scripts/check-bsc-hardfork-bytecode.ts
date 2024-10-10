import 'dotenv/config';
import {execSync} from 'child_process';
import * as fs from "fs";
import * as fsp from 'fs/promises';
import * as path from "node:path";

const log = console.log;

let contractNameMap: any = {}
const VALIDATOR_CONTRACT_ADDR = '0x0000000000000000000000000000000000001000';
contractNameMap[VALIDATOR_CONTRACT_ADDR] = 'ValidatorContract'

const SLASH_CONTRACT_ADDR = '0x0000000000000000000000000000000000001001';
contractNameMap[SLASH_CONTRACT_ADDR] = 'SlashContract'

const SYSTEM_REWARD_ADDR = '0x0000000000000000000000000000000000001002';
contractNameMap[SYSTEM_REWARD_ADDR] = 'SystemRewardContract'

const LIGHT_CLIENT_ADDR = '0x0000000000000000000000000000000000001003';
contractNameMap[LIGHT_CLIENT_ADDR] = 'LightClientContract'

const TOKEN_HUB_ADDR = '0x0000000000000000000000000000000000001004';
contractNameMap[TOKEN_HUB_ADDR] = 'TokenHubContract'

const INCENTIVIZE_ADDR = '0x0000000000000000000000000000000000001005';
contractNameMap[INCENTIVIZE_ADDR] = 'RelayerIncentivizeContract'

const RELAYERHUB_CONTRACT_ADDR = '0x0000000000000000000000000000000000001006';
contractNameMap[RELAYERHUB_CONTRACT_ADDR] = 'RelayerHubContract'

const GOV_HUB_ADDR = '0x0000000000000000000000000000000000001007';
contractNameMap[GOV_HUB_ADDR] = 'GovHubContract'

const TOKEN_MANAGER_ADDR = '0x0000000000000000000000000000000000001008';
contractNameMap[TOKEN_MANAGER_ADDR] = 'TokenManagerContract'

const CROSS_CHAIN_CONTRACT_ADDR = '0x0000000000000000000000000000000000002000';
contractNameMap[CROSS_CHAIN_CONTRACT_ADDR] = 'CrossChainContract'

const STAKING_CONTRACT_ADDR = '0x0000000000000000000000000000000000002001';
contractNameMap[STAKING_CONTRACT_ADDR] = 'StakingContract'

const STAKE_HUB_ADDR = '0x0000000000000000000000000000000000002002';
contractNameMap[STAKE_HUB_ADDR] = 'StakeHubContract'

const STAKE_CREDIT_ADDR = '0x0000000000000000000000000000000000002003';
contractNameMap[STAKE_CREDIT_ADDR] = 'StakeCreditContract'

const GOVERNOR_ADDR = '0x0000000000000000000000000000000000002004';
contractNameMap[GOVERNOR_ADDR] = 'GovernorContract'

const GOV_TOKEN_ADDR = '0x0000000000000000000000000000000000002005';
contractNameMap[GOV_TOKEN_ADDR] = 'GovTokenContract'

const TIMELOCK_ADDR = '0x0000000000000000000000000000000000002006';
contractNameMap[TIMELOCK_ADDR] = 'TimelockContract'

const TOKEN_RECOVER_PORTAL_ADDR = '0x0000000000000000000000000000000000003000';
contractNameMap[TOKEN_RECOVER_PORTAL_ADDR] = 'TokenRecoverPortalContract'

let hardforkName = process.env.HARDFORK
let bscUrl = process.env.BSC_URL
let bscRepoDir = '/tmp/bsc'

const checkHardforkBytecode = async () => {
  const bscHardforkBytecodeDir = bscRepoDir + '/core/systemcontracts/' + hardforkName
  const mainnetDir = bscHardforkBytecodeDir + '/mainnet'
  const testnetDir = bscHardforkBytecodeDir + '/chapel'

  log('---------------------------------------------------------------------------')
  log(`Mainnet: compare genesis bytecode with bsc repo`)
  const mainnetHardforkFiles = await searchFiles(mainnetDir, 'Contract')
  if (mainnetHardforkFiles.length === 0) {
    throw new Error(`cannot find any files in ${mainnetDir}`)
  }
  const mainnetGenesis = __dirname + '/../genesis.json'
  await compareGenesisWithHardforkBytecodes(mainnetGenesis, mainnetHardforkFiles)

  log('---------------------------------------------------------------------------')
  log(`Testnet: compare genesis bytecode with bsc repo`)
  const testnetHardforkFiles = await searchFiles(testnetDir, 'Contract')
  if (testnetHardforkFiles.length === 0) {
    throw new Error(`cannot find any files in ${testnetDir}`)
  }
  const testnetGenesis = __dirname + '/../genesis-testnet.json'
  await compareGenesisWithHardforkBytecodes(testnetGenesis, testnetHardforkFiles)
};

const compareGenesisWithHardforkBytecodes = async (genesisFile: string, files: string[]) => {
  const genesis: any = require(genesisFile)
  for (const addr in genesis['alloc']) {
    if (!genesis['alloc'][addr]['code']) {
      continue;
    }

    const contractName = contractNameMap[addr]
    const bytecode = clear0x(genesis['alloc'][addr]['code'])

    log('---------------------------------------------------------------------------')
    log(contractName, addr)
    log('bytecode from genesis:', bytecode.length, )

    const bytecodeFromBsc = getBytecodeFromBscRepo(contractName, files)
    if (!bytecodeFromBsc) {
      log(`cannot find bytecode for ${contractName} in bsc repo`)
      continue;
    }

    log('bytecode from bsc repo:', bytecodeFromBsc.length, )

    if (bytecode === bytecodeFromBsc) {
      log('Success!')
    } else {
      throw new Error(`bytecode not match for ${contractName}`)
    }
  }
}

const getBytecodeFromBscRepo = (contractName: string, files: string[]): string | undefined => {
  for (let i = 0; i < files.length; i++) {
    const file = files[i]
    if (file.includes(`/${contractName}`)) {
      return clear0x((fs.readFileSync(file)).toString());
    }
  }
  return undefined
}

const searchFiles = async (searchDir: string, searchSuffix = ''): Promise<string[]> => {
  let fileList: string[] = []
  try {
    const files = await fsp.readdir(searchDir);

    for (const file of files) {
      const filePath = path.join(searchDir, file);
      const stats = await fsp.stat(filePath);

      // recursive search
      if (stats.isDirectory()) {
        fileList = fileList.concat(await searchFiles(filePath));
      } else {
        if (searchSuffix.length > 0 && filePath.endsWith(searchSuffix)) {
          // success find target file which ends with searchSuffix
          fileList.push(filePath)
        }
      }
    }
  } catch (err) {
    console.error(`!! Error reading directory ${searchDir}:`, err);
  }

  return fileList;
}

const clear0x = (str: string) => {
  if (str.startsWith('0x')) return str.substring(2)
  return str
};

const main = async () => {

  if (!hardforkName) {
    throw new Error('HARDFORK is required in .env')
  }

  if (!bscUrl) {
    throw new Error('BSC_URL is required in .env')
  }

  hardforkName = hardforkName.trim()
  bscUrl = bscUrl.trim()

  const p= bscUrl.lastIndexOf('/')
  const commitId = bscUrl.substring(p+1)

  log('hardforkName', hardforkName, 'commitId', commitId)

  execSync(`cd /tmp && git clone https://github.com/bnb-chain/bsc.git && cd bsc && git checkout ${commitId}`)

  await sleep(5)

  await checkHardforkBytecode();

  log('All bytecode match!')
};

const sleep = async (seconds: number) => {
  console.log('sleep', seconds, 's');
  await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

