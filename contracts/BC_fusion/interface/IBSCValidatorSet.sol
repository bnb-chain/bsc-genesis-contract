// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IBSCValidatorSet {
    struct Validator {
        address consensusAddress;
        address payable feeAddress;
        address BBCFeeAddress;
        uint64 votingPower;
        bool jailed;
        uint256 incoming;
    }

    function jailValidator(address consensusAddress) external;
    function updateValidatorSetV2(Validator[] calldata validators, bytes[] calldata voteAddrs) external;
}
