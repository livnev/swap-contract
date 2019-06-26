pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;


contract Verifiable {

  bytes constant internal EIP191_HEADER = "\x19\x01";
  bytes constant internal DOMAIN_NAME = "SWAP";
  bytes constant internal DOMAIN_VERSION = "2";

  bytes32 private domainSeparator;

  struct Party {
    address wallet;
    address token;
    uint256 param;
  }

  struct Order {
    uint256 id;
    uint256 expiry;
    Party maker;
    Party taker;
    Party affiliate;
  }

  struct Signature {
    address signer;
    bytes32 r;
    bytes32 s;
    uint8 v;
    bytes1 version;
  }

  bytes32 internal constant DOMAIN_TYPEHASH = keccak256(abi.encodePacked(
      "EIP712Domain(",
      "string name,",
      "string version,",
      "address verifyingContract",
      ")"
  ));

  bytes32 internal constant ORDER_TYPEHASH = keccak256(abi.encodePacked(
      "Order(",
      "uint256 id,",
      "uint256 expiry,",
      "Party maker,",
      "Party taker,",
      "Party affiliate",
      ")",
      "Party(",
      "address wallet,",
      "address token,",
      "uint256 param",
      ")"
  ));

  bytes32 internal constant PARTY_TYPEHASH = keccak256(abi.encodePacked(
      "Party(",
      "address wallet,",
      "address token,",
      "uint256 param",
      ")"
  ));

  constructor() public {
    domainSeparator = keccak256(abi.encode(
        DOMAIN_TYPEHASH,
        keccak256(DOMAIN_NAME),
        keccak256(DOMAIN_VERSION),
        this
    ));
  }

  function hashParty(Party memory party) internal pure returns (bytes32) {
    return keccak256(abi.encode(
        PARTY_TYPEHASH,
        party.wallet,
        party.token,
        party.param
    ));
  }

  function hashOrder(Order memory order) internal view returns (bytes32) {
    return keccak256(abi.encodePacked(
        EIP191_HEADER,
        domainSeparator,
        keccak256(abi.encode(
            ORDER_TYPEHASH,
            order.id,
            order.expiry,
            hashParty(order.maker),
            hashParty(order.taker),
            hashParty(order.affiliate)
        ))
    ));
  }

  /**
    * @notice Validates signature using an EIP-712 typed data hash.
    *
    * @param order Order
    * @param signature Signature
    */
  function isValid(Order memory order, Signature memory signature) internal view returns (bool) {
    if (signature.version == byte(0x01)) {
      return signature.signer == ecrecover(
          hashOrder(order),
          signature.v, signature.r, signature.s
      );
    }
    if (signature.version == byte(0x45)) {
      return signature.signer == ecrecover(
          keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hashOrder(order))),
          signature.v, signature.r, signature.s
      );
    }
    return false;
  }

  /**
    * @notice Validates signature using a simple hash and verifyingContract.
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
  function isValidSimple(uint256 id,
    address makerWallet, uint256 makerParam, address makerToken,
    address takerWallet, uint256 takerParam, address takerToken,
    uint256 expiry, bytes32 r, bytes32 s, uint8 v
    ) internal view returns (bool) {
    return makerWallet == ecrecover(
      keccak256(abi.encodePacked(
        "\x19Ethereum Signed Message:\n32",
        keccak256(abi.encodePacked(
          byte(0),
          this,
          id,
          makerWallet,
          makerParam,
          makerToken,
          takerWallet,
          takerParam,
          takerToken,
          expiry
        )))),
      v, r, s);
  }

}
