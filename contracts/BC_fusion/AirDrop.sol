// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./interface/ITokenHub.sol";
import "./interface/IAirDrop.sol";
import "./System.sol";
import "./lib/Utils.sol";

/// @title AirDrop is used to claim the token from BC users.
/// @dev This is designed for the BC users to claim the token from TokenHub.
/// The BC will chain will stop and generate a merkle tree root after BC-fusion plan was started.
/// The BC users can claim the token from TokenHub after the merkle tree root is generated.
/// For more details, please refer to the BEP-299(https://github.com/bnb-chain/BEPs/pull/299).
contract AirDrop is IAirDrop, ReentrancyGuardUpgradeable, System {
    using Utils for string;
    using Utils for bytes;

    /*----------------- init paramters -----------------*/
    string public constant sourceChainID = "Binance-Chain-Ganges";
    address public approverAddress = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa;
    bytes32 public merkleRoot = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bool public merkleRootAlreadyInit = false;

    /*----------------- storage -----------------*/
    /// claimedMap is used to record the claimed token.
    mapping(bytes32 => bool) private claimedMap;

    /*----------------- permission control -----------------*/
    /// assetProtector is the address that is allowed to pause the claim.
    address public assetProtector = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa;
    /// blackList is the address that is not allowed to claim.
    mapping(address => bool) public blackList;
    /// paused is used to pause the claim.
    bool private _paused;

    modifier whenNotPaused() {
        if (_paused) revert AirDropPaused();
        _;
    }

    modifier onlyAssetProtector() {
        if (msg.sender != assetProtector) revert OnlyAssetProtector();
        _;
    }

    modifier notInBlackList() {
        if (blackList[msg.sender]) revert InBlackList();
        _;
    }

    modifier merkelRootReady() {
        if (!merkleRootAlreadyInit) revert MerkleRootNotInitialize();
        if (merkleRoot == bytes32(0)) revert MerkleRootNotInitialize();
        _;
    }

    function pause() external onlyAssetProtector {
        _paused = true;
        emit Paused();
    }

    function resume() external onlyAssetProtector {
        _paused = false;
        emit Resumed();
    }

    function addToBlackList(address account) external onlyAssetProtector {
        blackList[account] = true;
    }

    function removeFromBlackList(address account) external onlyAssetProtector {
        blackList[account] = false;
    }

    /*----------------- events -----------------*/
    /// This event is triggered whenever a call to #pause succeeds.
    event Paused();
    /// This event is triggered whenever a call to #pause succeeds.
    event Resumed();
    /// This event is triggered whenever a call to #claim succeeds.
    event Claimed(bytes32 tokenSymbol, address account, uint256 amount);

    /*----------------- errors -----------------*/
    error AlreadyClaimed();
    error InvalidProof();
    error InvalidApproverSignature();
    error InvalidOwnerPubKeyLength();
    error InvalidOwnerSignatureLength();
    error MerkleRootAlreadyInitiated();
    error MerkleRootNotInitialize();
    error AirDropPaused();
    error InBlackList();
    error OnlyAssetProtector();

    /// @isClaimed check if the token is claimed.
    /// @param node the leaf node of merkle tree.
    /// @return the result of check.
    function isClaimed(bytes32 node) public view override returns (bool) {
        return claimedMap[node];
    }

    /// @claim is used to claim the token from BC users.
    /// @dev The token will be unlocked from TokenHub after the signature and the merkel proof is verified.
    /// @param tokenSymbol is the symbol of token.
    /// @param amount is the amount of token.
    /// @param ownerPubKey is the secp256k1 public key of the token owner on BC.
    /// @param ownerSignature is the secp256k1 signature of the token owner on BC.
    /// @param approvalSignature is the eth_secp256k1 signature of the approver.
    /// @param merkleProof is the merkle proof of the token owner on BC.
    function claim(
        bytes32 tokenSymbol, uint256 amount,
        bytes calldata ownerPubKey, bytes calldata ownerSignature, bytes calldata approvalSignature,
        bytes32[] calldata merkleProof) merkelRootReady whenNotPaused notInBlackList nonReentrant external override {
        // Recover the owner address and check signature.
        bytes memory ownerAddr = _verifySecp256k1Sig(ownerPubKey, ownerSignature, _tmSignatureHash(tokenSymbol, amount, msg.sender));
        // Generate the leaf node of merkle tree.
        bytes32 node = keccak256(abi.encodePacked(ownerAddr, tokenSymbol, amount));
    
        // Check if the token is claimed.
        if (isClaimed(node)) revert AlreadyClaimed();
        
        // Verify the approval signature.
        _verifyApproverSig(msg.sender, ownerSignature, approvalSignature, node, merkleProof);
    
        // Verify the merkle proof.
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) revert InvalidProof();
    
        // Mark it claimed and send the token.
        claimedMap[node] = true;
        
        // Unlock the token from TokenHub.
        ITokenHub(TOKEN_HUB_ADDR).unlock(tokenSymbol, msg.sender, amount);

        emit Claimed(tokenSymbol, msg.sender, amount);
    }

    /// @verifyApproverSig is used to verify the approver signature.
    /// @dev The signature is generated by the approver address(need to call a aridrop backend service).
    function _verifyApproverSig(address account, bytes memory ownerSignature, bytes memory approvalSignature, bytes32 leafHash, bytes32[] memory merkleProof) internal view {
        bytes memory buffer;
        for (uint i = 0; i < merkleProof.length; i++) {
            buffer = abi.encodePacked(buffer, merkleProof[i]);
        }
        // Perform the approvalSignature recovery and ensure the recovered signer is the approval account
        bytes32 hash = keccak256(abi.encodePacked(sourceChainID, account, ownerSignature, leafHash, merkleRoot, buffer));
        if (ECDSA.recover(hash, approvalSignature) != approverAddress) revert InvalidApproverSignature();
    }

    /// @verifySecp256k1Sig is used to verify the secp256k1 signature from BC token owner.
    /// @dev The signature is generated by the token owner by BC tool.
    function _verifySecp256k1Sig(bytes memory pubKey, bytes memory signature, bytes32 messageHash) internal view returns (bytes memory) {
        // Ensure the public key is valid
        if (pubKey.length != 33) revert InvalidOwnerPubKeyLength();
        // Ensure the signature length is correct
        if (signature.length != 64) revert InvalidOwnerSignatureLength();

        // assemble input data
        bytes memory input = new bytes(129);
        Utils.bytesConcat(input, pubKey, 0, 33);
        Utils.bytesConcat(input, signature, 33, 64);
        Utils.bytesConcat(input, abi.encodePacked(messageHash), 97, 32);


        bytes memory output = new bytes(20);
        /* solium-disable-next-line */
        assembly {
          // call tmSignatureRecover precompile contract
          // Contract address: 0x69
          // input:
          // | tmPubKey | tmSignature  |  tmSignatureMsgHash  |
          // | 33 bytes |  64 bytes    |       32 bytes       |
          // output:
          // | recovered address  |
          // | 20 bytes |
          let len := mload(input)
          if iszero(staticcall(not(0), 0x69, input, len, output, 20)) {
            revert(0, 0)
          }
        }
        
        // return the recovered address
        return output;
    }

    /// @tmSignatureHash is used to generate the hash of the owner signature.
    /// @dev The hash is used to verify the signature from BC token owner.
    function _tmSignatureHash(
        bytes32 tokenSymbol,
        uint256 amount,
        address recipient
    ) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(
            '{"account_number":"0","chain_id":"',
            sourceChainID,
            '","data":null,"memo":"","msgs":[{"amount":"',
            Utils.bytesToHex(abi.encodePacked(amount), false),
            '","recipient":"',
            Utils.bytesToHex(abi.encodePacked(recipient), true),
            '","token_symbol":"',
            Utils.bytesToHex(abi.encodePacked(tokenSymbol), false),
            '"}],"sequence":"0","source":"0"}'
        ));
    }

    /// @updateParam is used to update the paramters of AirDrop.
    /// @dev The paramters can only be updated by the governor.
    /// @param key is the key of the paramter.
    /// @param value is the value of the paramter.
    function updateParam(string calldata key, bytes calldata value) external onlyGov{
        if (key.compareStrings("approverAddress")) {
            if (value.length != 20) revert InvalidValue(key, value);
            address newApprovalAddress = Utils.bytesToAddress(value, 20);
            if (newApprovalAddress == address(0)) revert InvalidValue(key, value);
            approverAddress = newApprovalAddress;
        } else if (key.compareStrings("merkleRoot")) {
            if (merkleRootAlreadyInit) revert MerkleRootAlreadyInitiated();
            if (value.length != 32) revert InvalidValue(key, value);
            bytes32 newMerkleRoot = 0;
            Utils.bytesToBytes32(32 ,value, newMerkleRoot);
            if (newMerkleRoot == bytes32(0)) revert InvalidValue(key, value);
            merkleRoot = newMerkleRoot;
            merkleRootAlreadyInit = true;
        } else if (key.compareStrings("assetProtector")) {
            if (value.length != 20) revert InvalidValue(key, value);
            address newAssetProtector = value.bytesToAddress(20);
            if (newAssetProtector == address(0)) revert InvalidValue(key, value);
            assetProtector = newAssetProtector;
        }else {
            revert UnknownParam(key, value);
        }
        emit ParamChange(key,value);
    }
}