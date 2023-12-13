import fileinput
import os
import re
import shutil
import subprocess

import jinja2
import typer
from typing_extensions import Annotated
from web3 import Web3

work_dir = os.getcwd()
if work_dir.endswith("scripts"):
    work_dir = work_dir[:-8]

network: str
chain_id: int
hex_chain_id: str

main = typer.Typer()


def backup_file(source, destination):
    try:
        shutil.copyfile(source, destination)
    except FileNotFoundError:
        print(f"Source file '{source}' not found.")
    except PermissionError:
        print(f"Permission error: Unable to copy file '{source}' to '{destination}'.")
    except Exception as e:
        print(f"An error occurred: {e}")


def insert(contract, pattern, ins):
    pattern = re.compile(pattern)
    filepath = os.path.join(work_dir, "contracts", contract)

    found = False
    with fileinput.FileInput(filepath, inplace=True) as file:
        for line in file:
            if not found and pattern.search(line):
                print(ins)
                found = True
            print(line, end="")

    if not found:
        raise Exception(f"{pattern} not found")


def replace(contract, pattern, repl, count=1):
    pattern = re.compile(pattern)
    filepath = os.path.join(work_dir, "contracts", contract)

    with open(filepath, "r") as f:
        content = f.read()

    if pattern.search(content):
        content = pattern.sub(repl, content, count=count)
    else:
        raise Exception(f"{pattern} not found")

    with open(filepath, "w") as f:
        f.write(content)


def replace_parameter(contract, parameter, value):
    pattern = f"{parameter} =[^;]*;"
    repl = f"{parameter} = {value};"

    replace(contract, pattern, repl)


def convert_chain_id(int_chain_id: int):
    try:
        hex_representation = hex(int_chain_id)[2:]
        padded_hex = hex_representation.zfill(4)
        return padded_hex
    except Exception as e:
        print(f"Error converting {int_chain_id} to hex: {e}")
        return None


def generate_from_template(data, template_file, output_file):
    template_loader = jinja2.FileSystemLoader(work_dir)
    template_env = jinja2.Environment(loader=template_loader, autoescape=True)

    template = template_env.get_template(template_file)
    result_string = template.render(data)

    output_path = os.path.join(work_dir, output_file)
    with open(output_path, "w") as output_file:
        output_file.write(result_string)


def generate_cross_chain(init_batch_size="50"):
    contract = "CrossChain.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "uint256 constant public CROSS_CHAIN_KEY_PREFIX", f"0x01{hex_chain_id}00")
    replace_parameter(contract, "uint256 constant public INIT_BATCH_SIZE", f"{init_batch_size}")


def generate_relayer_hub(whitelist_1, whitelist_2):
    contract = "RelayerHub.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "address public constant WHITELIST_1", f"{whitelist_1}")
    replace_parameter(contract, "address public constant WHITELIST_2", f"{whitelist_2}")

    if network == "dev":
        replace(contract, r"function whitelistInit\(\) external", "function whitelistInit() public")
        insert(contract, "alreadyInit = true;", "\t\twhitelistInit();")


def generate_slash_indicator(init_felony_slash_scope):
    contract = "SlashIndicator.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "uint256 public constant INIT_FELONY_SLASH_SCOPE", f"{init_felony_slash_scope}")

    if network == "dev":
        insert(contract, "alreadyInit = true;", "\t\tenableMaliciousVoteSlash = true;")


def generate_stake_hub(
    breathe_block_interval, init_bc_consensus_addresses, init_bc_vote_addresses, unbond_period, downtime_jail_time,
    felony_jail_time, asset_protector
):
    contract = "BC_fusion/StakeHub.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "uint256 public constant BREATHE_BLOCK_INTERVAL", f"{breathe_block_interval}")
    replace_parameter(contract, "bytes private constant INIT_BC_CONSENSUS_ADDRESSES", f"{init_bc_consensus_addresses}")
    replace_parameter(contract, "bytes private constant INIT_BC_VOTE_ADDRESSES", f"{init_bc_vote_addresses}")

    replace(contract, r"unbondPeriod = .*;", f"unbondPeriod = {unbond_period};")
    replace(contract, r"downtimeJailTime = .*;", f"downtimeJailTime = {downtime_jail_time};")
    replace(contract, r"felonyJailTime = .*;", f"felonyJailTime = {felony_jail_time};")
    replace(contract, r"assetProtector = .*;", f"assetProtector = {asset_protector};")


def generate_governor(
    block_interval, init_voting_delay, init_voting_period, init_min_period_after_quorum, governor_protector
):
    contract = "BC_fusion/BSCGovernor.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "uint256 private constant BLOCK_INTERVAL", f"{block_interval}")
    replace_parameter(contract, "uint256 private constant INIT_VOTING_DELAY", f"{init_voting_delay}")
    replace_parameter(contract, "uint256 private constant INIT_VOTING_PERIOD", f"{init_voting_period}")
    replace_parameter(
        contract, "uint64 private constant INIT_MIN_PERIOD_AFTER_QUORUM", f"{init_min_period_after_quorum}"
    )
    replace(contract, r"governorProtector = .*;", f"governorProtector = {governor_protector};")


def generate_timelock(init_minimal_delay):
    contract = "BC_fusion/BSCTimelock.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "uint256 private constant INIT_MINIMAL_DELAY", f"{init_minimal_delay}")


def generate_system():
    contract = "System.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "uint16 constant public bscChainID", f"0x{hex_chain_id}")


def generate_system_reward():
    if network == "dev":
        contract = "SystemReward.sol"
        backup_file(
            os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
        )

        insert(contract, "numOperator = 2;", "\t\toperators[VALIDATOR_CONTRACT_ADDR] = true;")
        insert(contract, "numOperator = 2;", "\t\toperators[SLASH_CONTRACT_ADDR] = true;")
        replace(contract, "numOperator = 2;", "numOperator = 4;")


def generate_tendermint_light_client(init_consensus_state_bytes, init_reward_for_validator_ser_change="1e16"):
    contract = "TendermintLightClient.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(
        contract, "bytes constant public INIT_CONSENSUS_STATE_BYTES", f"hex\"{init_consensus_state_bytes}\""
    )
    replace_parameter(
        contract, "uint256 constant public INIT_REWARD_FOR_VALIDATOR_SER_CHANGE",
        f"{init_reward_for_validator_ser_change}"
    )


def generate_token_hub(max_gas_for_transfer_bnb, max_gas_for_calling_bep20, reward_upper_limit, init_minimum_relay_fee):
    contract = "TokenHub.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "uint256 constant public MAX_GAS_FOR_TRANSFER_BNB", f"{max_gas_for_transfer_bnb}")
    replace_parameter(contract, "uint256 constant public MAX_GAS_FOR_CALLING_BEP20", f"{max_gas_for_calling_bep20}")
    replace_parameter(contract, "uint256 constant public REWARD_UPPER_LIMIT", f"{reward_upper_limit}")
    replace_parameter(contract, "uint256 constant public INIT_MINIMUM_RELAY_FEE", f"{init_minimum_relay_fee}")


def generate_token_recover_portal(source_chain_id):
    contract = "BC_fusion/TokenRecoverPortal.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "string public constant SOURCE_CHAIN_ID", f"\"{source_chain_id}\"")


def generate_validator_set(init_burn_ratio, init_validatorset_bytes):
    contract = "BSCValidatorSet.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "uint256 public constant INIT_BURN_RATIO", f"{init_burn_ratio}")
    replace_parameter(contract, "bytes public constant INIT_VALIDATORSET_BYTES", f"hex\"{init_validatorset_bytes}\"")

    if network == "dev":
        insert(
            contract, r"for \(uint i; i<validatorSetPkg\.validatorSet\.length; \+\+i\)",
            "\t\tValidatorExtra memory validatorExtra;"
        )
        insert(
            contract, r"currentValidatorSet\.push\(validatorSetPkg.validatorSet\[i\]\);",
            "\t\t\tvalidatorExtraSet.push(validatorExtra);"
        )
        insert(
            contract, r"currentValidatorSet\.push\(validatorSetPkg.validatorSet\[i\]\);",
            "\t\t\tvalidatorExtraSet[i].voteAddress=validatorSetPkg.voteAddrs[i];"
        )


def generate_genesis():
    subprocess.run(["forge", "build"], cwd=work_dir)
    subprocess.run(["node", "scripts/generate-genesis.js", "--chainId", f"{chain_id}"], cwd=work_dir)


@main.command(help="Generate contracts for BSC mainnet")
def mainnet():
    global network, chain_id, hex_chain_id
    network = "mainnet"
    chain_id = 56
    hex_chain_id = convert_chain_id(chain_id)

    init_consensus_bytes = "42696e616e63652d436861696e2d5469677269730000000000000000000000000000000006915167cedaf7bbf7df47d932fdda630527ee648562cf3e52c5e5f46156a3a971a4ceb443c53a50d8653ef8cf1e5716da68120fb51b636dc6d111ec3277b098ecd42d49d3769d8a1f78b4c17a965f7a30d4181fabbd1f969f46d3c8e83b5ad4845421d8000000e8d4a510002ba4e81542f437b7ae1f8a35ddb233c789a8dc22734377d9b6d63af1ca403b61000000e8d4a51000df8da8c5abfdb38595391308bb71e5a1e0aabdc1d0cf38315d50d6be939b2606000000e8d4a51000b6619edca4143484800281d698b70c935e9152ad57b31d85c05f2f79f64b39f3000000e8d4a510009446d14ad86c8d2d74780b0847110001a1c2e252eedfea4753ebbbfce3a22f52000000e8d4a510000353c639f80cc8015944436dab1032245d44f912edc31ef668ff9f4a45cd0599000000e8d4a51000e81d3797e0544c3a718e1f05f0fb782212e248e784c1a851be87e77ae0db230e000000e8d4a510005e3fcda30bd19d45c4b73688da35e7da1fce7c6859b2c1f20ed5202d24144e3e000000e8d4a51000b06a59a2d75bf5d014fce7c999b5e71e7a960870f725847d4ba3235baeaa08ef000000e8d4a510000c910e2fe650e4e01406b3310b489fb60a84bc3ff5c5bee3a56d5898b6a8af32000000e8d4a5100071f2d7b8ec1c8b99a653429b0118cd201f794f409d0fea4d65b1b662f2b00063000000e8d4a51000"
    init_burn_ratio = "1000"
    init_validatorset_bytes = "f905ec80f905e8f846942a7cdd959bfe8d9487b2a43b33565295a698f7e294b6a7edd747c0554875d3fc531d19ba1497992c5e941ff80f3f7f110ffd8920a3ac38fdef318fe94a3f86048c27395000f846946488aa4d1955ee33403f8ccb1d4de5fb97c7ade294220f003d8bdfaadf52aa1e55ae4cc485e6794875941a87e90e440a39c99aa9cb5cea0ad6a3f0b2407b86048c27395000f846949ef9f4360c606c7ab4db26b016007d3ad0ab86a0946103af86a874b705854033438383c82575f25bc29418e2db06cbff3e3c5f856410a1838649e760175786048c27395000f84694ee01c3b1283aa067c58eab4709f85e99d46de5fe94ee4b9bfb1871c64e2bcabb1dc382dc8b7c4218a29415904ab26ab0e99d70b51c220ccdcccabee6e29786048c27395000f84694685b1ded8013785d6623cc18d214320b6bb6475994a20ef4e5e4e7e36258dbf51f4d905114cb1b34bc9413e39085dc88704f4394d35209a02b1a9520320c86048c27395000f8469478f3adfc719c99674c072166708589033e2d9afe9448a30d5eaa7b64492a160f139e2da2800ec3834e94055838358c29edf4dcc1ba1985ad58aedbb6be2b86048c27395000f84694c2be4ec20253b8642161bc3f444f53679c1f3d479466f50c616d737e60d7ca6311ff0d9c434197898a94d1d678a2506eeaa365056fe565df8bc8659f28b086048c27395000f846942f7be8361c80a4c1e7e9aaf001d0877f1cfde218945f93992ac37f3e61db2ef8a587a436a161fd210b94ecbc4fb1a97861344dad0867ca3cba2b860411f086048c27395000f84694ce2fd7544e0b2cc94692d4a704debef7bcb613289444abc67b4b2fba283c582387f54c9cba7c34bafa948acc2ab395ded08bb75ce85bf0f95ad2abc51ad586048c27395000f84694b8f7166496996a7da21cf1f1b04d9b3e26a3d077946770572763289aac606e4f327c2f6cc1aa3b3e3b94882d745ed97d4422ca8da1c22ec49d880c4c097286048c27395000f846942d4c407bbe49438ed859fe965b140dcf1aab71a9943ad0939e120f33518fbba04631afe7a3ed6327b194b2bbb170ca4e499a2b0f3cc85ebfa6e8c4dfcbea86048c27395000f846946bbad7cf34b5fa511d8e963dbba288b1960e75d694853b0f6c324d1f4e76c8266942337ac1b0af1a229442498946a51ca5924552ead6fc2af08b94fcba648601d1a94a2000f846944430b3230294d12c6ab2aac5c2cd68e80b16b581947b107f4976a252a6939b771202c28e64e03f52d694795811a7f214084116949fc4f53cedbf189eeab28601d1a94a2000f84694ea0a6e3c511bbd10f4519ece37dc24887e11b55d946811ca77acfb221a49393c193f3a22db829fcc8e9464feb7c04830dd9ace164fc5c52b3f5a29e5018a8601d1a94a2000f846947ae2f5b9e386cd1b50a4550696d957cb4900f03a94e83bcc5077e6b873995c24bac871b5ad856047e19464e48d4057a90b233e026c1041e6012ada897fe88601d1a94a2000f8469482012708dafc9e1b880fd083b32182b869be8e09948e5adc73a2d233a1b496ed3115464dd6c7b887509428b383d324bc9a37f4e276190796ba5a8947f5ed8601d1a94a2000f8469422b81f8e175ffde54d797fe11eb03f9e3bf75f1d94a1c3ef7ca38d8ba80cce3bfc53ebd2903ed21658942767f7447f7b9b70313d4147b795414aecea54718601d1a94a2000f8469468bf0b8b6fb4e317a0f9d6f03eaf8ce6675bc60d94675cfe570b7902623f47e7f59c9664b5f5065dcf94d84f0d2e50bcf00f2fc476e1c57f5ca2d57f625b8601d1a94a2000f846948c4d90829ce8f72d0163c1d5cf348a862d5506309485c42a7b34309bee2ed6a235f86d16f059deec5894cc2cedc53f0fa6d376336efb67e43d167169f3b78601d1a94a2000f8469435e7a025f4da968de7e4d7e4004197917f4070f194b1182abaeeb3b4d8eba7e6a4162eac7ace23d57394c4fd0d870da52e73de2dd8ded19fe3d26f43a1138601d1a94a2000f84694d6caa02bbebaebb5d7e581e4b66559e635f805ff94c07335cf083c1c46a487f0325769d88e163b653694efaff03b42e41f953a925fc43720e45fb61a19938601d1a94a2000"
    whitelist_1 = "0xb005741528b86F5952469d80A8614591E3c5B632"
    whitelist_2 = "0x446AA6E0DC65690403dF3F127750da1322941F3e"
    source_chain_id = "Binance-Chain-Tigris"

    generate_system()
    generate_cross_chain()
    generate_relayer_hub(whitelist_1, whitelist_2)
    generate_tendermint_light_client(init_consensus_bytes)
    generate_validator_set(init_burn_ratio, init_validatorset_bytes)
    generate_token_recover_portal(source_chain_id)

    generate_genesis()
    print("Generate genesis of mainnet successfully")


@main.command(help="Generate contracts for BSC testnet")
def testnet():
    global network, chain_id, hex_chain_id
    network = "testnet"
    chain_id = 97
    hex_chain_id = convert_chain_id(chain_id)

    init_consensus_bytes = "42696e616e63652d436861696e2d47616e67657300000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000aea1ac326886b992a991d21a6eb155f41b77867cbf659e78f31d89d8205122a84d1be64f0e9a466c2e66a53433928192783e29f8fa21beb2133499b5ef770f60000000e8d4a5100099308aa365c40554bc89982af505d85da95251445d5dd4a9bb37dd2584fd92d3000000e8d4a5100001776920ff0b0f38d78cf95c033c21adf7045785114e392a7544179652e0a612000000e8d4a51000"
    init_burn_ratio = "1000"
    init_validatorset_bytes = "f901a880f901a4f844941284214b9b9c85549ab3d2b972df0deef66ac2c9946ddf42a51534fc98d0c0a3b42c963cace8441ddf946ddf42a51534fc98d0c0a3b42c963cace8441ddf8410000000f84494a2959d3f95eae5dc7d70144ce1b73b403b7eb6e0948081ef03f1d9e0bb4a5bf38f16285c879299f07f948081ef03f1d9e0bb4a5bf38f16285c879299f07f8410000000f8449435552c16704d214347f29fa77f77da6d75d7c75294dc4973e838e3949c77aced16ac2315dc2d7ab11194dc4973e838e3949c77aced16ac2315dc2d7ab1118410000000f84494980a75ecd1309ea12fa2ed87a8744fbfc9b863d594cc6ac05c95a99c1f7b5f88de0e3486c82293b27094cc6ac05c95a99c1f7b5f88de0e3486c82293b2708410000000f84494f474cf03cceff28abc65c9cbae594f725c80e12d94e61a183325a18a173319dd8e19c8d069459e217594e61a183325a18a173319dd8e19c8d069459e21758410000000f84494b71b214cb885500844365e95cd9942c7276e7fd894d22ca3ba2141d23adab65ce4940eb7665ea2b6a794d22ca3ba2141d23adab65ce4940eb7665ea2b6a78410000000"
    whitelist_1 = "0x9fB29AAc15b9A4B7F17c3385939b007540f4d791"
    whitelist_2 = "0x37B8516a0F88E65D677229b402ec6C1e0E333004"
    source_chain_id = "Binance-Chain-Ganges"

    generate_system()
    generate_cross_chain()
    generate_relayer_hub(whitelist_1, whitelist_2)
    generate_tendermint_light_client(init_consensus_bytes)
    generate_validator_set(init_burn_ratio, init_validatorset_bytes)
    generate_token_recover_portal(source_chain_id)

    generate_genesis()
    print("Generate genesis of testnet successfully")


@main.command(help="Generate contracts for qa environment")
def qa(
    whitelist_1: Annotated[
        str, typer.Option(help="whitelist relayer1's address")] = "0x88cb4D8F77742c24d647BEf8049D3f3C56067cDD",
    whitelist_2: Annotated[
        str, typer.Option(help="whitelist relayer2's address")] = "0x42D596440775C90db8d9187b47650986E1063493",
    source_chain_id: Annotated[
        str, typer.Option(help="source chain id of the token recover portal")] = "Binance-Chain-Ganges"
):
    global network, chain_id, hex_chain_id
    network = "qa"
    chain_id = 714
    hex_chain_id = convert_chain_id(chain_id)

    init_consensus_bytes = "42696e616e63652d436861696e2d47616e67657300000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000aea1ac326886b992a991d21a6eb155f41b77867cbf659e78f31d89d8205122a84d1be64f0e9a466c2e66a53433928192783e29f8fa21beb2133499b5ef770f60000000e8d4a5100099308aa365c40554bc89982af505d85da95251445d5dd4a9bb37dd2584fd92d3000000e8d4a5100001776920ff0b0f38d78cf95c033c21adf7045785114e392a7544179652e0a612000000e8d4a51000"
    init_burn_ratio = "1000"
    init_validatorset_bytes = "f901a880f901a4f844941284214b9b9c85549ab3d2b972df0deef66ac2c9946ddf42a51534fc98d0c0a3b42c963cace8441ddf946ddf42a51534fc98d0c0a3b42c963cace8441ddf8410000000f84494a2959d3f95eae5dc7d70144ce1b73b403b7eb6e0948081ef03f1d9e0bb4a5bf38f16285c879299f07f948081ef03f1d9e0bb4a5bf38f16285c879299f07f8410000000f8449435552c16704d214347f29fa77f77da6d75d7c75294dc4973e838e3949c77aced16ac2315dc2d7ab11194dc4973e838e3949c77aced16ac2315dc2d7ab1118410000000f84494980a75ecd1309ea12fa2ed87a8744fbfc9b863d594cc6ac05c95a99c1f7b5f88de0e3486c82293b27094cc6ac05c95a99c1f7b5f88de0e3486c82293b2708410000000f84494f474cf03cceff28abc65c9cbae594f725c80e12d94e61a183325a18a173319dd8e19c8d069459e217594e61a183325a18a173319dd8e19c8d069459e21758410000000f84494b71b214cb885500844365e95cd9942c7276e7fd894d22ca3ba2141d23adab65ce4940eb7665ea2b6a794d22ca3ba2141d23adab65ce4940eb7665ea2b6a78410000000"

    generate_system()
    generate_cross_chain()
    generate_relayer_hub(whitelist_1, whitelist_2)
    generate_tendermint_light_client(init_consensus_bytes)
    generate_validator_set(init_burn_ratio, init_validatorset_bytes)
    generate_token_recover_portal(source_chain_id)

    generate_genesis()
    print("Generate genesis of qa environment successfully")


@main.command(help="Generate contracts for dev environment")
def dev(
    dev_chain_id: int = 714,
    init_consensus_bytes:
    str = "42696e616e63652d436861696e2d4e696c650000000000000000000000000000000000000000000229eca254b3859bffefaf85f4c95da9fbd26527766b784272789c30ec56b380b6eb96442aaab207bc59978ba3dd477690f5c5872334fc39e627723daa97e441e88ba4515150ec3182bc82593df36f8abb25a619187fcfab7e552b94e64ed2deed000000e8d4a51000",
    init_burn_ratio: Annotated[str, typer.Option(help="init burn ratio of BscValidatorSet")] = "1000",
    whitelist_1: Annotated[
        str, typer.Option(help="whitelist relayer1's address")] = "0xA904540818AC9c47f2321F97F1069B9d8746c6DB",
    whitelist_2: Annotated[
        str, typer.Option(help="whitelist relayer2's address")] = "0x316b2Fa7C8a2ab7E21110a4B3f58771C01A71344",
    source_chain_id: Annotated[
        str, typer.Option(help="source chain id of the token recover portal")] = "Binance-Chain-Ganges",
    init_felony_slash_scope: str = "86400",
    breathe_block_interval: Annotated[str, typer.Option(help="breath block interval of Parlia")] = "1 days",
    block_interval: Annotated[str, typer.Option(help="block interval of Parlia")] = "3 seconds",
    init_bc_consensus_addresses:
    str = 'hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000"',
    init_bc_vote_addresses:
    str = 'hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000"',
    asset_protector: Annotated[str, typer.Option(help="assetProtector of StakeHub")] = "address(0xdEaD)",
    unbond_period: Annotated[str, typer.Option(help="unbondPeriod of StakeHub")] = "7 days",
    downtime_jail_time: Annotated[str, typer.Option(help="downtimeJailTime of StakeHub")] = "2 days",
    felony_jail_time: Annotated[str, typer.Option(help="felonyJailTime of StakeHub")] = "30 days",
    init_voting_delay: Annotated[str,
                                 typer.Option(help="INIT_VOTING_DELAY of BSCGovernor")] = "24 hours / BLOCK_INTERVAL",
    init_voting_period: Annotated[str,
                                  typer.Option(help="INIT_VOTING_PERIOD of BSCGovernor")] = "14 days / BLOCK_INTERVAL",
    init_min_period_after_quorum: Annotated[
        str, typer.Option(help="INIT_MIN_PERIOD_AFTER_QUORUM of BSCGovernor")] = "uint64(1 days / BLOCK_INTERVAL)",
    governor_protector: Annotated[str, typer.Option(help="governorProtector of BSCGovernor")] = "address(0xdEaD)",
    init_minimal_delay: Annotated[str, typer.Option(help="INIT_MINIMAL_DELAY of BSCTimelock")] = "24 hours"
):
    global network, chain_id, hex_chain_id
    network = "dev"
    chain_id = dev_chain_id
    hex_chain_id = convert_chain_id(chain_id)

    try:
        result = subprocess.run(
            [
                "node", "-e",
                "const exportsObj = require(\'./scripts/validators.js\'); console.log(exportsObj.validatorSetBytes.toString(\'hex\'));"
            ],
            capture_output=True,
            text=True,
            check=True,
            cwd=work_dir
        )
        init_validatorset_bytes = result.stdout.strip()[2:]
    except subprocess.CalledProcessError as e:
        raise Exception(f"Error getting init_validatorset_bytes: {e}")

    generate_system()
    generate_cross_chain()
    generate_system_reward()
    generate_slash_indicator(init_felony_slash_scope)
    generate_relayer_hub(whitelist_1, whitelist_2)
    generate_tendermint_light_client(init_consensus_bytes)
    generate_validator_set(init_burn_ratio, init_validatorset_bytes)
    generate_token_recover_portal(source_chain_id)
    generate_stake_hub(
        breathe_block_interval, init_bc_consensus_addresses, init_bc_vote_addresses, unbond_period, downtime_jail_time,
        felony_jail_time, asset_protector
    )
    generate_governor(
        block_interval, init_voting_delay, init_voting_period, init_min_period_after_quorum, governor_protector
    )
    generate_timelock(init_minimal_delay)

    generate_genesis()
    print("Generate genesis of dev environment successfully")


@main.command(help="Recover from the backup")
def recover():
    contracts_dir = os.path.join(work_dir, "contracts")
    for file in os.listdir(contracts_dir):
        if file.endswith(".bak"):
            c_file = file[:-4] + ".sol"
            os.replace(os.path.join(contracts_dir, file), os.path.join(contracts_dir, c_file))
    contracts_dir = os.path.join(contracts_dir, "BC_fusion")
    for file in os.listdir(contracts_dir):
        if file.endswith(".bak"):
            c_file = file[:-4] + ".sol"
            os.replace(os.path.join(contracts_dir, file), os.path.join(contracts_dir, c_file))

    print("Recover from the backup successfully")


@main.command(help="Generate init holders")
def generate_init_holders(
    init_holders: Annotated[str, typer.Argument(help="A list of addresses separated by comma")],
    template_file: str = "./scripts/init_holders.template",
    output_file: str = "./scripts/init_holders.js"
):
    init_holders = init_holders.split(",")
    data = {
        "initHolders": init_holders,
    }

    generate_from_template(data, template_file, output_file)
    print("Generate init holders successfully")


@main.command(help="Generate validators")
def generate_validators(
    file_path: str = "./validators.conf",
    template_file: str = "./scripts/validators.template",
    output_file: str = "./scripts/validators.js"
):
    file_path = os.path.join(work_dir, file_path)
    validators = []

    with open(file_path, "r") as file:
        for line in file:
            vs = line.strip().split(",")
            if len(vs) != 5:
                raise Exception(f"Invalid validator info: {line}")
            validators.append(
                {
                    "consensusAddr": vs[0],
                    "feeAddr": vs[1],
                    "bscFeeAddr": vs[2],
                    "votingPower": vs[3],
                    "bLSPublicKey": vs[4],
                }
            )

    data = {
        "validators": validators,
    }

    generate_from_template(data, template_file, output_file)
    print("Generate validators successfully")


@main.command(help="Generate errors signature")
def generate_error_sig(dir_path: str = "./contracts/BC_fusion"):
    dir_path = os.path.join(work_dir, dir_path)

    annotation_prefix = "    // @notice signature: "
    error_pattern = re.compile(r"^\s{4}(error)\s([a-zA-Z]*\(.*\));\s$")
    annotation_pattern = re.compile(r"^\s{4}(//\s@notice\ssignature:)\s.*\s$")
    for file in os.listdir(dir_path):
        if file.endswith(".sol"):
            file_path = os.path.join(dir_path, file)
            with open(file_path) as f:
                content = f.readlines()
            for i, line in enumerate(content):
                if error_pattern.match(line):
                    error_msg = line[10:-2]
                    # remove variable names
                    match = re.search(r"\((.*?)\)", error_msg)
                    if match and match.group(1) != "":
                        variables = [v.split()[0].strip() for v in match.group(1).split(",")]
                        error_msg = re.sub(r"\((.*?)\)", f"({','.join(variables)})", error_msg)
                    sig = Web3.keccak(text=error_msg)[:4].hex()
                    annotation = annotation_prefix + sig + "\n"
                    # update/insert annotation
                    if annotation_pattern.match(content[i - 1]):
                        content[i - 1] = annotation
                    else:
                        content.insert(i, annotation)
            with open(file_path, "w") as f:
                f.writelines(content)


if __name__ == "__main__":
    main()
