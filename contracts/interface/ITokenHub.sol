pragma solidity 0.6.4;

interface ITokenHub {

  function getRelayFee() external returns(uint256);

  function getContractAddrByBEP2Symbol(bytes32 bep2Symbol) external returns(address);

  function getBep2SymbolByContractAddr(address contractAddr) external returns(bytes32);

  function setBindMapping(bytes32 bep2Symbol, address contractAddr) external;

  function unsetBindMapping(bytes32 bep2Symbol, address contractAddr) external;

  function setContractAddrDecimals(address contractAddr, uint256 decimals) external;

  function transferOut(address contractAddr, address recipient, uint256 amount, uint64 expireTime)
    external payable returns (bool);

  /* solium-disable-next-line */
  function batchTransferOutBNB(address[] calldata recipientAddrs, uint256[] calldata amounts, address[] calldata refundAddrs,
    uint64 expireTime) external payable returns (bool);

}


