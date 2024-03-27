// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./System.sol";
import "./extension/Protectable.sol";
import "./interface/ITokenHub.sol";
import "./interface/ITokenRecoverPortal.sol";
import "./lib/Utils.sol";

/**
 * @title TokenRecoverPortal is used to recover the token from BC users.
 * @dev This is designed for the BC users to recover the token from TokenHub.
 * The BC chain will stop and generate a merkle tree root after BC-fusion plan was started.
 * The BC users can recover the token from TokenHub after the merkle tree root is generated.
 * For more details, please refer to the BEP-299(https://github.com/bnb-chain/BEPs/pull/299).
 */
contract TokenRecoverPortal is System, Initializable, ReentrancyGuardUpgradeable, Protectable {
    using Utils for string;
    using Utils for bytes;

    /*----------------- constants -----------------*/
    // SOURCE_CHAIN_ID is the original chain ID of BC
    // This will be replaced based on the deployment network
    // Mainnet: "Binance-Chain-Tigris"
    // Testnet: "Binance-Chain-Ganges"
    // Rendering script: scripts/generate.py:238
    string public constant SOURCE_CHAIN_ID = "Binance-Chain-Ganges";

    /*----------------- storage -----------------*/
    address public approvalAddress;
    bytes32 public merkleRoot;
    bool public merkleRootAlreadyInit;

    // recoveredMap is used to record the recovered token.
    mapping(bytes32 => bool) private recoveredMap;

    modifier merkelRootReady() {
        if (!merkleRootAlreadyInit) revert MerkleRootNotInitialized();
        if (merkleRoot == bytes32(0)) revert MerkleRootNotInitialized();
        _;
    }

    modifier approvalAddressInit() {
        if (approvalAddress == address(0)) revert ApprovalAddressNotInitialized();
        _;
    }

    /*----------------- errors -----------------*/
    // @notice signature: 0x3e493100
    error AlreadyRecovered();
    // @notice signature: 0x09bde339
    error InvalidProof();
    // @notice signature: 0xad60149e
    error InvalidApprovalSignature();
    // @notice signature: 0x8152ea1b
    error InvalidOwnerPubKeyLength();
    // @notice signature: 0xbc97af2e
    error InvalidOwnerSignatureLength();
    // @notice signature: 0xf36660de
    error MerkleRootAlreadyInitiated();
    // @notice signature: 0xcf1ec32e
    error MerkleRootNotInitialized();
    // @notice signature: 0xc629ac81
    error TokenRecoverPortalPaused();
    // @notice signature: 0xd0dcbbd8
    error ApprovalAddressNotInitialized();

    /*----------------- events -----------------*/
    // This event is triggered whenever a call to #recover succeeds.
    event TokenRecoverRequested(bytes ownerAddress, bytes32 tokenSymbol, address account, uint256 amount);

    /*----------------- init -----------------*/
    function initialize() external initializer onlyCoinbase onlyZeroGasPrice {
        __ReentrancyGuard_init_unchained();

        // Different address will be set depending on the environment
        __Protectable_init_unchained(0x08E68Ec70FA3b629784fDB28887e206ce8561E08);
    }

    /**
     * isRecovered check if the token is recovered.
     * @param node the leaf node of merkle tree.
     * @return the result of check.
     */
    function isRecovered(bytes32 node) public view returns (bool) {
        return recoveredMap[node];
    }

    /**
     * For the Beacon Chain account whose funds are not transferred to BSC before BC fusion,
     * can still invoke this function to recover funds on the BSC network.
     * @dev The token will be locked in TokenHub after the signature and the merkel proof is verified.
     * @notice The token will be unlocked after 7 days.
     * @param tokenSymbol is the symbol of token.
     * @param amount is the amount of token.
     * @param ownerPubKey is the secp256k1 public key of the token owner on BC.
     * @param ownerSignature is the secp256k1 signature of the token owner on BC.
     * @param approvalSignature is the eth_secp256k1 signature of the approval.
     * @param merkleProof is the merkle proof of the token owner on BC.
     */
    function recover(
        bytes32 tokenSymbol,
        uint256 amount,
        bytes calldata ownerPubKey,
        bytes calldata ownerSignature,
        bytes calldata approvalSignature,
        bytes32[] calldata merkleProof
    ) external merkelRootReady approvalAddressInit whenNotPaused nonReentrant {
        // Recover the owner address and check signature.
        bytes memory ownerAddr =
            _verifySecp256k1Sig(ownerPubKey, ownerSignature, _tmSignatureHash(tokenSymbol, amount, msg.sender));
        // Generate the leaf node of merkle tree.
        bytes32 node = keccak256(abi.encodePacked(ownerAddr, tokenSymbol, amount));

        // Check if the token is recovered.
        if (isRecovered(node)) revert AlreadyRecovered();

        // Verify the approval signature.
        _verifyApprovalSig(msg.sender, ownerSignature, approvalSignature, node, merkleProof);

        // Verify the merkle proof.
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert InvalidProof();

        // Mark it recovered.
        recoveredMap[node] = true;

        // recover the token from TokenHub contract. it will be unlocked after 7 days.
        ITokenHub(TOKEN_HUB_ADDR).recoverBCAsset(tokenSymbol, msg.sender, amount);

        emit TokenRecoverRequested(ownerAddr, tokenSymbol, msg.sender, amount);
    }

    /**
     * verifyApprovalSig is used to verify the approval signature.
     * @dev The signature is generated by the approval address(need to call a token recovery backend service).
     */
    function _verifyApprovalSig(
        address account,
        bytes memory ownerSignature,
        bytes memory approvalSignature,
        bytes32 leafHash,
        bytes32[] memory merkleProof
    ) internal view {
        bytes memory buffer;
        for (uint256 i = 0; i < merkleProof.length; i++) {
            buffer = abi.encodePacked(buffer, merkleProof[i]);
        }
        // Perform the approvalSignature recovery and ensure the recovered signer is the approval account
        bytes32 hash =
            keccak256(abi.encodePacked(SOURCE_CHAIN_ID, account, ownerSignature, leafHash, merkleRoot, buffer));

        if (recover(approvalSignature, hash) != approvalAddress) revert InvalidApprovalSignature();
    }

    function recover(bytes memory sig, bytes32 hash) internal pure returns (address) {
        // Ensure the signature length is correct
        if (sig.length != 65) revert InvalidApprovalSignature();
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        if (v < 27) v += 27;
        if (v < 27 || v > 28) revert InvalidApprovalSignature();
        (address signer,) = ECDSA.tryRecover(hash, v, r, s);
        return signer;
    }

    /**
     * verifySecp256k1Sig is used to verify the secp256k1 signature from BC token owner.
     * @dev The signature is generated by the token owner by BC tool.
     */
    function _verifySecp256k1Sig(
        bytes memory pubKey,
        bytes memory signature,
        bytes32 messageHash
    ) internal view returns (bytes memory) {
        // Ensure the public key is valid
        if (pubKey.length != 33) revert InvalidOwnerPubKeyLength();
        // Ensure the signature length is correct
        if (signature.length != 64) revert InvalidOwnerSignatureLength();

        // assemble input data
        bytes memory msgBz = new bytes(32);
        assembly {
            mstore(add(msgBz, 32), messageHash)
        }
        bytes memory input = bytes.concat(pubKey, signature, msgBz);
        bytes memory output = new bytes(20);
        /* solium-disable-next-line */
        assembly {
            // call Secp256k1SignatureRecover precompile contract
            // Contract address: 0x69
            // input:
            // | PubKey | Signature  |  SignatureMsgHash  |
            // | 33 bytes |  64 bytes    |       32 bytes       |
            // output:
            // | recovered address  |
            // | 20 bytes |
            let len := mload(input)
            if iszero(staticcall(not(0), 0x69, add(input, 0x20), len, add(output, 0x20), 20)) { revert(0, 0) }
        }

        // return the recovered address
        return output;
    }

    /**
     * tmSignatureHash is used to generate the hash of the owner signature.
     * @dev The hash is used to verify the signature from BC token owner.
     */
    function _tmSignatureHash(bytes32 tokenSymbol, uint256 amount, address recipient) internal pure returns (bytes32) {
        return sha256(
            abi.encodePacked(
                '{"account_number":"0","chain_id":"',
                SOURCE_CHAIN_ID,
                '","data":null,"memo":"","msgs":[{"amount":"',
                Utils.bytesToHex(abi.encodePacked(amount), false),
                '","recipient":"',
                Utils.bytesToHex(abi.encodePacked(recipient), true),
                '","token_symbol":"',
                Utils.bytesToHex(abi.encodePacked(tokenSymbol), false),
                '"}],"sequence":"0","source":"0"}'
            )
        );
    }

    /**
     * updateParam is used to update the parameters of TokenRecoverPortal.
     * @dev The parameters can only be updated by the governor.
     * @param key is the key of the parameter.
     * @param value is the value of the parameter.
     */
    function updateParam(string calldata key, bytes calldata value) external onlyGov {
        if (key.compareStrings("approvalAddress")) {
            if (value.length != 20) revert InvalidValue(key, value);
            address newApprovalAddress = value.bytesToAddress(20);
            if (newApprovalAddress == address(0)) revert InvalidValue(key, value);
            approvalAddress = newApprovalAddress;
        } else if (key.compareStrings("merkleRoot")) {
            if (merkleRootAlreadyInit) revert MerkleRootAlreadyInitiated();
            if (value.length != 32) revert InvalidValue(key, value);
            bytes32 newMerkleRoot = value.bytesToBytes32(32);
            if (newMerkleRoot == bytes32(0)) revert InvalidValue(key, value);
            merkleRoot = newMerkleRoot;
            merkleRootAlreadyInit = true;
        } else if (key.compareStrings("tokenRecoverPortalProtector")) {
            if (value.length != 20) revert InvalidValue(key, value);
            address newTokenRecoverPortalProtector = value.bytesToAddress(20);
            if (newTokenRecoverPortalProtector == address(0)) revert InvalidValue(key, value);
            _setProtector(newTokenRecoverPortalProtector);
        } else {
            revert UnknownParam(key, value);
        }
        emit ParamChange(key, value);
    }

    /**
     * cancelTokenRecover is used to cancel the recovery request.
     * @dev The token recover request can only be canceled by the assetProtector.
     * @param tokenSymbol is the symbol of token.
     * @param attacker is the address of the attacker.
     */
    function cancelTokenRecover(bytes32 tokenSymbol, address attacker) external onlyProtector {
        ITokenHub(TOKEN_HUB_ADDR).cancelTokenRecoverLock(tokenSymbol, attacker);
    }
}
