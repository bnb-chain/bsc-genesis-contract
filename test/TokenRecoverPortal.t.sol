pragma solidity ^0.8.10;

import "./utils/Deployer.sol";

interface ITokenRecoverPortal {
    // Returns the merkle root of the merkle tree containing account balances available to recover.
    function merkleRoot() external view returns (bytes32);
    // Returns the address of the contract that is allowed to confirm the recover.
    function approvalAddress() external view returns (address);
    // Returns the address of the contract that is allowed to pause the recover.
    function assetProtector() external view returns (address);
    // Returns true if the index has been marked recovered.
    function isRecovered(bytes32 index) external view returns (bool);
    // recover the given amount of the token to the given address. Reverts if the inputs are invalid.
    function recover(
        bytes32 tokenSymbol,
        uint256 amount,
        bytes calldata ownerPubKey,
        bytes calldata ownerSignature,
        bytes calldata approvalSignature,
        bytes32[] calldata merkleProof
    ) external;
    // Cancel the user token recover request by the assetProtector.
    function cancelTokenRecover(bytes32 tokenSymbol, address recipient) external;
}

contract TokenRecoverPortalTest is Deployer {
    using RLPEncode for *;

    receive() external payable { }

    address mockUser = address(0x2e9247B67ae885a8dcfBf77Eb6d0e93A32bea24C);
    bytes mockTokenOwner = hex"b713200f29effb427fb76a185b4ac73ea09a534b";
    bytes32 testTokenSymbol = hex"424e420000000000000000000000000000000000000000000000000000000000";

    address protector = address(0x5C7c4b3ee76D1eD8a4341Ab07D87a2a88d81454A);
    address approvalAddress = address(0xb26859a7321AB7B2025E5E6a425D697e2eacbFB1);
    bytes merkleRoot = hex"59bb94f7047904a8fdaec42e4785295167f7fd63742b309afeb84bd71f8e6554";

    function setUp() public {
        vm.mockCall(address(0x69), "", mockTokenOwner);
        // slot id for `merkleRootAlreadyInit`
        bytes32 slot = bytes32(uint256(105));

        // change `merkleRootAlreadyInit` to false
        vm.store(address(tokenRecoverPortal), slot, bytes32(uint256(0)));

        // check `merkleRootAlreadyInit` is false
        assertEq(tokenRecoverPortal.merkleRootAlreadyInit(), false);
    }

    function setUpContractParams(
        address newApprovalAddress,
        bytes memory newMerkleRoot,
        address newProtector
    ) internal {
        // set the approvalAddress, merkleRoot and tokenRecoverPortalProtector
        bytes memory key = "approvalAddress";
        bytes memory value = abi.encodePacked(newApprovalAddress);
        _updateParamByGovHub(key, value, address(tokenRecoverPortal));

        bytes memory key2 = "merkleRoot";
        bytes memory value2 = newMerkleRoot;
        _updateParamByGovHub(key2, value2, address(tokenRecoverPortal));

        bytes memory key3 = "tokenRecoverPortalProtector";
        bytes memory value3 = abi.encodePacked(newProtector);
        _updateParamByGovHub(key3, value3, address(tokenRecoverPortal));
    }

    function setUpCorrectContractParams() public {
        setUpContractParams(approvalAddress, merkleRoot, protector);
    }

    function setUpContractParamsWithWrongApprovelAddress() public {
        setUpContractParams(
            address(0x561319e67357fa3d2b51E58d011a80EB6268A0f5),
            hex"11111111047904a8fdaec42e4785295167f7fd63742b309afeb84bd71f8e6554",
            protector
        );
    }

    function setUpContractParamsWithWrongMerkleRoot() public {
        setUpContractParams(
            approvalAddress, hex"11111111047904a8fdaec42e4785295167f7fd63742b309afeb84bd71f8e6554", protector
        );
    }

    function recoverParams()
        internal
        view
        returns (bytes32, uint256, bytes memory, bytes memory, bytes memory, bytes32[] memory)
    {
        bytes32 tokenSymbol = testTokenSymbol;
        uint256 amount = 14188000000;
        bytes memory ownerPubKey = hex"036d5d41cd7da2e96d39bcbd0390bfed461a86382f7a2923436ff16c65cabc7719";
        bytes memory ownerSignature =
            hex"5f5391ba7f2b002b4746025f7e803a43e57a397ea66f3939d05302eb7851bbbc0773cda87aae0fbb1e2a29367b606209ed47dc5cba6d1a83f6b79cb70e56efdb";
        bytes memory approvalSignature =
            hex"52a0a5ca80beb068d82413cac31c1df0540dc6a61eddec9f31b94419e60b6c586e5342552f4c8034a00c876d640abea8c5ba9c4d72145d0e562fedd09fe1e00a01";
        bytes32[] memory merkleProof = new bytes32[](17);
        merkleProof[0] = hex"03719d7863e4aba727d7030e7a1916b9be2245d447eb71fc683d3ac0ded5eecd";
        merkleProof[1] = hex"7f9aa9d8246251cbab3cc642416dec81d074d39a85be6ca8326a05ac422e74ab";
        merkleProof[2] = hex"6debec5a4272951843cf24f74c30d5ccf1afec9aafbfc45d0b50cb4eb6f89c09";
        merkleProof[3] = hex"5cb2e4d880e2387764df4de9ce49cbabc41b6e4a07b1c2e1d9fc98957b6643d2";
        merkleProof[4] = hex"88c6195b4444035bef3212847f38822c0d509d811de8c9154e7f5f8ec3778b67";
        merkleProof[5] = hex"27c985cced25522043ded2fc8103baa24edc21b6c9f95c5bfff635ab36bdb29d";
        merkleProof[6] = hex"39a0fbfba925ebd0cf4f5fe5ab4c69eb18317fd1bd4373647a53dc339fb764a9";
        merkleProof[7] = hex"61300a7a7fe0932760c1e1edfa4d4450cc378d9b5c538dcb24ffbbc18f249fe5";
        merkleProof[8] = hex"4d49fcf8a1e0b72b535921dea8e02baac18df614e7f7c462749a2b14ee2737ef";
        merkleProof[9] = hex"c10261d3337346f921c4fef13ba1bcb46a531e947ce41c81e54404e970deaaf5";
        merkleProof[10] = hex"3536a24678835b0f7adeae1f27dae7d6bb22598fb8f8578ec0eef5ea5146f85b";
        merkleProof[11] = hex"925aab793d8080c4f8ea5034e195938c5550f7ba80acf7d7e7d8468f5b5dd70a";
        merkleProof[12] = hex"def2b6210654ac4f48b4556e24907e027e66729045d0c669a53c75a880477b48";
        merkleProof[13] = hex"4bb1aab890245e6a9e1e969ae3f6f0315ea073606fd6fabe9f3d7514c84fee98";
        merkleProof[14] = hex"e096d4b3669b1c7cd8fcff26b2b00029c09c0f38a34ae632b022622fb46ad69a";
        merkleProof[15] = hex"05e63b558cba63f5add60201151f96ff8f5370d2b8280a96b4fa8fd2d519ab9f";
        merkleProof[16] = hex"a2d456e52facaa953bfbc79a5a6ed7647dda59872b9b35c20183887eeb4640eb";

        return (tokenSymbol, amount, ownerPubKey, ownerSignature, approvalSignature, merkleProof);
    }

    function testRecoverFaildWithWrongApprovalAddress() public {
        setUpContractParamsWithWrongApprovelAddress();
        vm.prank(mockUser);

        (
            bytes32 tokenSymbol,
            uint256 amount,
            bytes memory ownerPubKey,
            bytes memory ownerSignature,
            bytes memory approvalSignature,
            bytes32[] memory merkleProof
        ) = recoverParams();

        vm.expectRevert();
        // failed to recover the token
        tokenRecoverPortal.recover(tokenSymbol, amount, ownerPubKey, ownerSignature, approvalSignature, merkleProof);
    }

    function testRecoverFaildWithWrongMerkleRoot() public {
        setUpContractParamsWithWrongMerkleRoot();
        vm.prank(mockUser);

        (
            bytes32 tokenSymbol,
            uint256 amount,
            bytes memory ownerPubKey,
            bytes memory ownerSignature,
            bytes memory approvalSignature,
            bytes32[] memory merkleProof
        ) = recoverParams();

        vm.expectRevert();
        // failed to recover the token
        tokenRecoverPortal.recover(tokenSymbol, amount, ownerPubKey, ownerSignature, approvalSignature, merkleProof);
    }

    function testRecoverFaildWithWrongRecipient() public {
        setUpCorrectContractParams();
        vm.prank(address(0x561319e67357fa3d2b51E58d011a80EB6268A0f5));

        (
            bytes32 tokenSymbol,
            uint256 amount,
            bytes memory ownerPubKey,
            bytes memory ownerSignature,
            bytes memory approvalSignature,
            bytes32[] memory merkleProof
        ) = recoverParams();

        vm.expectRevert();
        // failed to recover the token
        tokenRecoverPortal.recover(tokenSymbol, amount, ownerPubKey, ownerSignature, approvalSignature, merkleProof);
    }

    function testRecoverFaildWithWrongTokenSymbol() public {
        setUpCorrectContractParams();
        vm.prank(mockUser);

        (
            bytes32 tokenSymbol,
            uint256 amount,
            bytes memory ownerPubKey,
            bytes memory ownerSignature,
            bytes memory approvalSignature,
            bytes32[] memory merkleProof
        ) = recoverParams();

        tokenSymbol = hex"4241110000000000000000000000000000000000000000000000000000000000";
        vm.expectRevert();
        // failed to recover the token
        tokenRecoverPortal.recover(tokenSymbol, amount, ownerPubKey, ownerSignature, approvalSignature, merkleProof);
    }

    function testRecoverFaildWithWrongAmount() public {
        setUpCorrectContractParams();
        vm.prank(mockUser);

        (
            bytes32 tokenSymbol,
            uint256 amount,
            bytes memory ownerPubKey,
            bytes memory ownerSignature,
            bytes memory approvalSignature,
            bytes32[] memory merkleProof
        ) = recoverParams();

        amount = 188000001;
        vm.expectRevert();
        // failed to recover the token
        tokenRecoverPortal.recover(tokenSymbol, amount, ownerPubKey, ownerSignature, approvalSignature, merkleProof);
    }

    function testRecoverFaildWithWrongOwnerPubKey() public {
        setUpCorrectContractParams();
        vm.prank(mockUser);

        (
            bytes32 tokenSymbol,
            uint256 amount,
            bytes memory ownerPubKey,
            bytes memory ownerSignature,
            bytes memory approvalSignature,
            bytes32[] memory merkleProof
        ) = recoverParams();

        vm.expectRevert();
        vm.mockCall(address(0x69), "", hex"1111100f29effb427fb76a185b4ac73ea09a534b");
        ownerPubKey = hex"11111111cd7da2e96d39bcbd0390bfed461a86382f7a2923436ff16c65cabc7720";
        // failed to recover the token
        tokenRecoverPortal.recover(tokenSymbol, amount, ownerPubKey, ownerSignature, approvalSignature, merkleProof);
    }

    function testRecoverFaildWithWrongOwnerSignature() public {
        setUpCorrectContractParams();
        vm.prank(mockUser);

        (
            bytes32 tokenSymbol,
            uint256 amount,
            bytes memory ownerPubKey,
            bytes memory ownerSignature,
            bytes memory approvalSignature,
            bytes32[] memory merkleProof
        ) = recoverParams();

        ownerSignature =
            hex"111111117f2b002b4746025f7e803a43e57a397ea66f3939d05302eb7851bbbc0773cda87aae0fbb1e2a29367b606209ed47dc5cba6d1a83f6b79cb70e56efdb";
        vm.expectRevert();
        // failed to recover the token
        tokenRecoverPortal.recover(tokenSymbol, amount, ownerPubKey, ownerSignature, approvalSignature, merkleProof);
    }

    function testRecoverFaildWithWrongApprovalSignature() public {
        setUpCorrectContractParams();
        vm.prank(mockUser);

        (
            bytes32 tokenSymbol,
            uint256 amount,
            bytes memory ownerPubKey,
            bytes memory ownerSignature,
            bytes memory approvalSignature,
            bytes32[] memory merkleProof
        ) = recoverParams();

        approvalSignature =
            hex"1111111180beb068d82413cac31c1df0540dc6a61eddec9f31b94419e60b6c586e5342552f4c8034a00c876d640abea8c5ba9c4d72145d0e562fedd09fe1e00a02";
        vm.expectRevert();
        // failed to recover the token
        tokenRecoverPortal.recover(tokenSymbol, amount, ownerPubKey, ownerSignature, approvalSignature, merkleProof);
    }

    function testRecoverFaildWithWrongMerkleProof() public {
        setUpCorrectContractParams();
        vm.prank(mockUser);

        (
            bytes32 tokenSymbol,
            uint256 amount,
            bytes memory ownerPubKey,
            bytes memory ownerSignature,
            bytes memory approvalSignature,
            bytes32[] memory merkleProof
        ) = recoverParams();

        merkleProof[13] = hex"1111111190245e6a9e1e969ae3f6f0315ea073606fd6fabe9f3d7514c84fee98";
        vm.expectRevert();
        // failed to recover the token
        tokenRecoverPortal.recover(tokenSymbol, amount, ownerPubKey, ownerSignature, approvalSignature, merkleProof);
    }

    function testRecover() public {
        setUpCorrectContractParams();
        vm.prank(mockUser);

        (
            bytes32 tokenSymbol,
            uint256 amount,
            bytes memory ownerPubKey,
            bytes memory ownerSignature,
            bytes memory approvalSignature,
            bytes32[] memory merkleProof
        ) = recoverParams();

        // recover the token
        tokenRecoverPortal.recover(tokenSymbol, amount, ownerPubKey, ownerSignature, approvalSignature, merkleProof);

        // check if the token is recovered
        bytes32 node = keccak256(abi.encodePacked(mockTokenOwner, tokenSymbol, amount));
        assert(tokenRecoverPortal.isRecovered(node));
    }

    function testCancelTokenRecover() public {
        testRecover();
        vm.prank(protector);
        tokenRecoverPortal.cancelTokenRecover(testTokenSymbol, mockUser);
    }
}
