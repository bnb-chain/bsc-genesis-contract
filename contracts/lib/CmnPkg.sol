pragma solidity 0.6.4;

import "./RLPEncode.sol";
import "./RLPDecode.sol";

library CmnPkg {

    using RLPEncode for *;
    using RLPDecode for *;


    struct CommonAckPackage {
        uint32 code;
    }

    function encodeCommonAckPackage(uint32 code) internal pure returns (bytes memory) {
        bytes[] memory elements = new bytes[](1);
        elements[0] = uint256(code).encodeUint();
        return elements.encodeList();
    }

    function decodeCommonAckPackage(bytes memory msgBytes) internal pure returns (CommonAckPackage memory, bool) {
        CommonAckPackage memory ackPkg;
        RLPDecode.Iterator memory iter = msgBytes.toRLPItem().iterator();

        bool success = false;
        uint256 idx=0;
        while (iter.hasNext()) {
            if (idx == 0) {
                ackPkg.code = uint32(iter.next().toUint());
                success = true;
            } else {
                break;
            }
            idx++;
        }
        return (ackPkg, success);
    }
}