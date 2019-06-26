pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

import "./Authorizable.sol";
import "./Transferable.sol";
import "./Verifiable.sol";


/**
* @title Atomic swap contract used by the Swap Protocol
*/
contract Swap is Authorizable, Transferable, Verifiable {

  byte constant private OPEN = 0x00;
  byte constant private TAKEN = 0x01;
  byte constant private CANCELED = 0x02;

  // Maps makers to orders by ID as TAKEN (0x01) or CANCELED (0x02)
  mapping (address => mapping (uint256 => byte)) public makerOrderStatus;

  // Emitted on Swap
  event Swap(
    uint256 indexed id,
    address indexed makerAddress,
    uint256 makerParam,
    address makerToken,
    address takerAddress,
    uint256 takerParam,
    address takerToken,
    address affiliateAddress,
    uint256 affiliateParam,
    address affiliateToken
  );

  // Emitted on Cancel
  event Cancel(
    uint256 indexed id,
    address indexed makerAddress
  );

  /**
    * @notice Atomic Token Swap
    * @dev Determines type (ERC-20 or ERC-721) with ERC-165
    *
    * @param order Order
    * @param signature Signature
    */
  function swap(
    Order calldata order,
    Signature calldata signature
  )
    external payable
  {

    // Ensure the order is not expired
    require(order.expiry > block.timestamp,
      "ORDER_EXPIRED");

    // Ensure the order has not already been taken
    require(makerOrderStatus[order.maker.wallet][order.id] != TAKEN,
      "ORDER_ALREADY_TAKEN");

    // Ensure the order has not already been canceled
    require(makerOrderStatus[order.maker.wallet][order.id] != CANCELED,
      "ORDER_ALREADY_CANCELED");

    // Ensure the order sender is authorized
    if (msg.sender != order.taker.wallet) {
      require(isAuthorized(order.taker.wallet, msg.sender),
        "SENDER_UNAUTHORIZED");
    }

    // Ensure the order signer is authorized
    require(isAuthorized(order.maker.wallet, signature.signer),
      "SIGNER_UNAUTHORIZED");

    // Ensure the order signature is valid
    require(isValid(order, signature),
      "SIGNATURE_INVALID");

    // Mark the order TAKEN (0x01)
    makerOrderStatus[order.maker.wallet][order.id] = TAKEN;

    // A null taker token is an order for ether
    if (order.taker.token == address(0)) {

      // Ensure the ether sent matches the taker param
      require(msg.value == order.taker.param,
        "VALUE_MUST_BE_SENT");

      // Transfer ether from taker to maker
      send(order.maker.wallet, msg.value);

    } else {

      // Ensure the value sent is zero
      require(msg.value == 0,
        "VALUE_MUST_BE_ZERO");

      // Transfer token from taker to maker
      safeTransferAny(
        "TAKER",
        order.taker.wallet,
        order.maker.wallet,
        order.taker.param,
        order.taker.token
      );

    }

    // Transfer token from maker to taker
    safeTransferAny(
      "MAKER",
      order.maker.wallet,
      order.taker.wallet,
      order.maker.param,
      order.maker.token
    );

    // Transfer token from maker to affiliate if specified
    if (order.affiliate.wallet != address(0)) {
      safeTransferAny(
        "MAKER",
        order.maker.wallet,
        order.affiliate.wallet,
        order.affiliate.param,
        order.affiliate.token
      );
    }

    emit Swap(order.id,
      order.maker.wallet, order.maker.param, order.maker.token,
      order.taker.wallet, order.taker.param, order.taker.token,
      order.affiliate.wallet, order.affiliate.param, order.affiliate.token
    );
  }

  /**
    * @notice Atomic Token Swap (Simple)
    * @dev Determines type (ERC-20 or ERC-721) with ERC-165
    *
    * @param id uint256
    * @param makerWallet address
    * @param makerParam uint256
    * @param makerToken address
    * @param takerWallet address
    * @param takerParam uint256
    * @param takerToken address
    * @param expiry uint256
    * @param r bytes32
    * @param s bytes32
    * @param v uint8
    */
  function swapSimple(
    uint256 id,
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
    external payable
  {

    // Ensure the order is not expired
    require(expiry > block.timestamp,
      "ORDER_EXPIRED");

    // Ensure the order has not already been taken or canceled
    require(makerOrderStatus[makerWallet][id] == OPEN,
      "ORDER_UNAVAILABLE");

    // Ensure the order sender is authorized
    if (msg.sender != takerWallet) {
      require(isAuthorized(takerWallet, msg.sender),
        "SENDER_UNAUTHORIZED");
    }

    // Ensure the order signature is valid
    require(isValidSimple(
      id,
      makerWallet,
      makerParam,
      makerToken,
      takerWallet,
      takerParam,
      takerToken,
      expiry,
      r, s, v
    ), "SIGNATURE_INVALID");

    // Mark the order TAKEN (0x01)
    makerOrderStatus[makerWallet][id] = TAKEN;

    // A null taker token is an order for ether
    if (takerToken == address(0)) {

      // Ensure the ether sent matches the taker param
      require(msg.value == takerParam,
        "VALUE_MUST_BE_SENT");

      // Transfer ether from taker to maker
      send(makerWallet, msg.value);

    } else {

      // Ensure the value sent is zero
      require(msg.value == 0,
        "VALUE_MUST_BE_ZERO");

      // Transfer token from taker to maker
      transferAny(takerToken, takerWallet, makerWallet, takerParam);

    }

    // Transfer token from maker to taker
    transferAny(makerToken, makerWallet, takerWallet, makerParam);

    emit Swap(id,
      makerWallet, makerParam, makerToken,
      takerWallet, takerParam, takerToken,
      address(0), 0, address(0)
    );

  }

  /** @notice Cancel a batch of orders
    * @dev Canceled orders are marked CANCELED (0x02)
    * @param ids uint256[]
    */
  function cancel(uint256[] calldata ids) external {
    for (uint256 i = 0; i < ids.length; i++) {
      if (makerOrderStatus[msg.sender][ids[i]] == OPEN) {
        makerOrderStatus[msg.sender][ids[i]] = CANCELED;
        emit Cancel(ids[i], msg.sender);
      }
    }
  }

}
