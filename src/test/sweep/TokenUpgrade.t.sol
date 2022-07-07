// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "ds-test/test.sol";
import "@utils/console.sol";
import "@cheatcodes/interfaces/ICheatCodes.sol";
import "@contracts/sweep/TroveSmolSweeper.sol";

import "@contracts/sweep/TokenUpgrade.sol";

contract MyTokenTest is DSTest {
    ICheatCodes public constant CHEATCODES = ICheatCodes(HEVM_ADDRESS);

    MyToken public token;

    address public OWNER;
    address public constant NOT_OWNER =
        0x0000000000000000000000000000000000000001;
    address public constant NEW_OWNER =
        0x0000000000000000000000000000000000000002;
    address public constant USER = 0x0000000000000000000000000000000000000003;

    function setUp() public {
        token = new MyToken();

        token.initialize();

        OWNER = address(this);
    }

    function test_owner() public {
        assertEq(token.owner(), OWNER);
    }

    function test_transferOwnership() public {
        assertEq(token.owner(), OWNER);
        token.transferOwnership(NEW_OWNER);
        assertEq(token.owner(), NEW_OWNER);
    }

    function test_mint() public {
        assertEq(token.balanceOf(OWNER), 0);
        token.mint(OWNER, 100);
        assertEq(token.balanceOf(OWNER), 100);
    }

    function test_transfer() public {
        token.mint(OWNER, 100);
        assertEq(token.balanceOf(OWNER), 100);
        assertEq(token.balanceOf(USER), 0);
        token.transfer(USER, 50);
        assertEq(token.balanceOf(OWNER), 50);
        assertEq(token.balanceOf(USER), 50);
    }
}
