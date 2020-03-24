pragma solidity 0.5.16;

interface ITokenHub {

  function handleBindPackage(uint64 height, bytes calldata key, bytes calldata value, bytes calldata proof) external returns (bool);

  function handleTransferInPackage(uint64 height, bytes calldata key, bytes calldata value, bytes calldata proof) external returns (bool);

  function handleRefundPackage(uint64 height, bytes calldata key, bytes calldata value, bytes calldata proof) external returns (bool);

  function transferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime, uint256 relayFee) external payable returns (bool);

  function batchTransferOut(address[] calldata recipientAddrs, uint256[] calldata amounts, address[] calldata refundAddrs, address contractAddr, uint256 expireTime, uint256 relayFee) external payable returns (bool);

}


