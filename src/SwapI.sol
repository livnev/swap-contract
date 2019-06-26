interface SwapSimple {
  function swapSimple(
    uint256 takeId,
    uint256 killId,
    uint256 expiry,
    address makerWallet,
    address makerToken,
    uint256 makerParam,
    address takerWallet,
    address takerToken,
    uint256 takerParam,
    address affiliateWallet,
    address affiliateToken,
    uint256 affiliateParam,
    address signer,
    bytes32 r,
    bytes32 s,
    uint8 v
    bytes1 version
  )
    external payable;
  function cancel(uint256[] calldata ids) external;
}
