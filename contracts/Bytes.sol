pragma solidity 0.5.16;

library Bytes {

    uint internal constant BYTES_HEADER_SIZE = 32;

    function concat(bytes memory self, bytes memory other) internal pure returns (bytes memory) {
        bytes memory ret = new bytes(self.length + other.length);
        uint src;
        uint srcLen;
        (src, srcLen) = Memory.fromBytes(self);

        uint src2;
        uint src2Len;
        (src2, src2Len) = Memory.fromBytes(other);

        uint dest;
        uint destLen;
        (dest,destLen) = Memory.fromBytes(ret);

        uint dest2 = dest + srcLen;
        Memory.copy(src, dest, srcLen);
        Memory.copy(src2, dest2, src2Len);
        return ret;
    }

}