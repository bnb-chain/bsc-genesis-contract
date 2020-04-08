pragma solidity 0.6.4;

import "../interface/IRelayerHub.sol";

contract MockRelayerHub is IRelayerHub {

  function isRelayer(address sender) external view returns (bool){
    return true;
  }
}
