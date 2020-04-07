pragma solidity 0.6.4;

import "../interface/ITokenHub.sol";

contract MockTokenHub is ITokenHub {

  function handleBindPackage(uint64, uint64, bytes calldata, bytes calldata)
  external override(ITokenHub) returns (bool) {
    return true;
  }

  function handleTransferInPackage(uint64, uint64, bytes calldata, bytes calldata)
  external override(ITokenHub) returns (bool) {
    return true;
  }

  function handleRefundPackage(uint64, uint64, bytes calldata, bytes calldata)
  external override(ITokenHub) returns (bool) {
    return true;
  }

  function transferOut(address, address, uint256, uint256, uint256)
  external override(ITokenHub) payable returns (bool) {
    return true;
  }

  /* solium-disable-next-line */
  function batchTransferOut(address[] calldata, uint256[] calldata, address[] calldata,
    address, uint256, uint256) external override(ITokenHub) payable returns (bool) {
    return true;
  }
}


