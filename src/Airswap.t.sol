pragma solidity ^0.5.6;

import "ds-test/test.sol";

import "./Airswap.sol";

contract AirswapTest is DSTest {
    Airswap airswap;

    function setUp() public {
        airswap = new Airswap();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
