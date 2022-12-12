pragma solidity ^0.8.10;

interface MockRelayerHub {
    function isRelayer(address) external view returns (bool);
}
