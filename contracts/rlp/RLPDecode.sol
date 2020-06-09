pragma solidity 0.6.4;

/**
 * @title RLPReader
 * @dev RLPReader is used to read and parse RLP encoded data in memory.
 * @author Andreas Olofsson (androlo1980@gmail.com)
 */


library RLPDecode {
    uint constant DATA_SHORT_START = 0x80;
    uint constant DATA_LONG_START = 0xB8;
    uint constant LIST_SHORT_START = 0xC0;
    uint constant LIST_LONG_START = 0xF8;

    uint constant DATA_LONG_OFFSET = 0xB7;
    uint constant LIST_LONG_OFFSET = 0xF7;



    struct RLPItem {
        uint _unsafeMemPtr;    // Pointer to the RLP-encoded bytes.
        uint _unsafeLength;    // Number of bytes. This is the full length of the string.
    }

    struct Iterator {
        RLPItem _unsafeItem;   // Item that's being iterated over.
        uint _unsafeNextPtr;   // Position of the next item in the list.
    }

    function toRLPItem(bytes memory self) internal pure returns (RLPItem memory) {
        uint len = self.length;
        uint memPtr;
        assembly {
            memPtr := add(self, 0x20)
        }
        return RLPItem(memPtr, len);
    }

    function toList(RLPItem memory self, uint256 numItems) internal pure returns (RLPItem[] memory list) {
        list = new RLPItem[](numItems);
        Iterator memory it = iterator(self);
        uint idx;
        while (idx < numItems) {
            list[idx] = next(it);
            idx++;
        }
    }

    function toUint(RLPItem memory self) internal pure returns (uint data) {
        (uint rStartPos, uint len) = _decode(self);
        assembly {
            data := div(mload(rStartPos), exp(256, sub(32, len)))
        }
    }

    function toAddress(RLPItem memory self) internal pure returns (address data)
    {
        (uint rStartPos,) = _decode(self);
        assembly {
            data := div(mload(rStartPos), exp(256, 12))
        }
    }

    function iterator(RLPItem memory self) private pure returns (Iterator memory it) {
        uint ptr = self._unsafeMemPtr + _payloadOffset(self);
        it._unsafeItem = self;
        it._unsafeNextPtr = ptr;
    }


    function next(Iterator memory self) private pure returns (RLPItem memory subItem) {
        uint ptr = self._unsafeNextPtr;
        uint itemLength = _itemLength(ptr);
        subItem._unsafeMemPtr = ptr;
        subItem._unsafeLength = itemLength;
        self._unsafeNextPtr = ptr + itemLength;
    }

    function hasNext(Iterator memory self) private pure returns (bool) {
        RLPItem memory item = self._unsafeItem;
        return self._unsafeNextPtr < item._unsafeMemPtr + item._unsafeLength;
    }

    // Get the payload offset.
    function _payloadOffset(RLPItem memory self) private pure returns (uint)
    {
        uint b0;
        uint memPtr = self._unsafeMemPtr;
        assembly {
            b0 := byte(0, mload(memPtr))
        }
        if (b0 < DATA_SHORT_START)
            return 0;
        if (b0 < DATA_LONG_START || (b0 >= LIST_SHORT_START && b0 < LIST_LONG_START))
            return 1;
        if (b0 < LIST_SHORT_START)
            return b0 - DATA_LONG_OFFSET + 1;
        return b0 - LIST_LONG_OFFSET + 1;
    }

    // Get the full length of an RLP item.
    function _itemLength(uint memPtr) private pure returns (uint len) {
        uint b0;
        assembly {
            b0 := byte(0, mload(memPtr))
        }
        if (b0 < DATA_SHORT_START)
            len = 1;
        else if (b0 < DATA_LONG_START)
            len = b0 - DATA_SHORT_START + 1;
    }

    // Get start position and length of the data.
    function _decode(RLPItem memory self) private pure returns (uint memPtr, uint len) {
        uint b0;
        uint start = self._unsafeMemPtr;
        assembly {
            b0 := byte(0, mload(start))
        }
        if (b0 < DATA_SHORT_START) {
            memPtr = start;
            len = 1;
            return (memPtr, len);
        }
        if (b0 < DATA_LONG_START) {
            len = self._unsafeLength - 1;
            memPtr = start + 1;
        } else {
            uint bLen;
            assembly {
                bLen := sub(b0, 0xB7) // DATA_LONG_OFFSET
            }
            len = self._unsafeLength - 1 - bLen;
            memPtr = start + bLen + 1;
        }
        return (memPtr, len);
    }

    function toBytes(RLPItem memory self) internal pure returns (bytes memory bts) {
        uint len = self._unsafeLength;
        if (len == 0)
            return bts;
        bts = new bytes(len);
        _copyToBytes(self._unsafeMemPtr, bts, len);
    }

    // Assumes that enough memory has been allocated to store in target.
    function _copyToBytes(uint btsPtr, bytes memory tgt, uint btsLen) private pure {
        // Exploiting the fact that 'tgt' was the last thing to be allocated,
        // we can write entire words, and just overwrite any excess.
        assembly {
            {
            // evm operations on words
                let words := div(add(btsLen, 31), 32)
                let rOffset := btsPtr
                let wOffset := add(tgt, 0x20)
                for
                { let i := 0 } // start at arr + 0x20 -> first byte corresponds to length
                lt(i, words)
                { i := add(i, 1) }
                {
                    let offset := mul(i, 0x20)
                    mstore(add(wOffset, offset), mload(add(rOffset, offset)))
                }
                mstore(add(tgt, add(0x20, mload(tgt))), 0)
            }
        }
    }
}