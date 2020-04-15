pragma solidity 0.6.4;

contract System {

   modifier onlySystem() {
       require(msg.sender == block.coinbase, "the message sender must be the block producer");
       _;
   }

}
