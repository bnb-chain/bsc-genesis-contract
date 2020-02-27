pragma solidity ^0.5.15;

contract System {
  address public constant SYSTEM_ADDRESS = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;

  modifier onlySystem() {
    require(msg.sender == SYSTEM_ADDRESS, "the message sender must be system account");
    _;
  }
}
