pragma solidity ^0.8.10;

interface MockTokenHub {
    function batchTransferOutBNB(address[] memory, uint256[] memory, address[] memory, uint64)
        external
        payable
        returns (bool);
    function bindToken(bytes32 bep2Symbol, address contractAddr, uint256 decimals) external;
    function getBep2SymbolByContractAddr(address contractAddr) external view returns (bytes32);
    function getContractAddrByBEP2Symbol(bytes32 bep2Symbol) external view returns (address);
    function getMiniRelayFee() external view returns (uint256);
    function setPanicBatchTransferOut(bool doPanic) external;
    function transferOut(address, address, uint256, uint64) external payable returns (bool);
    function unbindToken(bytes32 bep2Symbol, address contractAddr) external;
    function withdrawStakingBNB(uint256 amount) external returns (bool);
}
