pragma solidity 0.6.4;

import "./System.sol";
import "./interface/0.6.x/IParamSubscriber.sol";
import "./interface/0.6.x/IApplication.sol";

contract GovHub is System, IApplication {
    uint32 public constant ERROR_TARGET_NOT_CONTRACT = 101;
    uint32 public constant ERROR_TARGET_CONTRACT_FAIL = 102;

    event failReasonWithStr(string message);
    event failReasonWithBytes(bytes message);
    event paramChange(string key, bytes value);  // @dev deprecated

    struct ParamChangePackage {
        string key;
        bytes value;
        address target;
    }

    function handleSynPackage(
        uint8,
        bytes calldata msgBytes
    ) external override onlyCrossChainContract returns (bytes memory responsePayload) {
        revert("deprecated");
    }

    // should not happen
    function handleAckPackage(uint8, bytes calldata) external override onlyCrossChainContract {
        revert("deprecated");
    }

    // should not happen
    function handleFailAckPackage(uint8, bytes calldata) external override onlyCrossChainContract {
        revert("deprecated");
    }

    function updateParam(string calldata key, bytes calldata value, address target) external onlyGovernorTimelock {
        ParamChangePackage memory proposal = ParamChangePackage(key, value, target);
        notifyUpdates(proposal);
    }

    function notifyUpdates(ParamChangePackage memory proposal) internal returns (uint32) {
        if (!isContract(proposal.target)) {
            emit failReasonWithStr("the target is not a contract");
            return ERROR_TARGET_NOT_CONTRACT;
        }
        try IParamSubscriber(proposal.target).updateParam(proposal.key, proposal.value) { }
        catch Error(string memory reason) {
            emit failReasonWithStr(reason);
            return ERROR_TARGET_CONTRACT_FAIL;
        } catch (bytes memory lowLevelData) {
            emit failReasonWithBytes(lowLevelData);
            return ERROR_TARGET_CONTRACT_FAIL;
        }
        return CODE_OK;
    }
}
