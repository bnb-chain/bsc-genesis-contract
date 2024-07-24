// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./System.sol";
import "./extension/Protectable.sol";
import "./interface/IBSCValidatorSet.sol";
import "./interface/ICrossChain.sol";
import "./interface/IGovToken.sol";
import "./interface/IStakeCredit.sol";
import "./interface/ITokenHub.sol";
import "./lib/RLPDecode.sol";
import "./lib/Utils.sol";

contract StakeHub is System, Initializable, Protectable {
    using RLPDecode for *;
    using Utils for string;
    using Utils for bytes;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*----------------- constants -----------------*/
    uint256 private constant BLS_PUBKEY_LENGTH = 48;
    uint256 private constant BLS_SIG_LENGTH = 96;

    address public constant DEAD_ADDRESS = address(0xdEaD);
    uint256 public constant LOCK_AMOUNT = 1 ether;
    uint256 public constant REDELEGATE_FEE_RATE_BASE = 100000; // 100%

    uint256 public constant BREATHE_BLOCK_INTERVAL = 1 days;

    bytes private constant INIT_BC_CONSENSUS_ADDRESSES =
        hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000038000000000000000000000000295e26495cef6f69dfa69911d9d8e4f3bbadb89b00000000000000000000000072b61c6014342d914470ec7ac2975be345796c2b0000000000000000000000002465176c461afb316ebc773c61faee85a6515daa0000000000000000000000007ae2f5b9e386cd1b50a4550696d957cb4900f03a000000000000000000000000b4dd66d7c2c7e57f628210187192fb89d4b99dd4000000000000000000000000e9ae3261a475a27bb1028f140bc2a7c843318afd000000000000000000000000ee226379db83cffc681495730c11fdde79ba4c0c0000000000000000000000003f349bbafec1551819b8be1efea2fc46ca749aa10000000000000000000000008b6c8fd93d6f4cea42bbb345dbc6f0dfdb5bec73000000000000000000000000ef0274e31810c9df02f98fafde0f841f4e66a1cd000000000000000000000000a6f79b60359f141df90a0c745125b131caaffd12000000000000000000000000e2d3a739effcd3a99387d015e260eefac72ebea100000000000000000000000061dd481a114a2e761c554b641742c973867899d3000000000000000000000000cc8e6d00c17eb431350c6c50d8b8f05176b90b11000000000000000000000000ea0a6e3c511bbd10f4519ece37dc24887e11b55d0000000000000000000000002d4c407bbe49438ed859fe965b140dcf1aab71a9000000000000000000000000685b1ded8013785d6623cc18d214320b6bb64759000000000000000000000000d1d6bf74282782b0b3eb1413c901d6ecf02e8e2800000000000000000000000070f657164e5b75689b64b7fd1fa275f334f28e18000000000000000000000000be807dddb074639cd9fa61b47676c064fc50d62c000000000000000000000000b218c5d6af1f979ac42bc68d98a5a0d796c6ab010000000000000000000000009f8ccdafcc39f3c7d6ebf637c9151673cbc36b88000000000000000000000000d93dbfb27e027f5e9e6da52b9e1c413ce35adc11000000000000000000000000ce2fd7544e0b2cc94692d4a704debef7bcb613280000000000000000000000000bac492386862ad3df4b666bc096b0505bb694da000000000000000000000000733fda7714a05960b7536330be4dbb135bef0ed600000000000000000000000035ebb5849518aff370ca25e19e1072cc1a9fabca000000000000000000000000ebe0b55ad7bb78309180cada12427d120fdbcc3a0000000000000000000000006488aa4d1955ee33403f8ccb1d4de5fb97c7ade20000000000000000000000004396e28197653d0c244d95f8c1e57da902a72b4e000000000000000000000000702be18040aa2a9b1af9219941469f1a435854fc00000000000000000000000012d810c13e42811e9907c02e02d1fad46cfa18ba0000000000000000000000002a7cdd959bfe8d9487b2a43b33565295a698f7e2000000000000000000000000b8f7166496996a7da21cf1f1b04d9b3e26a3d0770000000000000000000000009bb832254baf4e8b4cc26bd2b52b31389b56e98b0000000000000000000000004430b3230294d12c6ab2aac5c2cd68e80b16b581000000000000000000000000c2be4ec20253b8642161bc3f444f53679c1f3d47000000000000000000000000ee01c3b1283aa067c58eab4709f85e99d46de5fe0000000000000000000000009ef9f4360c606c7ab4db26b016007d3ad0ab86a00000000000000000000000002f7be8361c80a4c1e7e9aaf001d0877f1cfde21800000000000000000000000035e7a025f4da968de7e4d7e4004197917f4070f1000000000000000000000000d6caa02bbebaebb5d7e581e4b66559e635f805ff0000000000000000000000008c4d90829ce8f72d0163c1d5cf348a862d55063000000000000000000000000068bf0b8b6fb4e317a0f9d6f03eaf8ce6675bc60d00000000000000000000000082012708dafc9e1b880fd083b32182b869be8e090000000000000000000000006bbad7cf34b5fa511d8e963dbba288b1960e75d600000000000000000000000022b81f8e175ffde54d797fe11eb03f9e3bf75f1d00000000000000000000000078f3adfc719c99674c072166708589033e2d9afe00000000000000000000000029a97c6effb8a411dabc6adeefaa84f5067c8bbe000000000000000000000000aacf6a8119f7e11623b5a43da638e91f669a130f0000000000000000000000002b3a6c089311b478bf629c29d790a7a6db3fc1b9000000000000000000000000fe6e72b223f6d6cf4edc6bff92f30e84b8258249000000000000000000000000a6503279e8b5c7bb5cf4defd3ec8abf3e009a80b0000000000000000000000004ee63a09170c3f2207aeca56134fc2bee1b28e3c000000000000000000000000ac0e15a038eedfc68ba3c35c73fed5be4a07afb500000000000000000000000069c77a677c40c7fbea129d4b171a39b7a8ddabfa";
    bytes private constant INIT_BC_VOTE_ADDRESSES =
        hex"00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000044000000000000000000000000000000000000000000000000000000000000004a00000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000056000000000000000000000000000000000000000000000000000000000000005c00000000000000000000000000000000000000000000000000000000000000620000000000000000000000000000000000000000000000000000000000000068000000000000000000000000000000000000000000000000000000000000006e0000000000000000000000000000000000000000000000000000000000000074000000000000000000000000000000000000000000000000000000000000007a00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000086000000000000000000000000000000000000000000000000000000000000008c00000000000000000000000000000000000000000000000000000000000000920000000000000000000000000000000000000000000000000000000000000098000000000000000000000000000000000000000000000000000000000000009e00000000000000000000000000000000000000000000000000000000000000a400000000000000000000000000000000000000000000000000000000000000aa00000000000000000000000000000000000000000000000000000000000000b000000000000000000000000000000000000000000000000000000000000000b600000000000000000000000000000000000000000000000000000000000000bc00000000000000000000000000000000000000000000000000000000000000c200000000000000000000000000000000000000000000000000000000000000c800000000000000000000000000000000000000000000000000000000000000ce00000000000000000000000000000000000000000000000000000000000000d400000000000000000000000000000000000000000000000000000000000000da00000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000e600000000000000000000000000000000000000000000000000000000000000ec00000000000000000000000000000000000000000000000000000000000000f200000000000000000000000000000000000000000000000000000000000000f800000000000000000000000000000000000000000000000000000000000000fe0000000000000000000000000000000000000000000000000000000000000104000000000000000000000000000000000000000000000000000000000000010a00000000000000000000000000000000000000000000000000000000000000030977cf58294f7239d515e15b24cfeb82494056cf691eaf729b165f32c9757c429dba5051155903067e56ebe3698678e9100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003081db0422a5fd08e40db1fc2368d2245e4b18b1d0b85c921aaaafd2e341760e29fc613edd39f71254614e2055c3287a510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308a923564c6ffd37fb2fe9f118ef88092e8762c7addb526ab7eb1e772baef85181f892c731be0c1891a50e6b06262c816000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b84f83ff2df44193496793b847f64e9d6db1b3953682bb95edd096eb1e69bbd357c200992ca78050d0cbe180cfaa018e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b0de8472be0308918c8bdb369bf5a67525210daffa053c52224c1d2ef4f5b38e4ecfcd06a1cc51c39c3a7dccfcb6b507000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030ae7bc6faa3f0cc3e6093b633fd7ee4f86970926958d0b7ec80437f936acf212b78f0cd095f4565fff144fd458d233a5b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003084248a459464eec1a21e7fc7b71a053d9644e9bb8da4853b8f872cd7c1d6b324bf1922829830646ceadfb658d3de009a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030a8a257074e82b881cfa06ef3eb4efeca060c2531359abd0eab8af1e3edfa2025fca464ac9c3fd123f6c24a0d7886948500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003098cbf822e4bc29f1701ac0350a3d042cd0756e9f74822c6481773ceb000641c51b870a996fe0f6a844510b1061f38cd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b772e180fbf38a051c97dabc8aaa0126a233a9e828cdafcc7422c4bb1f4030a56ba364c54103f26bad91508b5220b741000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030956c470ddff48cb49300200b5f83497f3a3ccb3aeb83c5edd9818569038e61d197184f4aa6939ea5e9911e3e98ac6d210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308a80967d39e406a0a9642d41e9007a27fc1150a267d143a9f786cd2b5eecbdcc4036273705225b956d5e2f8f5eb95d25000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b3a3d4feb825ae9702711566df5dbf38e82add4dd1b573b95d2466fa6501ccb81e9d26a352b96150ccbf7b697fd0a419000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b2d4c6283c44a1c7bd503aaba7666e9f0c830e0ff016c1c750a5e48757a713d0836b1cabfd5c281b1de3b77d1c19218300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003093c1f7f6929d1fe2a17b4e14614ef9fc5bdc713d6631d675403fbeefac55611bf612700b1b65f4744861b80b0f7d6ab00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308a60f82a7bcf74b4cb053b9bfe83d0ed02a84ebb10865dfdd8e26e7535c43a1cccd268e860f502216b379dfc9971d358000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030939e8fb41b682372335be8070199ad3e8621d1743bcac4cc9d8f0f6e10f41e56461385c8eb5daac804fe3f2bca6ce73900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003096a26afa1295da81418593bd12814463d9f6e45c36a0e47eb4cd3e5b6af29c41e2a3a5636430155a466e216585af3ba7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b1f2c71577def3144fabeb75a8a1c8cb5b51d1d1b4a05eec67988b8685008baa17459ec425dbaebc852f496dc92196cd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b659ad0fbd9f515893fdd740b29ba0772dbde9b4635921dd91bd2963a0fc855e31f6338f45b211c4e9dedb7f2eb09de70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308819ec5ec3e97e1f03bbb4bb6055c7a5feac8f4f259df58349a32bb5cb377e2cb1f362b77f1dd398cfd3e9dba46138c3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b313f9cba57c63a84edb4079140e6dbd7829e5023c9532fce57e9fe602400a2953f4bf7dab66cca16e97be95d4de7044000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b64abe25614c9cfd32e456b4d521f29c8357f4af4606978296c9be93494072ac05fa86e3d27cc8d66e65000f8ba33fbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b0bec348681af766751cb839576e9c515a09c8bffa30a46296ccc56612490eb480d03bf948e10005bbcc0421f90b3d4e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b0245c33bc556cfeb013cd3643b30dbdef6df61a0be3ba00cae104b3c587083852e28f8911689c7033f7021a8a1774c9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030a7f3e2c0b4b16ad183c473bafe30a36e39fa4a143657e229cd23c77f8fbc8e4e4e241695dd3d248d1e51521eee6619140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308fdf49777b22f927d460fa3fcdd7f2ba0cf200634a3dfb5197d7359f2f88aaf496ef8c93a065de0f376d164ff2b6db9a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308ab17a9148339ef40aed8c177379c4db0bb5efc6f5c57a5d1a6b58b84d4b562e227196c79bda9a136830ed0c09f378130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308dd20979bd63c14df617a6939c3a334798149151577dd3f1fadb2bd1c1b496bf84c25c879da5f0f9dfdb88c6dd17b1e6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b679cbab0276ac30ff5f198e5e1dedf6b84959129f70fe7a07fcdf13444ba45b5dbaa7b1f650adf8b0acbecd04e2675b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000308974616fe8ab950a3cded19b1d16ff49c97bf5af65154b3b097d5523eb213f3d35fc5c57e7276c7f2d83be87ebfdcdf9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030ab764a39ff81dad720d5691b852898041a3842e09ecbac8025812d51b32223d8420e6ae51a01582220a10f7722de67c10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000309025b6715c8eaabac0bfccdb2f25d651c9b69b0a184011a4a486b0b2080319d2396e7ca337f2abdf01548b2de1b3ba06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030b2317f59d86abfaf690850223d90e9e7593d91a29331dfc2f84d5adecc75fc39ecab4632c1b4400a3dd1e1298835bcca00000000000000000000000000000000";

    // receive fund status
    uint8 private constant _DISABLE = 0;
    uint8 private constant _ENABLE = 1;

    /*----------------- errors -----------------*/
    // @notice signature: 0x5f28f62b
    error ValidatorExisted();
    // @notice signature: 0x056e8811
    error ValidatorNotExisted();
    // @notice signature: 0x4b6b857d
    error ValidatorNotJailed();
    // @notice signature: 0x3cdeb0ea
    error DuplicateConsensusAddress();
    // @notice signature: 0x11fdb947
    error DuplicateVoteAddress();
    // @notice signature: 0xc0bf4143
    error DuplicateMoniker();
    // @notice signature: 0x2f64097e
    error SelfDelegationNotEnough();
    // @notice signature: 0xdc81db85
    error InvalidCommission();
    // @notice signature: 0x5dba5ad7
    error InvalidMoniker();
    // @notice signature: 0x2c8fc796
    error InvalidVoteAddress();
    // @notice signature: 0xca40c236
    error InvalidConsensusAddress();
    // @notice signature: 0x3f259b7a
    error UpdateTooFrequently();
    // @notice signature: 0x5c32dd9c
    error JailTimeNotExpired();
    // @notice signature: 0xdc6f0bdd
    error DelegationAmountTooSmall();
    // @notice signature: 0x64689203
    error OnlySelfDelegation();
    // @notice signature: 0x9811e0c7
    error ZeroShares();
    // @notice signature: 0xf0e3e629
    error SameValidator();
    // @notice signature: 0xbd52fcdb
    error NoMoreFelonyAllowed();
    // @notice signature: 0x37233762
    error AlreadySlashed();
    // @notice signature: 0x90b8ec18
    error TransferFailed();
    // @notice signature: 0x41abc801
    error InvalidRequest();
    // @notice signature: 0x1898eb6b
    error VoteAddressExpired();
    // @notice signature: 0xc2aee074
    error ConsensusAddressExpired();
    // @notice signature: 0x0d7b78d4
    error InvalidSynPackage();
    // @notice signature: 0xbebdc757
    error InvalidAgent();
    // @notice signature: 0x682a6e7c
    error InvalidValidator();

    /*----------------- storage -----------------*/
    uint8 private _receiveFundStatus;
    uint256 public transferGasLimit;

    // stake params
    uint256 public minSelfDelegationBNB;
    uint256 public minDelegationBNBChange;
    uint256 public maxElectedValidators;
    uint256 public unbondPeriod;
    uint256 public redelegateFeeRate;

    // slash params
    uint256 public downtimeSlashAmount;
    uint256 public felonySlashAmount;
    uint256 public downtimeJailTime;
    uint256 public felonyJailTime;

    // validator operator address set
    EnumerableSet.AddressSet private _validatorSet;
    // validator operator address => validator info
    mapping(address => Validator) private _validators;
    // validator moniker set(hash of the moniker)
    mapping(bytes32 => bool) private _monikerSet;
    // validator consensus address => validator operator address
    mapping(address => address) public consensusToOperator;
    // validator consensus address => expiry date
    mapping(address => uint256) public consensusExpiration;
    // validator vote address => validator operator address
    mapping(bytes => address) public voteToOperator;
    // validator vote address => expiry date
    mapping(bytes => uint256) public voteExpiration;

    // legacy addresses of BC
    mapping(address => bool) private _legacyConsensusAddress;
    mapping(bytes => bool) private _legacyVoteAddress;

    // total number of current jailed validators
    uint256 public numOfJailed;
    // max number of jailed validators between breathe block(only for malicious vote and double sign)
    uint256 public maxFelonyBetweenBreatheBlock;
    // index(timestamp / breatheBlockInterval) => number of malicious vote and double sign slash
    mapping(uint256 => uint256) private _felonyMap;
    // slash key => slash jail time
    mapping(bytes32 => uint256) private _felonyRecords;

    // agent => validator operator address
    mapping(address => address) public agentToOperator;

    /*----------------- structs and events -----------------*/
    struct StakeMigrationPackage {
        address operatorAddress; // the operator address of the target validator to delegate to
        address delegator; // the beneficiary of the delegation
        address refundAddress; // the Beacon Chain address to refund the fund if migration failed
        uint256 amount; // the amount of BNB to be migrated(decimal: 18)
    }

    enum StakeMigrationRespCode {
        MIGRATE_SUCCESS,
        CLAIM_FUND_FAILED,
        VALIDATOR_NOT_EXISTED,
        VALIDATOR_JAILED,
        INVALID_DELEGATOR
    }

    struct Validator {
        address consensusAddress;
        address operatorAddress;
        address creditContract;
        uint256 createdTime;
        bytes voteAddress;
        Description description;
        Commission commission;
        bool jailed;
        uint256 jailUntil;
        uint256 updateTime;
        // The agent can perform transactions on behalf of the operatorAddress in certain scenarios.
        address agent;
        uint256[19] __reservedSlots;
    }

    struct Description {
        string moniker;
        string identity;
        string website;
        string details;
    }

    struct Commission {
        uint64 rate; // the commission rate charged to delegators(10000 is 100%)
        uint64 maxRate; // maximum commission rate which validator can ever charge
        uint64 maxChangeRate; // maximum daily increase of the validator commission
    }

    enum SlashType {
        DoubleSign,
        DownTime,
        MaliciousVote
    }

    event ValidatorCreated(
        address indexed consensusAddress,
        address indexed operatorAddress,
        address indexed creditContract,
        bytes voteAddress
    );
    event StakeCreditInitialized(address indexed operatorAddress, address indexed creditContract);
    event ConsensusAddressEdited(address indexed operatorAddress, address indexed newConsensusAddress);
    event CommissionRateEdited(address indexed operatorAddress, uint64 newCommissionRate);
    event DescriptionEdited(address indexed operatorAddress);
    event VoteAddressEdited(address indexed operatorAddress, bytes newVoteAddress);
    event Delegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event Undelegated(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event Redelegated(
        address indexed srcValidator,
        address indexed dstValidator,
        address indexed delegator,
        uint256 oldShares,
        uint256 newShares,
        uint256 bnbAmount
    );
    event RewardDistributed(address indexed operatorAddress, uint256 reward);
    event RewardDistributeFailed(address indexed operatorAddress, bytes failReason);
    event ValidatorSlashed(
        address indexed operatorAddress, uint256 jailUntil, uint256 slashAmount, SlashType slashType
    );
    event ValidatorJailed(address indexed operatorAddress);
    event ValidatorEmptyJailed(address indexed operatorAddress);
    event ValidatorUnjailed(address indexed operatorAddress);
    event Claimed(address indexed operatorAddress, address indexed delegator, uint256 bnbAmount);
    event MigrateSuccess(address indexed operatorAddress, address indexed delegator, uint256 shares, uint256 bnbAmount);
    event MigrateFailed(
        address indexed operatorAddress, address indexed delegator, uint256 bnbAmount, StakeMigrationRespCode respCode
    );
    event UnexpectedPackage(uint8 channelId, bytes msgBytes);
    event AgentChanged(address indexed operatorAddress, address indexed oldAgent, address indexed newAgent);

    /*----------------- modifiers -----------------*/
    modifier validatorExist(address operatorAddress) {
        if (!_validatorSet.contains(operatorAddress)) revert ValidatorNotExisted();
        _;
    }

    modifier enableReceivingFund() {
        _receiveFundStatus = _ENABLE;
        _;
        _receiveFundStatus = _DISABLE;
    }

    receive() external payable {
        // to prevent BNB from being lost
        if (_receiveFundStatus != _ENABLE) revert();
    }

    /**
     * @dev this function is invoked by BSC Parlia consensus engine during the hard fork
     */
    function initialize() external initializer onlyCoinbase onlyZeroGasPrice {
        transferGasLimit = 5000;
        minSelfDelegationBNB = 2_000 ether;
        minDelegationBNBChange = 1 ether;
        maxElectedValidators = 45;
        unbondPeriod = 7 days;
        redelegateFeeRate = 2;
        downtimeSlashAmount = 10 ether;
        felonySlashAmount = 200 ether;
        downtimeJailTime = 2 days;
        felonyJailTime = 30 days;
        maxFelonyBetweenBreatheBlock = 2;

        address[] memory bcConsensusAddress;
        bytes[] memory bcVoteAddress;
        bcConsensusAddress = abi.decode(INIT_BC_CONSENSUS_ADDRESSES, (address[]));
        bcVoteAddress = abi.decode(INIT_BC_VOTE_ADDRESSES, (bytes[]));
        for (uint256 i; i < bcConsensusAddress.length; ++i) {
            _legacyConsensusAddress[bcConsensusAddress[i]] = true;
        }
        for (uint256 i; i < bcVoteAddress.length; ++i) {
            _legacyVoteAddress[bcVoteAddress[i]] = true;
        }

        // Different address will be set depending on the environment
        __Protectable_init_unchained(0x08E68Ec70FA3b629784fDB28887e206ce8561E08);
    }

    /*----------------- Implement cross chain app -----------------*/
    function handleSynPackage(
        uint8,
        bytes calldata msgBytes
    ) external onlyCrossChainContract whenNotPaused enableReceivingFund returns (bytes memory) {
        (StakeMigrationPackage memory migrationPkg, bool decodeSuccess) = _decodeMigrationSynPackage(msgBytes);
        if (!decodeSuccess) revert InvalidSynPackage();

        if (migrationPkg.amount == 0) {
            return new bytes(0);
        }

        // claim fund from TokenHub
        bool claimSuccess = ITokenHub(TOKEN_HUB_ADDR).claimMigrationFund(migrationPkg.amount);
        if (!claimSuccess) {
            emit MigrateFailed(
                migrationPkg.operatorAddress,
                migrationPkg.delegator,
                migrationPkg.amount,
                StakeMigrationRespCode.CLAIM_FUND_FAILED
            );
            return msgBytes;
        }

        StakeMigrationRespCode respCode = _doMigration(migrationPkg);

        if (respCode == StakeMigrationRespCode.MIGRATE_SUCCESS) {
            return new bytes(0);
        } else {
            (bool success,) = TOKEN_HUB_ADDR.call{ value: address(this).balance }("");
            if (!success) revert TransferFailed();
            emit MigrateFailed(migrationPkg.operatorAddress, migrationPkg.delegator, migrationPkg.amount, respCode);
            return msgBytes;
        }
    }

    function handleAckPackage(uint8 channelId, bytes calldata msgBytes) external onlyCrossChainContract {
        // should not happen
        emit UnexpectedPackage(channelId, msgBytes);
    }

    function handleFailAckPackage(uint8 channelId, bytes calldata msgBytes) external onlyCrossChainContract {
        // should not happen
        emit UnexpectedPackage(channelId, msgBytes);
    }

    /*----------------- external functions -----------------*/
    /**
     * @param newAgent the new agent address of the validator, updating to address(0) means remove the old agent.
     */
    function updateAgent(address newAgent) external validatorExist(msg.sender) whenNotPaused notInBlackList {
        if (agentToOperator[newAgent] != address(0)) revert InvalidAgent();
        if (_validatorSet.contains(newAgent)) revert InvalidAgent();

        address operatorAddress = msg.sender;
        address oldAgent = _validators[operatorAddress].agent;
        if (oldAgent == newAgent) revert InvalidAgent();

        if (oldAgent != address(0)) {
            delete agentToOperator[oldAgent];
        }

        _validators[operatorAddress].agent = newAgent;

        if (newAgent != address(0)) {
            agentToOperator[newAgent] = operatorAddress;
        }

        emit AgentChanged(operatorAddress, oldAgent, newAgent);
    }

    /**
     * @param consensusAddress the consensus address of the validator
     * @param voteAddress the vote address of the validator
     * @param blsProof the bls proof of the vote address
     * @param commission the commission of the validator
     * @param description the description of the validator
     */
    function createValidator(
        address consensusAddress,
        bytes calldata voteAddress,
        bytes calldata blsProof,
        Commission calldata commission,
        Description calldata description
    ) external payable whenNotPaused notInBlackList {
        // basic check
        address operatorAddress = msg.sender;
        if (_validatorSet.contains(operatorAddress)) revert ValidatorExisted();
        if (agentToOperator[operatorAddress] != address(0)) revert InvalidValidator();

        if (consensusToOperator[consensusAddress] != address(0) || _legacyConsensusAddress[consensusAddress]) {
            revert DuplicateConsensusAddress();
        }
        if (voteToOperator[voteAddress] != address(0) || _legacyVoteAddress[voteAddress]) {
            revert DuplicateVoteAddress();
        }
        bytes32 monikerHash = keccak256(abi.encodePacked(description.moniker));
        if (_monikerSet[monikerHash]) revert DuplicateMoniker();

        uint256 delegation = msg.value - LOCK_AMOUNT; // create validator need to lock 1 BNB
        if (delegation < minSelfDelegationBNB) revert SelfDelegationNotEnough();

        if (consensusAddress == address(0)) revert InvalidConsensusAddress();
        if (
            commission.maxRate > 5_000 || commission.rate > commission.maxRate
                || commission.maxChangeRate > commission.maxRate
        ) revert InvalidCommission();
        if (!_checkMoniker(description.moniker)) revert InvalidMoniker();
        // proof-of-possession verify
        if (!_checkVoteAddress(operatorAddress, voteAddress, blsProof)) revert InvalidVoteAddress();

        // deploy stake credit proxy contract
        address creditContract = _deployStakeCredit(operatorAddress, description.moniker);

        _validatorSet.add(operatorAddress);
        _monikerSet[monikerHash] = true;
        Validator storage valInfo = _validators[operatorAddress];
        valInfo.consensusAddress = consensusAddress;
        valInfo.operatorAddress = operatorAddress;
        valInfo.creditContract = creditContract;
        valInfo.createdTime = block.timestamp;
        valInfo.voteAddress = voteAddress;
        valInfo.description = description;
        valInfo.commission = commission;
        valInfo.updateTime = block.timestamp;
        consensusToOperator[consensusAddress] = operatorAddress;
        voteToOperator[voteAddress] = operatorAddress;

        emit ValidatorCreated(consensusAddress, operatorAddress, creditContract, voteAddress);
        emit Delegated(operatorAddress, operatorAddress, delegation, delegation);
        emit Delegated(operatorAddress, DEAD_ADDRESS, LOCK_AMOUNT, LOCK_AMOUNT);

        IGovToken(GOV_TOKEN_ADDR).sync(creditContract, operatorAddress);
    }

    /**
     * @param newConsensusAddress the new consensus address of the validator
     */
    function editConsensusAddress(address newConsensusAddress)
        external
        whenNotPaused
        notInBlackList
        validatorExist(_bep410MsgSender())
    {
        if (newConsensusAddress == address(0)) revert InvalidConsensusAddress();
        if (consensusToOperator[newConsensusAddress] != address(0) || _legacyConsensusAddress[newConsensusAddress]) {
            revert DuplicateConsensusAddress();
        }

        address operatorAddress = _bep410MsgSender();
        Validator storage valInfo = _validators[operatorAddress];
        if (valInfo.updateTime + BREATHE_BLOCK_INTERVAL > block.timestamp) revert UpdateTooFrequently();

        consensusExpiration[valInfo.consensusAddress] = block.timestamp;
        valInfo.consensusAddress = newConsensusAddress;
        valInfo.updateTime = block.timestamp;
        consensusToOperator[newConsensusAddress] = operatorAddress;

        emit ConsensusAddressEdited(operatorAddress, newConsensusAddress);
    }

    /**
     * @param commissionRate the new commission rate of the validator
     */
    function editCommissionRate(uint64 commissionRate)
        external
        whenNotPaused
        notInBlackList
        validatorExist(_bep410MsgSender())
    {
        address operatorAddress = _bep410MsgSender();
        Validator storage valInfo = _validators[operatorAddress];
        if (valInfo.updateTime + BREATHE_BLOCK_INTERVAL > block.timestamp) revert UpdateTooFrequently();

        if (commissionRate > valInfo.commission.maxRate) revert InvalidCommission();
        uint256 changeRate = commissionRate >= valInfo.commission.rate
            ? commissionRate - valInfo.commission.rate
            : valInfo.commission.rate - commissionRate;
        if (changeRate > valInfo.commission.maxChangeRate) revert InvalidCommission();

        valInfo.commission.rate = commissionRate;
        valInfo.updateTime = block.timestamp;

        emit CommissionRateEdited(operatorAddress, commissionRate);
    }

    /**
     * @notice the moniker of the validator will be ignored as it is not editable
     * @param description the new description of the validator
     */
    function editDescription(Description memory description)
        external
        whenNotPaused
        notInBlackList
        validatorExist(_bep410MsgSender())
    {
        address operatorAddress = _bep410MsgSender();
        Validator storage valInfo = _validators[operatorAddress];
        if (valInfo.updateTime + BREATHE_BLOCK_INTERVAL > block.timestamp) revert UpdateTooFrequently();

        description.moniker = valInfo.description.moniker;
        valInfo.description = description;
        valInfo.updateTime = block.timestamp;

        emit DescriptionEdited(operatorAddress);
    }

    /**
     * @param newVoteAddress the new vote address of the validator
     * @param blsProof the bls proof of the vote address
     */
    function editVoteAddress(
        bytes calldata newVoteAddress,
        bytes calldata blsProof
    ) external whenNotPaused notInBlackList validatorExist(_bep410MsgSender()) {
        // proof-of-possession verify
        address operatorAddress = _bep410MsgSender();
        if (!_checkVoteAddress(operatorAddress, newVoteAddress, blsProof)) revert InvalidVoteAddress();
        if (voteToOperator[newVoteAddress] != address(0) || _legacyVoteAddress[newVoteAddress]) {
            revert DuplicateVoteAddress();
        }

        Validator storage valInfo = _validators[operatorAddress];
        if (valInfo.updateTime + BREATHE_BLOCK_INTERVAL > block.timestamp) revert UpdateTooFrequently();

        voteExpiration[valInfo.voteAddress] = block.timestamp;
        valInfo.voteAddress = newVoteAddress;
        valInfo.updateTime = block.timestamp;
        voteToOperator[newVoteAddress] = operatorAddress;

        emit VoteAddressEdited(operatorAddress, newVoteAddress);
    }

    /**
     * @param operatorAddress the operator address of the validator to be unjailed
     */
    function unjail(address operatorAddress) external whenNotPaused notInBlackList validatorExist(operatorAddress) {
        Validator storage valInfo = _validators[operatorAddress];
        if (!valInfo.jailed) revert ValidatorNotJailed();

        if (IStakeCredit(valInfo.creditContract).getPooledBNB(operatorAddress) < minSelfDelegationBNB) {
            revert SelfDelegationNotEnough();
        }
        if (valInfo.jailUntil > block.timestamp) revert JailTimeNotExpired();

        valInfo.jailed = false;
        numOfJailed -= 1;
        emit ValidatorUnjailed(operatorAddress);
    }

    /**
     * @param operatorAddress the operator address of the validator to be delegated to
     * @param delegateVotePower whether to delegate vote power to the validator
     */
    function delegate(
        address operatorAddress,
        bool delegateVotePower
    ) external payable whenNotPaused notInBlackList validatorExist(operatorAddress) {
        uint256 bnbAmount = msg.value;
        if (bnbAmount < minDelegationBNBChange) revert DelegationAmountTooSmall();

        address delegator = msg.sender;
        Validator memory valInfo = _validators[operatorAddress];
        if (valInfo.jailed && delegator != operatorAddress) revert OnlySelfDelegation();

        uint256 shares = IStakeCredit(valInfo.creditContract).delegate{ value: bnbAmount }(delegator);
        emit Delegated(operatorAddress, delegator, shares, bnbAmount);

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, delegator);
        if (delegateVotePower) {
            IGovToken(GOV_TOKEN_ADDR).delegateVote(delegator, operatorAddress);
        }
    }

    /**
     * @dev Undelegate BNB from a validator, fund is only claimable few days later
     * @param operatorAddress the operator address of the validator to be undelegated from
     * @param shares the shares to be undelegated
     */
    function undelegate(
        address operatorAddress,
        uint256 shares
    ) external whenNotPaused notInBlackList validatorExist(operatorAddress) {
        if (shares == 0) revert ZeroShares();

        address delegator = msg.sender;
        Validator memory valInfo = _validators[operatorAddress];

        uint256 bnbAmount = IStakeCredit(valInfo.creditContract).undelegate(delegator, shares);
        emit Undelegated(operatorAddress, delegator, shares, bnbAmount);

        if (delegator == operatorAddress) {
            _checkValidatorSelfDelegation(operatorAddress);
        }

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, delegator);
    }

    /**
     * @param srcValidator the operator address of the validator to be redelegated from
     * @param dstValidator the operator address of the validator to be redelegated to
     * @param shares the shares to be redelegated
     * @param delegateVotePower whether to delegate vote power to the dstValidator
     */
    function redelegate(
        address srcValidator,
        address dstValidator,
        uint256 shares,
        bool delegateVotePower
    )
        external
        whenNotPaused
        notInBlackList
        validatorExist(srcValidator)
        validatorExist(dstValidator)
        enableReceivingFund
    {
        if (shares == 0) revert ZeroShares();
        if (srcValidator == dstValidator) revert SameValidator();

        address delegator = msg.sender;
        Validator memory srcValInfo = _validators[srcValidator];
        Validator memory dstValInfo = _validators[dstValidator];
        if (dstValInfo.jailed && delegator != dstValidator) revert OnlySelfDelegation();

        uint256 bnbAmount = IStakeCredit(srcValInfo.creditContract).unbond(delegator, shares);
        if (bnbAmount < minDelegationBNBChange) revert DelegationAmountTooSmall();
        // check if the srcValidator has enough self delegation
        if (
            delegator == srcValidator
                && IStakeCredit(srcValInfo.creditContract).getPooledBNB(srcValidator) < minSelfDelegationBNB
        ) {
            revert SelfDelegationNotEnough();
        }

        uint256 feeCharge = bnbAmount * redelegateFeeRate / REDELEGATE_FEE_RATE_BASE;
        (bool success,) = dstValInfo.creditContract.call{ value: feeCharge }("");
        if (!success) revert TransferFailed();

        bnbAmount -= feeCharge;
        uint256 newShares = IStakeCredit(dstValInfo.creditContract).delegate{ value: bnbAmount }(delegator);
        emit Redelegated(srcValidator, dstValidator, delegator, shares, newShares, bnbAmount);

        address[] memory stakeCredits = new address[](2);
        stakeCredits[0] = srcValInfo.creditContract;
        stakeCredits[1] = dstValInfo.creditContract;
        IGovToken(GOV_TOKEN_ADDR).syncBatch(stakeCredits, delegator);
        if (delegateVotePower) {
            IGovToken(GOV_TOKEN_ADDR).delegateVote(delegator, dstValidator);
        }
    }

    /**
     * @dev Claim the undelegated BNB from the pool after unbondPeriod
     * @param operatorAddress the operator address of the validator
     * @param requestNumber the request number of the undelegation. 0 means claim all
     */
    function claim(address operatorAddress, uint256 requestNumber) external whenNotPaused notInBlackList {
        _claim(operatorAddress, requestNumber);
    }

    /**
     * @dev Claim the undelegated BNB from the pools after unbondPeriod
     * @param operatorAddresses the operator addresses of the validator
     * @param requestNumbers numbers of the undelegation requests. 0 means claim all
     */
    function claimBatch(
        address[] calldata operatorAddresses,
        uint256[] calldata requestNumbers
    ) external whenNotPaused notInBlackList {
        if (operatorAddresses.length != requestNumbers.length) revert InvalidRequest();
        for (uint256 i; i < operatorAddresses.length; ++i) {
            _claim(operatorAddresses[i], requestNumbers[i]);
        }
    }

    /**
     * @dev Sync the gov tokens of validators in operatorAddresses
     * @param operatorAddresses the operator addresses of the validators
     * @param account the account to sync gov tokens to
     */
    function syncGovToken(
        address[] calldata operatorAddresses,
        address account
    ) external whenNotPaused notInBlackList {
        uint256 _length = operatorAddresses.length;
        address[] memory stakeCredits = new address[](_length);
        address credit;
        for (uint256 i = 0; i < _length; ++i) {
            if (!_validatorSet.contains(operatorAddresses[i])) revert ValidatorNotExisted();
            credit = _validators[operatorAddresses[i]].creditContract;
            stakeCredits[i] = credit;
        }

        IGovToken(GOV_TOKEN_ADDR).syncBatch(stakeCredits, account);
    }

    /*----------------- system functions -----------------*/
    /**
     * @dev This function will be called by consensus engine. So it should never revert.
     */
    function distributeReward(address consensusAddress) external payable onlyValidatorContract {
        address operatorAddress = consensusToOperator[consensusAddress];
        Validator memory valInfo = _validators[operatorAddress];
        if (valInfo.creditContract == address(0) || valInfo.jailed) {
            SYSTEM_REWARD_ADDR.call{ value: msg.value }("");
            emit RewardDistributeFailed(operatorAddress, "INVALID_VALIDATOR");
            return;
        }

        IStakeCredit(valInfo.creditContract).distributeReward{ value: msg.value }(valInfo.commission.rate);
        emit RewardDistributed(operatorAddress, msg.value);

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, operatorAddress);
    }

    /**
     * @dev Downtime slash. Only the `SlashIndicator` contract can call this function.
     */
    function downtimeSlash(address consensusAddress) external onlySlash {
        address operatorAddress = consensusToOperator[consensusAddress];
        if (!_validatorSet.contains(operatorAddress)) revert ValidatorNotExisted(); // should never happen
        Validator storage valInfo = _validators[operatorAddress];

        // slash
        uint256 slashAmount = IStakeCredit(valInfo.creditContract).slash(downtimeSlashAmount);
        uint256 jailUntil = block.timestamp + downtimeJailTime;
        _jailValidator(valInfo, jailUntil);

        emit ValidatorSlashed(operatorAddress, jailUntil, slashAmount, SlashType.DownTime);

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, operatorAddress);
    }

    /**
     * @dev Malicious vote slash. Only the `SlashIndicator` contract can call this function.
     */
    function maliciousVoteSlash(bytes calldata voteAddress) external onlySlash whenNotPaused {
        address operatorAddress = voteToOperator[voteAddress];
        if (!_validatorSet.contains(operatorAddress)) revert ValidatorNotExisted(); // should never happen
        Validator storage valInfo = _validators[operatorAddress];

        uint256 index = block.timestamp / BREATHE_BLOCK_INTERVAL;
        // This is to prevent many honest validators being slashed at the same time because of implementation bugs
        if (_felonyMap[index] >= maxFelonyBetweenBreatheBlock) revert NoMoreFelonyAllowed();
        _felonyMap[index] += 1;

        // check if the voteAddress has already expired
        if (voteExpiration[voteAddress] != 0 && voteExpiration[voteAddress] + BREATHE_BLOCK_INTERVAL < block.timestamp)
        {
            revert VoteAddressExpired();
        }

        // slash
        (bool canSlash, uint256 jailUntil) = _checkFelonyRecord(operatorAddress, SlashType.MaliciousVote);
        if (!canSlash) revert AlreadySlashed();
        uint256 slashAmount = IStakeCredit(valInfo.creditContract).slash(felonySlashAmount);
        _jailValidator(valInfo, jailUntil);

        emit ValidatorSlashed(operatorAddress, jailUntil, slashAmount, SlashType.MaliciousVote);

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, operatorAddress);
    }

    /**
     * @dev Double sign slash. Only the `SlashIndicator` contract can call this function.
     */
    function doubleSignSlash(address consensusAddress) external onlySlash whenNotPaused {
        address operatorAddress = consensusToOperator[consensusAddress];
        if (!_validatorSet.contains(operatorAddress)) revert ValidatorNotExisted(); // should never happen
        Validator storage valInfo = _validators[operatorAddress];

        uint256 index = block.timestamp / BREATHE_BLOCK_INTERVAL;
        // This is to prevent many honest validators being slashed at the same time because of implementation bugs
        if (_felonyMap[index] >= maxFelonyBetweenBreatheBlock) revert NoMoreFelonyAllowed();
        _felonyMap[index] += 1;

        // check if the consensusAddress has already expired
        if (
            consensusExpiration[consensusAddress] != 0
                && consensusExpiration[consensusAddress] + BREATHE_BLOCK_INTERVAL < block.timestamp
        ) {
            revert ConsensusAddressExpired();
        }

        // slash
        (bool canSlash, uint256 jailUntil) = _checkFelonyRecord(operatorAddress, SlashType.DoubleSign);
        if (!canSlash) revert AlreadySlashed();
        uint256 slashAmount = IStakeCredit(valInfo.creditContract).slash(felonySlashAmount);
        _jailValidator(valInfo, jailUntil);

        emit ValidatorSlashed(operatorAddress, jailUntil, slashAmount, SlashType.DoubleSign);

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, operatorAddress);
    }

    /**
     * @param key the key of the param
     * @param value the value of the param
     */
    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        if (key.compareStrings("transferGasLimit")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newTransferGasLimit = value.bytesToUint256(32);
            if (newTransferGasLimit < 2300 || newTransferGasLimit > 10_000) revert InvalidValue(key, value);
            transferGasLimit = newTransferGasLimit;
        } else if (key.compareStrings("minSelfDelegationBNB")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newMinSelfDelegationBNB = value.bytesToUint256(32);
            if (newMinSelfDelegationBNB < 1000 ether || newMinSelfDelegationBNB > 100_000 ether) {
                revert InvalidValue(key, value);
            }
            minSelfDelegationBNB = newMinSelfDelegationBNB;
        } else if (key.compareStrings("minDelegationBNBChange")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newMinDelegationBNBChange = value.bytesToUint256(32);
            if (newMinDelegationBNBChange < 0.1 ether || newMinDelegationBNBChange > 10 ether) {
                revert InvalidValue(key, value);
            }
            minDelegationBNBChange = newMinDelegationBNBChange;
        } else if (key.compareStrings("maxElectedValidators")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newMaxElectedValidators = value.bytesToUint256(32);
            if (newMaxElectedValidators == 0 || newMaxElectedValidators > 500) revert InvalidValue(key, value);
            maxElectedValidators = newMaxElectedValidators;
        } else if (key.compareStrings("unbondPeriod")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newUnbondPeriod = value.bytesToUint256(32);
            if (newUnbondPeriod < 3 days || newUnbondPeriod > 30 days) revert InvalidValue(key, value);
            unbondPeriod = newUnbondPeriod;
        } else if (key.compareStrings("redelegateFeeRate")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newRedelegateFeeRate = value.bytesToUint256(32);
            if (newRedelegateFeeRate > 100) {
                revert InvalidValue(key, value);
            }
            redelegateFeeRate = newRedelegateFeeRate;
        } else if (key.compareStrings("downtimeSlashAmount")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newDowntimeSlashAmount = value.bytesToUint256(32);
            if (newDowntimeSlashAmount < 5 ether || newDowntimeSlashAmount > felonySlashAmount) {
                revert InvalidValue(key, value);
            }
            downtimeSlashAmount = newDowntimeSlashAmount;
        } else if (key.compareStrings("felonySlashAmount")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newFelonySlashAmount = value.bytesToUint256(32);
            if (newFelonySlashAmount < 100 ether || newFelonySlashAmount <= downtimeSlashAmount) {
                revert InvalidValue(key, value);
            }
            felonySlashAmount = newFelonySlashAmount;
        } else if (key.compareStrings("downtimeJailTime")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newDowntimeJailTime = value.bytesToUint256(32);
            if (newDowntimeJailTime < 2 days || newDowntimeJailTime >= felonyJailTime) revert InvalidValue(key, value);
            downtimeJailTime = newDowntimeJailTime;
        } else if (key.compareStrings("felonyJailTime")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newFelonyJailTime = value.bytesToUint256(32);
            if (newFelonyJailTime < 10 days || newFelonyJailTime <= downtimeJailTime) revert InvalidValue(key, value);
            felonyJailTime = newFelonyJailTime;
        } else if (key.compareStrings("maxFelonyBetweenBreatheBlock")) {
            if (value.length != 32) revert InvalidValue(key, value);
            uint256 newJailedPerDay = value.bytesToUint256(32);
            if (newJailedPerDay == 0) revert InvalidValue(key, value);
            maxFelonyBetweenBreatheBlock = newJailedPerDay;
        } else if (key.compareStrings("stakeHubProtector")) {
            if (value.length != 20) revert InvalidValue(key, value);
            address newStakeHubProtector = value.bytesToAddress(20);
            if (newStakeHubProtector == address(0)) revert InvalidValue(key, value);
            _setProtector(newStakeHubProtector);
        } else {
            revert UnknownParam(key, value);
        }
        emit ParamChange(key, value);
    }

    /*----------------- view functions -----------------*/
    /**
     * @param operatorAddress the operator address of the validator
     * @param index the index of the day to query(timestamp / 1 days)
     *
     * @return the validator's reward of the day
     */
    function getValidatorRewardRecord(address operatorAddress, uint256 index) external view returns (uint256) {
        if (!_validatorSet.contains(operatorAddress)) revert ValidatorNotExisted();
        return IStakeCredit(_validators[operatorAddress].creditContract).rewardRecord(index);
    }

    /**
     * @param operatorAddress the operator address of the validator
     * @param index the index of the day to query(timestamp / 1 days)
     *
     * @return the validator's total pooled BNB of the day
     */
    function getValidatorTotalPooledBNBRecord(address operatorAddress, uint256 index) external view returns (uint256) {
        if (!_validatorSet.contains(operatorAddress)) revert ValidatorNotExisted();
        return IStakeCredit(_validators[operatorAddress].creditContract).totalPooledBNBRecord(index);
    }

    /**
     * @notice pagination query all validators' operator address and credit contract address
     *
     * @param offset the offset of the query
     * @param limit the limit of the query
     *
     * @return operatorAddrs operator addresses
     * @return creditAddrs credit contract addresses
     * @return totalLength total number of validators
     */
    function getValidators(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory operatorAddrs, address[] memory creditAddrs, uint256 totalLength) {
        totalLength = _validatorSet.length();
        if (offset >= totalLength) {
            return (operatorAddrs, creditAddrs, totalLength);
        }

        limit = limit == 0 ? totalLength : limit;
        uint256 count = (totalLength - offset) > limit ? limit : (totalLength - offset);
        operatorAddrs = new address[](count);
        creditAddrs = new address[](count);
        for (uint256 i; i < count; ++i) {
            operatorAddrs[i] = _validatorSet.at(offset + i);
            creditAddrs[i] = _validators[operatorAddrs[i]].creditContract;
        }
    }

    /**
     * @notice get the consensus address of a validator
     *
     * @param operatorAddress the operator address of the validator
     *
     * @return consensusAddress the consensus address of the validator
     */
    function getValidatorConsensusAddress(address operatorAddress) external view returns (address consensusAddress) {
        Validator memory valInfo = _validators[operatorAddress];
        consensusAddress = valInfo.consensusAddress;
    }

    /**
     * @notice get the credit contract address of a validator
     *
     * @param operatorAddress the operator address of the validator
     *
     * @return creditContract the credit contract address of the validator
     */
    function getValidatorCreditContract(address operatorAddress) external view returns (address creditContract) {
        Validator memory valInfo = _validators[operatorAddress];
        creditContract = valInfo.creditContract;
    }

    /**
     * @notice get the vote address of a validator
     *
     * @param operatorAddress the operator address of the validator
     *
     * @return voteAddress the vote address of the validator
     */
    function getValidatorVoteAddress(address operatorAddress) external view returns (bytes memory voteAddress) {
        Validator memory valInfo = _validators[operatorAddress];
        voteAddress = valInfo.voteAddress;
    }

    /**
     * @notice get the basic info of a validator
     *
     * @param operatorAddress the operator address of the validator
     *
     * @return createdTime the creation time of the validator
     * @return jailed whether the validator is jailed
     * @return jailUntil the jail time of the validator
     */
    function getValidatorBasicInfo(address operatorAddress)
        external
        view
        returns (uint256 createdTime, bool jailed, uint256 jailUntil)
    {
        Validator memory valInfo = _validators[operatorAddress];
        createdTime = valInfo.createdTime;
        jailed = valInfo.jailed;
        jailUntil = valInfo.jailUntil;
    }

    /**
     * @param operatorAddress the operator address of the validator
     *
     * @return the description of a validator
     */
    function getValidatorDescription(address operatorAddress)
        external
        view
        validatorExist(operatorAddress)
        returns (Description memory)
    {
        return _validators[operatorAddress].description;
    }

    /**
     * @param operatorAddress the operator address of the validator
     *
     * @return the commission of a validator
     */
    function getValidatorCommission(address operatorAddress)
        external
        view
        validatorExist(operatorAddress)
        returns (Commission memory)
    {
        return _validators[operatorAddress].commission;
    }

    /**
     * @param operatorAddress the operator address of the validator
     *
     * @return the agent of a validator
     */
    function getValidatorAgent(address operatorAddress)
        external
        view
        validatorExist(operatorAddress)
        returns (address)
    {
        return _validators[operatorAddress].agent;
    }

    /**
     * @dev this function will be used by Parlia consensus engine.
     *
     * @notice get the election info of a validator
     *
     * @param offset the offset of the query
     * @param limit the limit of the query
     *
     * @return consensusAddrs the consensus addresses of the validators
     * @return votingPowers the voting powers of the validators. The voting power will be 0 if the validator is jailed.
     * @return voteAddrs the vote addresses of the validators
     * @return totalLength the total number of validators
     */
    function getValidatorElectionInfo(
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (
            address[] memory consensusAddrs,
            uint256[] memory votingPowers,
            bytes[] memory voteAddrs,
            uint256 totalLength
        )
    {
        totalLength = _validatorSet.length();
        if (offset >= totalLength) {
            return (consensusAddrs, votingPowers, voteAddrs, totalLength);
        }

        limit = limit == 0 ? totalLength : limit;
        uint256 count = (totalLength - offset) > limit ? limit : (totalLength - offset);
        consensusAddrs = new address[](count);
        votingPowers = new uint256[](count);
        voteAddrs = new bytes[](count);
        for (uint256 i; i < count; ++i) {
            address operatorAddress = _validatorSet.at(offset + i);
            Validator memory valInfo = _validators[operatorAddress];
            consensusAddrs[i] = valInfo.consensusAddress;
            votingPowers[i] = valInfo.jailed ? 0 : IStakeCredit(valInfo.creditContract).totalPooledBNB();
            voteAddrs[i] = valInfo.voteAddress;
        }
    }

    /*----------------- internal functions -----------------*/
    function _decodeMigrationSynPackage(bytes memory msgBytes)
        internal
        pure
        returns (StakeMigrationPackage memory, bool)
    {
        StakeMigrationPackage memory migrationPackage;

        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();
        bool success = false;
        uint256 idx = 0;
        while (iter.hasNext()) {
            if (idx == 0) {
                migrationPackage.operatorAddress = address(uint160(iter.next().toAddress()));
            } else if (idx == 1) {
                migrationPackage.delegator = address(uint160(iter.next().toAddress()));
            } else if (idx == 2) {
                migrationPackage.refundAddress = address(uint160(iter.next().toAddress()));
            } else if (idx == 3) {
                migrationPackage.amount = iter.next().toUint();
                success = true;
            } else {
                break;
            }
            ++idx;
        }

        return (migrationPackage, success);
    }

    function _doMigration(StakeMigrationPackage memory migrationPkg) internal returns (StakeMigrationRespCode) {
        if (blackList[migrationPkg.delegator] || migrationPkg.delegator == address(0)) {
            return StakeMigrationRespCode.INVALID_DELEGATOR;
        }

        if (!_validatorSet.contains(migrationPkg.operatorAddress)) {
            return StakeMigrationRespCode.VALIDATOR_NOT_EXISTED;
        }

        Validator memory valInfo = _validators[migrationPkg.operatorAddress];
        if (valInfo.jailed && migrationPkg.delegator != migrationPkg.operatorAddress) {
            return StakeMigrationRespCode.VALIDATOR_JAILED;
        }

        uint256 shares =
            IStakeCredit(valInfo.creditContract).delegate{ value: migrationPkg.amount }(migrationPkg.delegator);
        emit Delegated(migrationPkg.operatorAddress, migrationPkg.delegator, shares, migrationPkg.amount);
        emit MigrateSuccess(migrationPkg.operatorAddress, migrationPkg.delegator, shares, migrationPkg.amount);

        IGovToken(GOV_TOKEN_ADDR).sync(valInfo.creditContract, migrationPkg.delegator);

        return StakeMigrationRespCode.MIGRATE_SUCCESS;
    }

    function _checkMoniker(string memory moniker) internal pure returns (bool) {
        bytes memory bz = bytes(moniker);

        // 1. moniker length should be between 3 and 9
        if (bz.length < 3 || bz.length > 9) {
            return false;
        }

        // 2. first character should be uppercase
        if (uint8(bz[0]) < 65 || uint8(bz[0]) > 90) {
            return false;
        }

        // 3. only alphanumeric characters are allowed
        for (uint256 i = 1; i < bz.length; ++i) {
            // Check if the ASCII value of the character falls outside the range of alphanumeric characters
            if (
                (uint8(bz[i]) < 48 || uint8(bz[i]) > 57) && (uint8(bz[i]) < 65 || uint8(bz[i]) > 90)
                    && (uint8(bz[i]) < 97 || uint8(bz[i]) > 122)
            ) {
                // Character is a special character
                return false;
            }
        }

        // No special characters found
        return true;
    }

    function _checkVoteAddress(
        address operatorAddress,
        bytes calldata voteAddress,
        bytes calldata blsProof
    ) internal view returns (bool) {
        if (voteAddress.length != BLS_PUBKEY_LENGTH || blsProof.length != BLS_SIG_LENGTH) {
            return false;
        }

        // get msg hash
        bytes32 msgHash = keccak256(abi.encodePacked(operatorAddress, voteAddress, block.chainid));
        bytes memory msgBz = new bytes(32);
        assembly {
            mstore(add(msgBz, 32), msgHash)
        }

        // call the precompiled contract to verify the BLS signature
        // the precompiled contract's address is 0x66
        bytes memory input = bytes.concat(msgBz, blsProof, voteAddress); // length: 32 + 96 + 48 = 176
        bytes memory output = new bytes(1);
        assembly {
            let len := mload(input)
            if iszero(staticcall(not(0), 0x66, add(input, 0x20), len, add(output, 0x20), 0x01)) { revert(0, 0) }
        }
        uint8 result = uint8(output[0]);
        if (result != uint8(1)) {
            return false;
        }
        return true;
    }

    function _deployStakeCredit(address operatorAddress, string memory moniker) internal returns (address) {
        address creditProxy = address(new TransparentUpgradeableProxy(STAKE_CREDIT_ADDR, DEAD_ADDRESS, ""));
        IStakeCredit(creditProxy).initialize{ value: msg.value }(operatorAddress, moniker);
        emit StakeCreditInitialized(operatorAddress, creditProxy);

        return creditProxy;
    }

    function _checkValidatorSelfDelegation(address operatorAddress) internal {
        Validator storage valInfo = _validators[operatorAddress];
        if (valInfo.jailed) {
            return;
        }
        if (IStakeCredit(valInfo.creditContract).getPooledBNB(operatorAddress) < minSelfDelegationBNB) {
            _jailValidator(valInfo, block.timestamp + downtimeJailTime);
            IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).felony(valInfo.consensusAddress);
        }
    }

    function _checkFelonyRecord(address operatorAddress, SlashType slashType) internal returns (bool, uint256) {
        bytes32 slashKey = keccak256(abi.encodePacked(operatorAddress, slashType));
        uint256 jailUntil = _felonyRecords[slashKey];
        // for double sign and malicious vote slash
        // if the validator is already jailed, no need to slash again
        if (jailUntil > block.timestamp) {
            return (false, 0);
        }
        jailUntil = block.timestamp + felonyJailTime;
        _felonyRecords[slashKey] = jailUntil;
        return (true, jailUntil);
    }

    function _jailValidator(Validator storage valInfo, uint256 jailUntil) internal {
        IBSCValidatorSet(VALIDATOR_CONTRACT_ADDR).removeTmpMigratedValidator(valInfo.consensusAddress);

        // keep the last eligible validator
        bool isLast = (numOfJailed >= _validatorSet.length() - 1);
        if (isLast) {
            // If staking channel is closed, then BC-fusion is finished and we should keep the last eligible validator here
            if (
                !ICrossChain(CROSS_CHAIN_CONTRACT_ADDR).registeredContractChannelMap(
                    VALIDATOR_CONTRACT_ADDR, STAKING_CHANNELID
                )
            ) {
                emit ValidatorEmptyJailed(valInfo.operatorAddress);
                return;
            }
        }

        if (jailUntil > valInfo.jailUntil) {
            valInfo.jailUntil = jailUntil;
        }

        if (!valInfo.jailed) {
            valInfo.jailed = true;
            numOfJailed += 1;

            emit ValidatorJailed(valInfo.operatorAddress);
        }
    }

    function _claim(address operatorAddress, uint256 requestNumber) internal validatorExist(operatorAddress) {
        uint256 bnbAmount = IStakeCredit(_validators[operatorAddress].creditContract).claim(msg.sender, requestNumber);
        emit Claimed(operatorAddress, msg.sender, bnbAmount);
    }

    function _bep410MsgSender() internal view returns (address) {
        if (agentToOperator[msg.sender] != address(0)) {
            return agentToOperator[msg.sender];
        }

        return msg.sender;
    }
}
