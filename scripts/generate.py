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

    replace_parameter(contract, "uint256 public constant CROSS_CHAIN_KEY_PREFIX", f"0x01{hex_chain_id}00")
    replace_parameter(contract, "uint256 public constant INIT_BATCH_SIZE", f"{init_batch_size}")


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


def generate_slash_indicator(misdemeanor_threshold, felony_threshold, init_felony_slash_scope):
    contract = "SlashIndicator.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "uint256 public constant MISDEMEANOR_THRESHOLD", f"{misdemeanor_threshold}")
    replace_parameter(contract, "uint256 public constant FELONY_THRESHOLD", f"{felony_threshold}")
    replace_parameter(contract, "uint256 public constant INIT_FELONY_SLASH_SCOPE", f"{init_felony_slash_scope}")

    if network == "dev":
        insert(contract, "alreadyInit = true;", "\t\tenableMaliciousVoteSlash = true;")


def generate_stake_hub(
    breathe_block_interval, init_bc_consensus_addresses, init_bc_vote_addresses, max_elected_validators, unbond_period,
    downtime_jail_time, felony_jail_time, stake_hub_protector
):
    contract = "BC_fusion/StakeHub.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "uint256 public constant BREATHE_BLOCK_INTERVAL", f"{breathe_block_interval}")
    replace_parameter(contract, "bytes private constant INIT_BC_CONSENSUS_ADDRESSES", f"{init_bc_consensus_addresses}")
    replace_parameter(contract, "bytes private constant INIT_BC_VOTE_ADDRESSES", f"{init_bc_vote_addresses}")

    replace(contract, r"maxElectedValidators = .*;", f"maxElectedValidators = {max_elected_validators};")
    replace(contract, r"unbondPeriod = .*;", f"unbondPeriod = {unbond_period};")
    replace(contract, r"downtimeJailTime = .*;", f"downtimeJailTime = {downtime_jail_time};")
    replace(contract, r"felonyJailTime = .*;", f"felonyJailTime = {felony_jail_time};")
    replace(contract, r"__Protectable_init_unchained\(.*\);", f"__Protectable_init_unchained({stake_hub_protector});")


def generate_governor(
    block_interval, init_voting_delay, init_voting_period, init_proposal_threshold, init_quorum_numerator,
    propose_start_threshold, init_min_period_after_quorum, governor_protector
):
    contract = "BC_fusion/BSCGovernor.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "uint256 private constant BLOCK_INTERVAL", f"{block_interval}")
    replace_parameter(contract, "uint256 private constant INIT_VOTING_DELAY", f"{init_voting_delay}")
    replace_parameter(contract, "uint256 private constant INIT_VOTING_PERIOD", f"{init_voting_period}")
    replace_parameter(contract, "uint256 private constant INIT_PROPOSAL_THRESHOLD", f"{init_proposal_threshold}")
    replace_parameter(contract, "uint256 private constant INIT_QUORUM_NUMERATOR", f"{init_quorum_numerator}")
    replace_parameter(
        contract, "uint256 private constant PROPOSE_START_GOVBNB_SUPPLY_THRESHOLD", f"{propose_start_threshold}"
    )
    replace_parameter(
        contract, "uint64 private constant INIT_MIN_PERIOD_AFTER_QUORUM", f"{init_min_period_after_quorum}"
    )
    replace(contract, r"__Protectable_init_unchained\(.*\);", f"__Protectable_init_unchained({governor_protector});")


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

    replace_parameter(contract, "uint16 public constant bscChainID", f"0x{hex_chain_id}")


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
        contract, "bytes public constant INIT_CONSENSUS_STATE_BYTES", f"hex\"{init_consensus_state_bytes}\""
    )
    replace_parameter(
        contract, "uint256 public constant INIT_REWARD_FOR_VALIDATOR_SER_CHANGE",
        f"{init_reward_for_validator_ser_change}"
    )


def generate_token_hub(lock_period_for_token_recover):
    contract = "TokenHub.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(
        contract, "uint256 public constant LOCK_PERIOD_FOR_TOKEN_RECOVER", f"{lock_period_for_token_recover}"
    )


def generate_token_recover_portal(source_chain_id, token_recover_portal_protector):
    contract = "BC_fusion/TokenRecoverPortal.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "string public constant SOURCE_CHAIN_ID", f"\"{source_chain_id}\"")
    replace(
        contract, r"__Protectable_init_unchained\(.*\);",
        f"__Protectable_init_unchained({token_recover_portal_protector});"
    )


def generate_validator_set(init_validator_set_bytes, init_burn_ratio, epoch):
    contract = "BSCValidatorSet.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    replace_parameter(contract, "uint256 public constant INIT_BURN_RATIO", f"{init_burn_ratio}")
    replace_parameter(contract, "bytes public constant INIT_VALIDATORSET_BYTES", f"hex\"{init_validator_set_bytes}\"")
    replace_parameter(contract, "uint256 public constant EPOCH", f"{epoch}")

    if network == "dev":
        insert(
            contract, r"for \(uint256 i; i < validatorSetPkg\.validatorSet\.length; \+\+i\)",
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
        replace(
            contract,
            r"handleSynPackage\(\s*uint8,\s*bytes calldata msgBytes\s*\) external override onlyInit onlyCrossChainContract initValidatorExtraSet",
            "handleSynPackage(uint8, bytes calldata msgBytes) external override onlyInit initValidatorExtraSet"
        )


def generate_gov_hub():
    contract = "GovHub.sol"
    backup_file(
        os.path.join(work_dir, "contracts", contract), os.path.join(work_dir, "contracts", contract[:-4] + ".bak")
    )

    if network == "dev":
        replace(
            contract, r"handleSynPackage\(\s*uint8,\s*bytes calldata msgBytes\s*\) external override onlyCrossChainContract",
            "handleSynPackage(uint8, bytes calldata msgBytes) external override"
        )


def generate_genesis():
    subprocess.run(["forge", "build"], cwd=work_dir, check=True)
    subprocess.run(["node", "scripts/generate-genesis.js", "--chainId", f"{chain_id}"], cwd=work_dir, check=True)


@main.command(help="Generate contracts for BSC mainnet")
def mainnet():
    global network, chain_id, hex_chain_id
    network = "mainnet"
    chain_id = 56
    hex_chain_id = convert_chain_id(chain_id)

    # mainnet init data
    init_consensus_bytes = "42696e616e63652d436861696e2d5469677269730000000000000000000000000000000006915167cedaf7bbf7df47d932fdda630527ee648562cf3e52c5e5f46156a3a971a4ceb443c53a50d8653ef8cf1e5716da68120fb51b636dc6d111ec3277b098ecd42d49d3769d8a1f78b4c17a965f7a30d4181fabbd1f969f46d3c8e83b5ad4845421d8000000e8d4a510002ba4e81542f437b7ae1f8a35ddb233c789a8dc22734377d9b6d63af1ca403b61000000e8d4a51000df8da8c5abfdb38595391308bb71e5a1e0aabdc1d0cf38315d50d6be939b2606000000e8d4a51000b6619edca4143484800281d698b70c935e9152ad57b31d85c05f2f79f64b39f3000000e8d4a510009446d14ad86c8d2d74780b0847110001a1c2e252eedfea4753ebbbfce3a22f52000000e8d4a510000353c639f80cc8015944436dab1032245d44f912edc31ef668ff9f4a45cd0599000000e8d4a51000e81d3797e0544c3a718e1f05f0fb782212e248e784c1a851be87e77ae0db230e000000e8d4a510005e3fcda30bd19d45c4b73688da35e7da1fce7c6859b2c1f20ed5202d24144e3e000000e8d4a51000b06a59a2d75bf5d014fce7c999b5e71e7a960870f725847d4ba3235baeaa08ef000000e8d4a510000c910e2fe650e4e01406b3310b489fb60a84bc3ff5c5bee3a56d5898b6a8af32000000e8d4a5100071f2d7b8ec1c8b99a653429b0118cd201f794f409d0fea4d65b1b662f2b00063000000e8d4a51000"
    init_burn_ratio = "1000"
    init_validator_set_bytes = "f905ec80f905e8f846942a7cdd959bfe8d9487b2a43b33565295a698f7e294b6a7edd747c0554875d3fc531d19ba1497992c5e941ff80f3f7f110ffd8920a3ac38fdef318fe94a3f86048c27395000f846946488aa4d1955ee33403f8ccb1d4de5fb97c7ade294220f003d8bdfaadf52aa1e55ae4cc485e6794875941a87e90e440a39c99aa9cb5cea0ad6a3f0b2407b86048c27395000f846949ef9f4360c606c7ab4db26b016007d3ad0ab86a0946103af86a874b705854033438383c82575f25bc29418e2db06cbff3e3c5f856410a1838649e760175786048c27395000f84694ee01c3b1283aa067c58eab4709f85e99d46de5fe94ee4b9bfb1871c64e2bcabb1dc382dc8b7c4218a29415904ab26ab0e99d70b51c220ccdcccabee6e29786048c27395000f84694685b1ded8013785d6623cc18d214320b6bb6475994a20ef4e5e4e7e36258dbf51f4d905114cb1b34bc9413e39085dc88704f4394d35209a02b1a9520320c86048c27395000f8469478f3adfc719c99674c072166708589033e2d9afe9448a30d5eaa7b64492a160f139e2da2800ec3834e94055838358c29edf4dcc1ba1985ad58aedbb6be2b86048c27395000f84694c2be4ec20253b8642161bc3f444f53679c1f3d479466f50c616d737e60d7ca6311ff0d9c434197898a94d1d678a2506eeaa365056fe565df8bc8659f28b086048c27395000f846942f7be8361c80a4c1e7e9aaf001d0877f1cfde218945f93992ac37f3e61db2ef8a587a436a161fd210b94ecbc4fb1a97861344dad0867ca3cba2b860411f086048c27395000f84694ce2fd7544e0b2cc94692d4a704debef7bcb613289444abc67b4b2fba283c582387f54c9cba7c34bafa948acc2ab395ded08bb75ce85bf0f95ad2abc51ad586048c27395000f84694b8f7166496996a7da21cf1f1b04d9b3e26a3d077946770572763289aac606e4f327c2f6cc1aa3b3e3b94882d745ed97d4422ca8da1c22ec49d880c4c097286048c27395000f846942d4c407bbe49438ed859fe965b140dcf1aab71a9943ad0939e120f33518fbba04631afe7a3ed6327b194b2bbb170ca4e499a2b0f3cc85ebfa6e8c4dfcbea86048c27395000f846946bbad7cf34b5fa511d8e963dbba288b1960e75d694853b0f6c324d1f4e76c8266942337ac1b0af1a229442498946a51ca5924552ead6fc2af08b94fcba648601d1a94a2000f846944430b3230294d12c6ab2aac5c2cd68e80b16b581947b107f4976a252a6939b771202c28e64e03f52d694795811a7f214084116949fc4f53cedbf189eeab28601d1a94a2000f84694ea0a6e3c511bbd10f4519ece37dc24887e11b55d946811ca77acfb221a49393c193f3a22db829fcc8e9464feb7c04830dd9ace164fc5c52b3f5a29e5018a8601d1a94a2000f846947ae2f5b9e386cd1b50a4550696d957cb4900f03a94e83bcc5077e6b873995c24bac871b5ad856047e19464e48d4057a90b233e026c1041e6012ada897fe88601d1a94a2000f8469482012708dafc9e1b880fd083b32182b869be8e09948e5adc73a2d233a1b496ed3115464dd6c7b887509428b383d324bc9a37f4e276190796ba5a8947f5ed8601d1a94a2000f8469422b81f8e175ffde54d797fe11eb03f9e3bf75f1d94a1c3ef7ca38d8ba80cce3bfc53ebd2903ed21658942767f7447f7b9b70313d4147b795414aecea54718601d1a94a2000f8469468bf0b8b6fb4e317a0f9d6f03eaf8ce6675bc60d94675cfe570b7902623f47e7f59c9664b5f5065dcf94d84f0d2e50bcf00f2fc476e1c57f5ca2d57f625b8601d1a94a2000f846948c4d90829ce8f72d0163c1d5cf348a862d5506309485c42a7b34309bee2ed6a235f86d16f059deec5894cc2cedc53f0fa6d376336efb67e43d167169f3b78601d1a94a2000f8469435e7a025f4da968de7e4d7e4004197917f4070f194b1182abaeeb3b4d8eba7e6a4162eac7ace23d57394c4fd0d870da52e73de2dd8ded19fe3d26f43a1138601d1a94a2000f84694d6caa02bbebaebb5d7e581e4b66559e635f805ff94c07335cf083c1c46a487f0325769d88e163b653694efaff03b42e41f953a925fc43720e45fb61a19938601d1a94a2000"
    whitelist_1 = "0xb005741528b86F5952469d80A8614591E3c5B632"
    whitelist_2 = "0x446AA6E0DC65690403dF3F127750da1322941F3e"
    source_chain_id = "Binance-Chain-Tigris"

    epoch = "200"
    block_interval = "3 seconds"
    breathe_block_interval = "1 days"
    max_elected_validators = "45"
    unbond_period = "7 days"
    downtime_jail_time = "2 days"
    felony_jail_time = "30 days"
    init_felony_slash_scope = "28800"
    misdemeanor_threshold = "50"
    felony_threshold = "150"
    init_voting_delay = "0 hours / BLOCK_INTERVAL"
    init_voting_period = "7 days / BLOCK_INTERVAL"
    init_proposal_threshold = "200 ether"
    init_quorum_numerator = "10"
    propose_start_threshold = "10_000_000 ether"
    init_min_period_after_quorum = "uint64(1 days / BLOCK_INTERVAL)"
    init_minimal_delay = "24 hours"
    lock_period_for_token_recover = "7 days"

    init_bc_consensus_addresses = 'hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000038000000000000000000000000295e26495cef6f69dfa69911d9d8e4f3bbadb89b00000000000000000000000072b61c6014342d914470ec7ac2975be345796c2b0000000000000000000000002465176c461afb316ebc773c61faee85a6515daa0000000000000000000000007ae2f5b9e386cd1b50a4550696d957cb4900f03a000000000000000000000000b4dd66d7c2c7e57f628210187192fb89d4b99dd4000000000000000000000000e9ae3261a475a27bb1028f140bc2a7c843318afd000000000000000000000000ee226379db83cffc681495730c11fdde79ba4c0c0000000000000000000000003f349bbafec1551819b8be1efea2fc46ca749aa10000000000000000000000008b6c8fd93d6f4cea42bbb345dbc6f0dfdb5bec73000000000000000000000000ef0274e31810c9df02f98fafde0f841f4e66a1cd000000000000000000000000a6f79b60359f141df90a0c745125b131caaffd12000000000000000000000000e2d3a739effcd3a99387d015e260eefac72ebea100000000000000000000000061dd481a114a2e761c554b641742c973867899d3000000000000000000000000cc8e6d00c17eb431350c6c50d8b8f05176b90b11000000000000000000000000ea0a6e3c511bbd10f4519ece37dc24887e11b55d0000000000000000000000002d4c407bbe49438ed859fe965b140dcf1aab71a9000000000000000000000000685b1ded8013785d6623cc18d214320b6bb64759000000000000000000000000d1d6bf74282782b0b3eb1413c901d6ecf02e8e2800000000000000000000000070f657164e5b75689b64b7fd1fa275f334f28e18000000000000000000000000be807dddb074639cd9fa61b47676c064fc50d62c000000000000000000000000b218c5d6af1f979ac42bc68d98a5a0d796c6ab010000000000000000000000009f8ccdafcc39f3c7d6ebf637c9151673cbc36b88000000000000000000000000d93dbfb27e027f5e9e6da52b9e1c413ce35adc11000000000000000000000000ce2fd7544e0b2cc94692d4a704debef7bcb613280000000000000000000000000bac492386862ad3df4b666bc096b0505bb694da000000000000000000000000733fda7714a05960b7536330be4dbb135bef0ed600000000000000000000000035ebb5849518aff370ca25e19e1072cc1a9fabca000000000000000000000000ebe0b55ad7bb78309180cada12427d120fdbcc3a0000000000000000000000006488aa4d1955ee33403f8ccb1d4de5fb97c7ade20000000000000000000000004396e28197653d0c244d95f8c1e57da902a72b4e000000000000000000000000702be18040aa2a9b1af9219941469f1a435854fc00000000000000000000000012d810c13e42811e9907c02e02d1fad46cfa18ba0000000000000000000000002a7cdd959bfe8d9487b2a43b33565295a698f7e2000000000000000000000000b8f7166496996a7da21cf1f1b04d9b3e26a3d0770000000000000000000000009bb832254baf4e8b4cc26bd2b52b31389b56e98b0000000000000000000000004430b3230294d12c6ab2aac5c2cd68e80b16b581000000000000000000000000c2be4ec20253b8642161bc3f444f53679c1f3d47000000000000000000000000ee01c3b1283aa067c58eab4709f85e99d46de5fe0000000000000000000000009ef9f4360c606c7ab4db26b016007d3ad0ab86a00000000000000000000000002f7be8361c80a4c1e7e9aaf001d0877f1cfde21800000000000000000000000035e7a025f4da968de7e4d7e4004197917f4070f1000000000000000000000000d6caa02bbebaebb5d7e581e4b66559e635f805ff0000000000000000000000008c4d90829ce8f72d0163c1d5cf348a862d55063000000000000000000000000068bf0b8b6fb4e317a0f9d6f03eaf8ce6675bc60d00000000000000000000000082012708dafc9e1b880fd083b32182b869be8e090000000000000000000000006bbad7cf34b5fa511d8e963dbba288b1960e75d600000000000000000000000022b81f8e175ffde54d797fe11eb03f9e3bf75f1d00000000000000000000000078f3adfc719c99674c072166708589033e2d9afe00000000000000000000000029a97c6effb8a411dabc6adeefaa84f5067c8bbe000000000000000000000000aacf6a8119f7e11623b5a43da638e91f669a130f0000000000000000000000002b3a6c089311b478bf629c29d790a7a6db3fc1b9000000000000000000000000fe6e72b223f6d6cf4edc6bff92f30e84b8258249000000000000000000000000a6503279e8b5c7bb5cf4defd3ec8abf3e009a80b0000000000000000000000004ee63a09170c3f2207aeca56134fc2bee1b28e3c000000000000000000000000ac0e15a038eedfc68ba3c35c73fed5be4a07afb500000000000000000000000069c77a677c40c7fbea129d4b171a39b7a8ddabfa"'
    init_bc_vote_addresses = 'hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000044000000000000000000000000000000000000000000000000000000000000004a00000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000056000000000000000000000000000000000000000000000000000000000000005c00000000000000000000000000000000000000000000000000000000000000620000000000000000000000000000000000000000000000000000000000000068000000000000000000000000000000000000000000000000000000000000006e0000000000000000000000000000000000000000000000000000000000000074000000000000000000000000000000000000000000000000000000000000007a00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000086000000000000000000000000000000000000000000000000000000000000008c00000000000000000000000000000000000000000000000000000000000000920000000000000000000000000000000000000000000000000000000000000098000000000000000000000000000000000000000000000000000000000000009e00000000000000000000000000000000000000000000000000000000000000a400000000000000000000000000000000000000000000000000000000000000aa00000000000000000000000000000000000000000000000000000000000000b000000000000000000000000000000000000000000000000000000000000000b600000000000000000000000000000000000000000000000000000000000000bc00000000000000000000000000000000000000000000000000000000000000c200000000000000000000000000000000000000000000000000000000000000c800000000000000000000000000000000000000000000000000000000000000ce00000000000000000000000000000000000000000000000000000000000000d400000000000000000000000000000000000000000000000000000000000000da00000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000e600000000000000000000000000000000000000000000000000000000000000ec00000000000000000000000000000000000000000000000000000000000000f200000000000000000000000000000000000000000000000000000000000000f800000000000000000000000000000000000000000000000000000000000000fe0000000000000000000000000000000000000000000000000000000000000104000000000000000000000000000000000000000000000000000000000000010a00000000000000000000000000000000000000000000000000000000000000030977cf58294f7239d515e15b24cfeb82494056cf691eaf729b165f32c9757c429dba5051155903067e56ebe3698678e9100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003081db0422a5fd08e40db1fc2368d2245e4b18b1d0b85c921aaaafd2e341760e29fc613edd39f71254614e2055c3287a510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308a923564c6ffd37fb2fe9f118ef88092e8762c7addb526ab7eb1e772baef85181f892c731be0c1891a50e6b06262c816000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b84f83ff2df44193496793b847f64e9d6db1b3953682bb95edd096eb1e69bbd357c200992ca78050d0cbe180cfaa018e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b0de8472be0308918c8bdb369bf5a67525210daffa053c52224c1d2ef4f5b38e4ecfcd06a1cc51c39c3a7dccfcb6b507000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030ae7bc6faa3f0cc3e6093b633fd7ee4f86970926958d0b7ec80437f936acf212b78f0cd095f4565fff144fd458d233a5b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003084248a459464eec1a21e7fc7b71a053d9644e9bb8da4853b8f872cd7c1d6b324bf1922829830646ceadfb658d3de009a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030a8a257074e82b881cfa06ef3eb4efeca060c2531359abd0eab8af1e3edfa2025fca464ac9c3fd123f6c24a0d7886948500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003098cbf822e4bc29f1701ac0350a3d042cd0756e9f74822c6481773ceb000641c51b870a996fe0f6a844510b1061f38cd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b772e180fbf38a051c97dabc8aaa0126a233a9e828cdafcc7422c4bb1f4030a56ba364c54103f26bad91508b5220b741000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030956c470ddff48cb49300200b5f83497f3a3ccb3aeb83c5edd9818569038e61d197184f4aa6939ea5e9911e3e98ac6d210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308a80967d39e406a0a9642d41e9007a27fc1150a267d143a9f786cd2b5eecbdcc4036273705225b956d5e2f8f5eb95d25000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b3a3d4feb825ae9702711566df5dbf38e82add4dd1b573b95d2466fa6501ccb81e9d26a352b96150ccbf7b697fd0a419000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b2d4c6283c44a1c7bd503aaba7666e9f0c830e0ff016c1c750a5e48757a713d0836b1cabfd5c281b1de3b77d1c19218300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003093c1f7f6929d1fe2a17b4e14614ef9fc5bdc713d6631d675403fbeefac55611bf612700b1b65f4744861b80b0f7d6ab00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308a60f82a7bcf74b4cb053b9bfe83d0ed02a84ebb10865dfdd8e26e7535c43a1cccd268e860f502216b379dfc9971d358000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030939e8fb41b682372335be8070199ad3e8621d1743bcac4cc9d8f0f6e10f41e56461385c8eb5daac804fe3f2bca6ce73900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003096a26afa1295da81418593bd12814463d9f6e45c36a0e47eb4cd3e5b6af29c41e2a3a5636430155a466e216585af3ba7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b1f2c71577def3144fabeb75a8a1c8cb5b51d1d1b4a05eec67988b8685008baa17459ec425dbaebc852f496dc92196cd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b659ad0fbd9f515893fdd740b29ba0772dbde9b4635921dd91bd2963a0fc855e31f6338f45b211c4e9dedb7f2eb09de70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308819ec5ec3e97e1f03bbb4bb6055c7a5feac8f4f259df58349a32bb5cb377e2cb1f362b77f1dd398cfd3e9dba46138c3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b313f9cba57c63a84edb4079140e6dbd7829e5023c9532fce57e9fe602400a2953f4bf7dab66cca16e97be95d4de7044000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b64abe25614c9cfd32e456b4d521f29c8357f4af4606978296c9be93494072ac05fa86e3d27cc8d66e65000f8ba33fbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b0bec348681af766751cb839576e9c515a09c8bffa30a46296ccc56612490eb480d03bf948e10005bbcc0421f90b3d4e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b0245c33bc556cfeb013cd3643b30dbdef6df61a0be3ba00cae104b3c587083852e28f8911689c7033f7021a8a1774c9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030a7f3e2c0b4b16ad183c473bafe30a36e39fa4a143657e229cd23c77f8fbc8e4e4e241695dd3d248d1e51521eee6619140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308fdf49777b22f927d460fa3fcdd7f2ba0cf200634a3dfb5197d7359f2f88aaf496ef8c93a065de0f376d164ff2b6db9a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308ab17a9148339ef40aed8c177379c4db0bb5efc6f5c57a5d1a6b58b84d4b562e227196c79bda9a136830ed0c09f378130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308dd20979bd63c14df617a6939c3a334798149151577dd3f1fadb2bd1c1b496bf84c25c879da5f0f9dfdb88c6dd17b1e6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b679cbab0276ac30ff5f198e5e1dedf6b84959129f70fe7a07fcdf13444ba45b5dbaa7b1f650adf8b0acbecd04e2675b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308974616fe8ab950a3cded19b1d16ff49c97bf5af65154b3b097d5523eb213f3d35fc5c57e7276c7f2d83be87ebfdcdf9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030ab764a39ff81dad720d5691b852898041a3842e09ecbac8025812d51b32223d8420e6ae51a01582220a10f7722de67c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000309025b6715c8eaabac0bfccdb2f25d651c9b69b0a184011a4a486b0b2080319d2396e7ca337f2abdf01548b2de1b3ba06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b2317f59d86abfaf690850223d90e9e7593d91a29331dfc2f84d5adecc75fc39ecab4632c1b4400a3dd1e1298835bcca00000000000000000000000000000000"'
    stake_hub_protector = "0x08E68Ec70FA3b629784fDB28887e206ce8561E08"
    governor_protector = "0x08E68Ec70FA3b629784fDB28887e206ce8561E08"
    token_recover_portal_protector = "0x08E68Ec70FA3b629784fDB28887e206ce8561E08"

    generate_system()
    generate_cross_chain()
    generate_system_reward()
    generate_gov_hub()
    generate_slash_indicator(misdemeanor_threshold, felony_threshold, init_felony_slash_scope)
    generate_relayer_hub(whitelist_1, whitelist_2)
    generate_tendermint_light_client(init_consensus_bytes)
    generate_validator_set(init_validator_set_bytes, init_burn_ratio, epoch)
    generate_token_recover_portal(source_chain_id, token_recover_portal_protector)
    generate_stake_hub(
        breathe_block_interval, init_bc_consensus_addresses, init_bc_vote_addresses, max_elected_validators,
        unbond_period, downtime_jail_time, felony_jail_time, stake_hub_protector
    )
    generate_governor(
        block_interval, init_voting_delay, init_voting_period, init_proposal_threshold, init_quorum_numerator,
        propose_start_threshold, init_min_period_after_quorum, governor_protector
    )
    generate_timelock(init_minimal_delay)
    generate_token_hub(lock_period_for_token_recover)

    generate_genesis()
    print("Generate genesis of mainnet successfully")


@main.command(help="Generate contracts for BSC testnet")
def testnet():
    global network, chain_id, hex_chain_id
    network = "testnet"
    chain_id = 97
    hex_chain_id = convert_chain_id(chain_id)

    # testnet init data
    init_consensus_bytes = "42696e616e63652d436861696e2d47616e67657300000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000aea1ac326886b992a991d21a6eb155f41b77867cbf659e78f31d89d8205122a84d1be64f0e9a466c2e66a53433928192783e29f8fa21beb2133499b5ef770f60000000e8d4a5100099308aa365c40554bc89982af505d85da95251445d5dd4a9bb37dd2584fd92d3000000e8d4a5100001776920ff0b0f38d78cf95c033c21adf7045785114e392a7544179652e0a612000000e8d4a51000"
    init_burn_ratio = "1000"
    init_validator_set_bytes = "f901a880f901a4f844941284214b9b9c85549ab3d2b972df0deef66ac2c9946ddf42a51534fc98d0c0a3b42c963cace8441ddf946ddf42a51534fc98d0c0a3b42c963cace8441ddf8410000000f84494a2959d3f95eae5dc7d70144ce1b73b403b7eb6e0948081ef03f1d9e0bb4a5bf38f16285c879299f07f948081ef03f1d9e0bb4a5bf38f16285c879299f07f8410000000f8449435552c16704d214347f29fa77f77da6d75d7c75294dc4973e838e3949c77aced16ac2315dc2d7ab11194dc4973e838e3949c77aced16ac2315dc2d7ab1118410000000f84494980a75ecd1309ea12fa2ed87a8744fbfc9b863d594cc6ac05c95a99c1f7b5f88de0e3486c82293b27094cc6ac05c95a99c1f7b5f88de0e3486c82293b2708410000000f84494f474cf03cceff28abc65c9cbae594f725c80e12d94e61a183325a18a173319dd8e19c8d069459e217594e61a183325a18a173319dd8e19c8d069459e21758410000000f84494b71b214cb885500844365e95cd9942c7276e7fd894d22ca3ba2141d23adab65ce4940eb7665ea2b6a794d22ca3ba2141d23adab65ce4940eb7665ea2b6a78410000000"
    whitelist_1 = "0x9fB29AAc15b9A4B7F17c3385939b007540f4d791"
    whitelist_2 = "0x37B8516a0F88E65D677229b402ec6C1e0E333004"
    source_chain_id = "Binance-Chain-Ganges"

    epoch = "200"
    block_interval = "3 seconds"
    breathe_block_interval = "1 days"
    max_elected_validators = "9"
    unbond_period = "7 days"
    downtime_jail_time = "2 days"
    felony_jail_time = "5 days"
    init_felony_slash_scope = "28800"
    misdemeanor_threshold = "50"
    felony_threshold = "150"
    init_voting_delay = "0 hours / BLOCK_INTERVAL"
    init_voting_period = "1 days / BLOCK_INTERVAL"
    init_proposal_threshold = "100 ether"
    init_quorum_numerator = "10"
    propose_start_threshold = "10_000_000 ether"
    init_min_period_after_quorum = "uint64(1 hours / BLOCK_INTERVAL)"
    init_minimal_delay = "6 hours"
    lock_period_for_token_recover = "1 days"

    init_bc_consensus_addresses = 'hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000001284214b9b9c85549ab3d2b972df0deef66ac2c9000000000000000000000000a2959d3f95eae5dc7d70144ce1b73b403b7eb6e0000000000000000000000000980a75ecd1309ea12fa2ed87a8744fbfc9b863d5000000000000000000000000b71b214cb885500844365e95cd9942c7276e7fd800000000000000000000000035552c16704d214347f29fa77f77da6d75d7c752000000000000000000000000f474cf03cceff28abc65c9cbae594f725c80e12d00000000000000000000000096c5d20b2a975c050e4220be276ace4892f4b41a00000000000000000000000047788386d0ed6c748e03a53160b4b30ed3748cc5000000000000000000000000bdfbc016c1bd481f5d8ca6f754f4b200a7ed66ce000000000000000000000000372e4887005ec21a5aff9ff62eda9e7713e3643700000000000000000000000055c968cf3430f3ba0534ef49ff4b3fbc9086c7ce000000000000000000000000136bd6343049c9690569db79dcd9208a57d342ad000000000000000000000000977ecef7de795cd248d77fd0d080ce3a35dec013000000000000000000000000b334ced91dff560bc9b5b3c30ae613bf335f1813"'
    init_bc_vote_addresses = 'hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000024000000000000000000000000000000000000000000000000000000000000002a000000000000000000000000000000000000000000000000000000000000000308e82934ca974fdcd97f3309de967d3c9c43fa711a8d673af5d75465844bf8969c8d1948d903748ac7b8b1720fa64e50c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b973c2d38487e58fd6e145491b110080fb14ac915a0411fc78f19e09a399ddee0d20c63a75d8f930f1694544ad2dc01b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003089037a9ace3b590165ea1c0c5ac72bf600b7c88c1e435f41932c1132aae1bfa0bb68e46b96ccb12c3415e4d82af717d8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030a2750ec6dded3dcdc2f351782310b0eadc077db59abca0f0cd26776e2e7acb9f3bce40b1fa5221fd1561226c6263cc5f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b742ad4855bae330426b823e742da31f816cc83bc16d69a9134be0cfb4a1d17ec34f1b5b32d5c20440b8536b1e88f0f200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003096c9b86c3400e529bfe184056e257c07940bb664636f689e8d2027c834681f8f878b73445261034e946bb2d901b4b87800000000000000000000000000000000"'
    stake_hub_protector = "0x30151DA466EC8AB345BEF3d6983023E050fb0673"
    governor_protector = "0x30151DA466EC8AB345BEF3d6983023E050fb0673"
    token_recover_portal_protector = "0x30151DA466EC8AB345BEF3d6983023E050fb0673"

    generate_system()
    generate_cross_chain()
    generate_system_reward()
    generate_gov_hub()
    generate_slash_indicator(misdemeanor_threshold, felony_threshold, init_felony_slash_scope)
    generate_relayer_hub(whitelist_1, whitelist_2)
    generate_tendermint_light_client(init_consensus_bytes)
    generate_validator_set(init_validator_set_bytes, init_burn_ratio, epoch)
    generate_token_recover_portal(source_chain_id, token_recover_portal_protector)
    generate_stake_hub(
        breathe_block_interval, init_bc_consensus_addresses, init_bc_vote_addresses, max_elected_validators,
        unbond_period, downtime_jail_time, felony_jail_time, stake_hub_protector
    )
    generate_governor(
        block_interval, init_voting_delay, init_voting_period, init_proposal_threshold, init_quorum_numerator,
        propose_start_threshold, init_min_period_after_quorum, governor_protector
    )
    generate_timelock(init_minimal_delay)
    generate_token_hub(lock_period_for_token_recover)

    generate_genesis()
    print("Generate genesis of testnet successfully")


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
    init_bc_consensus_addresses:
    str = 'hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000"',
    init_bc_vote_addresses:
    str = 'hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000"',
    stake_hub_protector: Annotated[str, typer.Option(help="assetProtector of StakeHub")] = "address(0xdEaD)",
    governor_protector: Annotated[str, typer.Option(help="governorProtector of BSCGovernor")] = "address(0xdEaD)",
    token_recover_portal_protector: Annotated[str,
                                              typer.Option(help="protector of TokenRecoverPortal")] = "address(0xdEaD)",
    epoch: str = "200",
    block_interval: Annotated[str, typer.Option(help="block interval of Parlia")] = "3 seconds",
    breathe_block_interval: Annotated[str, typer.Option(help="breath block interval of Parlia")] = "1 days",
    max_elected_validators: Annotated[str, typer.Option(help="maxElectedValidators of StakeHub")] = "45",
    unbond_period: Annotated[str, typer.Option(help="unbondPeriod of StakeHub")] = "7 days",
    downtime_jail_time: Annotated[str, typer.Option(help="downtimeJailTime of StakeHub")] = "2 days",
    felony_jail_time: Annotated[str, typer.Option(help="felonyJailTime of StakeHub")] = "30 days",
    init_felony_slash_scope: str = "28800",
    misdemeanor_threshold: str = "50",
    felony_threshold: str = "150",
    init_voting_delay: Annotated[str,
                                 typer.Option(help="INIT_VOTING_DELAY of BSCGovernor")] = "0 hours / BLOCK_INTERVAL",
    init_voting_period: Annotated[str,
                                  typer.Option(help="INIT_VOTING_PERIOD of BSCGovernor")] = "7 days / BLOCK_INTERVAL",
    init_proposal_threshold: Annotated[str, typer.Option(help="INIT_PROPOSAL_THRESHOLD of BSCGovernor")] = "200 ether",
    init_quorum_numerator: Annotated[str, typer.Option(help="INIT_QUORUM_NUMERATOR of BSCGovernor")] = "10",
    propose_start_threshold: Annotated[
        str, typer.Option(help="PROPOSE_START_GOVBNB_SUPPLY_THRESHOLD of BSCGovernor")] = "10_000_000 ether",
    init_min_period_after_quorum: Annotated[
        str, typer.Option(help="INIT_MIN_PERIOD_AFTER_QUORUM of BSCGovernor")] = "uint64(1 days / BLOCK_INTERVAL)",
    init_minimal_delay: Annotated[str, typer.Option(help="INIT_MINIMAL_DELAY of BSCTimelock")] = "24 hours",
    lock_period_for_token_recover: Annotated[str,
                                             typer.Option(help="LOCK_PERIOD_FOR_TOKEN_RECOVER of TokenHub")] = "7 days",
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
        init_validator_set_bytes = result.stdout.strip()[2:]
    except subprocess.CalledProcessError as e:
        raise Exception(f"Error getting init_validatorset_bytes: {e}")

    generate_system()
    generate_cross_chain()
    generate_system_reward()
    generate_gov_hub()
    generate_slash_indicator(misdemeanor_threshold, felony_threshold, init_felony_slash_scope)
    generate_relayer_hub(whitelist_1, whitelist_2)
    generate_tendermint_light_client(init_consensus_bytes)
    generate_validator_set(init_validator_set_bytes, init_burn_ratio, epoch)
    generate_token_recover_portal(source_chain_id, token_recover_portal_protector)
    generate_stake_hub(
        breathe_block_interval, init_bc_consensus_addresses, init_bc_vote_addresses, max_elected_validators,
        unbond_period, downtime_jail_time, felony_jail_time, stake_hub_protector
    )
    generate_governor(
        block_interval, init_voting_delay, init_voting_period, init_proposal_threshold, init_quorum_numerator,
        propose_start_threshold, init_min_period_after_quorum, governor_protector
    )
    generate_timelock(init_minimal_delay)
    generate_token_hub(lock_period_for_token_recover)

    generate_genesis()
    print("Generate genesis of dev environment successfully")


@main.command(help="Recover from the backup")
def recover():
    contracts_dir = os.path.join(work_dir, "contracts")
    for file in os.listdir(contracts_dir):
        if file.endswith(".bak"):
            c_file = file[:-4] + ".sol"
            shutil.copyfile(os.path.join(contracts_dir, file), os.path.join(contracts_dir, c_file))
            os.remove(os.path.join(contracts_dir, file))

    contracts_dir = os.path.join(contracts_dir, "BC_fusion")
    for file in os.listdir(contracts_dir):
        if file.endswith(".bak"):
            c_file = file[:-4] + ".sol"
            shutil.copyfile(os.path.join(contracts_dir, file), os.path.join(contracts_dir, c_file))
            os.remove(os.path.join(contracts_dir, file))

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
