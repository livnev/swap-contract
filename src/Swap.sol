pragma solidity 0.5.9;
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
  // n.b. that takeId and killId are two separate parameters of an order,
  // but if you set them to be the same then you recover the old behaviour,
  // and setting them to different values enables O(1) mass cancels.
  mapping (address => mapping (uint256 => byte)) public makerOrderStatus;

  // Emitted on Swap
  event Swap(
    uint256 indexed takeId,
    address indexed makerAddress,
    uint256 makerParam,
    address makerToken,
    address takerAddress,
    uint256 takerParam,
    address takerToken,
    address affiliateAddress,
    uint256 affiliateParam,
    address affiliateToken,
    uint256 killId
  );

  // Emitted on Cancel
  event Cancel(
    uint256 indexed killId,
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
    require(makerOrderStatus[order.maker.wallet][order.takeId] != TAKEN,
      "ORDER_ALREADY_TAKEN");

    // Ensure the order has not already been canceled
    require(makerOrderStatus[order.maker.wallet][order.killId] != CANCELED,
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
    makerOrderStatus[order.maker.wallet][order.takeId] = TAKEN;

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

    emit Swap(order.takeId,
      order.maker.wallet, order.maker.param, order.maker.token,
      order.taker.wallet, order.taker.param, order.taker.token,
      order.affiliate.wallet, order.affiliate.param, order.affiliate.token,
      order.killId);
  }

  /**
    * @notice Atomic Token Swap (Simple)
    * @dev Determines type (ERC-20 or ERC-721) with ERC-165
    *
    * @param order Order
    * @param signature Signature
    */
  function swapSimple(
    Order calldata order,
    Signature calldata signature
  )
    external payable
  {

    // Ensure the order is not expired
    require(order.expiry > block.timestamp,
      "ORDER_EXPIRED");

    // Ensure the order has not already been taken
    require(makerOrderStatus[order.maker.wallet][order.takeId] != TAKEN,
      "ORDER_ALREADY_TAKEN");

    // Ensure the order has not already been canceled
    require(makerOrderStatus[order.maker.wallet][order.killId] != CANCELED,
      "ORDER_ALREADY_CANCELED");

    // Ensure the order sender is authorized
    if (msg.sender != order.taker.wallet) {
      require(isAuthorized(order.taker.wallet, msg.sender),
        "SENDER_UNAUTHORIZED");
    }

    // Ensure the order signature is valid
    require(isValidSimple(
      order.takeId,
      order.killId,
      order.maker.wallet,
      order.maker.param,
      order.maker.token,
      order.taker.wallet,
      order.taker.param,
      order.taker.token,
      order.expiry,
      signature.r,
      signature.s,
      signature.v
    ), "SIGNATURE_INVALID");

    // Mark the order TAKEN (0x01)
    makerOrderStatus[order.maker.wallet][order.takeId] = TAKEN;

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
      transferAny(order.taker.token, order.taker.wallet, order.maker.wallet, order.taker.param);

    }

    // Transfer token from maker to taker
    transferAny(order.maker.token, order.maker.wallet, order.taker.wallet, order.maker.param);

    emit Swap(order.takeId,
      order.maker.wallet, order.maker.param, order.maker.token,
      order.taker.wallet, order.taker.param, order.taker.token,
      address(0), 0, address(0), order.killId
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
