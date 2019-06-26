pragma solidity ^0.5.6;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";
import "ds-token/token.sol";

import {Swap} from "./Swap.sol";
import {Verifiable} from "./Verifiable.sol";
import {SwapSimple} from "./SwapI.sol";

contract SwapTest is DSTest, Verifiable {
    Swap airswap;
    DSToken gold;
    DSToken dai;

    Party mak;
    Party tak;
    Party aff;
    Order ord;
    Signature sig;

    function setUp() public {
        airswap = new Swap();

        gold = new DSToken("GEM");
        gold.mint(1000 ether);
        gold.approve(address(airswap));

        dai = new DSToken("DAI");
        dai.mint(1000 ether);
        dai.approve(address(airswap));
    }

    function test_fudged_fill() public {
        Party memory mak = Party({wallet: address(this),
                                  token: address(dai),
                                  param: 10 ether});
        Party memory tak = Party({wallet: address(this),
                                  token: address(gold),
                                  param: 1 ether});
        Party memory aff = Party({wallet: address(0),
                                  token: address(0),
                                  param: 0 ether});
        Order memory ord = Order({takeId: 1337,
                                  killId: 7331,
                                  expiry: uint(-1),
                                  maker: mak,
                                  taker: tak,
                                  affiliate: aff});
        Signature memory sig = Signature({signer: address(this),
                                          r: hex"dead",
                                          s: hex"beef",
                                          v: uint8(0x1b),
                                          // stupid signature method
                                          version: bytes1(0xff)});
        airswap.swap(ord, sig);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
