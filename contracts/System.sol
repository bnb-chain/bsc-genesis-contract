pragma solidity ^0.5.16;

contract System {
  address public constant SYSTEM_ADDRESS = 0x9fB29AAc15b9A4B7F17c3385939b007540f4d791;

  modifier onlySystem() {
    require(msg.sender == SYSTEM_ADDRESS, "the message sender must be system account");
    _;
  }
}
