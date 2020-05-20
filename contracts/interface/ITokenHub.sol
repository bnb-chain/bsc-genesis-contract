pragma solidity 0.6.4;

interface ITokenHub {

  function handleBindPackage(bytes calldata msgBytes, bytes calldata proof, uint64 height, uint64 packageSequence)
    external returns (bool);

  function handleTransferInPackage(bytes calldata msgBytes, bytes calldata proof, uint64 height, uint64 packageSequence)
    external returns (bool);

  function handleRefundPackage(bytes calldata msgBytes, bytes calldata proof, uint64 height, uint64 packageSequence)
    external returns (bool);

  function transferOut(address contractAddr, address recipient, uint256 amount, uint256 expireTime, uint256 relayFee)
    external payable returns (bool);

  /* solium-disable-next-line */
  function batchTransferOut(address[] calldata recipientAddrs, uint256[] calldata amounts, address[] calldata refundAddrs,
    address contractAddr, uint256 expireTime, uint256 relayFee) external payable returns (bool);

}


