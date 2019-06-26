interface SwapSimple {
  function swapSimple(
    uint256 takeId,
    uint256 killId,
    address makerWallet,
    uint256 makerParam,
    address makerToken,
    address takerWallet,
    uint256 takerParam,
    address takerToken,
    uint256 expiry,
    bytes32 r,
    bytes32 s,
    uint8 v
  )
    external payable;
  function cancel(uint256[] calldata ids) external;
}
