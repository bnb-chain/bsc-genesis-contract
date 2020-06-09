pragma solidity 0.6.4;

interface ITokenHub {

  function getRelayFee() external returns(uint256, uint256);

  function transferOut(address contractAddr, address recipient, uint256 amount, uint64 expireTime)
    external payable returns (bool);

  /* solium-disable-next-line */
  function batchTransferOut(address[] calldata recipientAddrs, uint256[] calldata amounts, address[] calldata refundAddrs,
    address contractAddr, uint64 expireTime) external payable returns (bool);

}


