// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "ds-test/test.sol";
import "@utils/console.sol";
import "@cheatcodes/interfaces/ICheatCodes.sol";
import "@contracts/sweep/TroveSmolSweeper.sol";

import "@contracts/treasure/trove/TroveMarketplace.sol";
import "@contracts/treasure/assets/magic-token/Magic.sol";
import "@contracts/weth/WETH9.sol";
import "@contracts/assets/erc721/NFTERC721.sol";
import "@contracts/assets/erc1155/NFTERC1155.sol";

contract TroveSmolSweepSwapperTest is DSTest {
    ICheatCodes public constant CHEATCODES = ICheatCodes(HEVM_ADDRESS);

    TroveSmolSweeper public smolsweep;

    TroveMarketplace public trove;
    Magic public magic;
    WETH9 public weth;
    NFTERC721 public erc721;
    NFTERC1155 public erc1155;

    address public OWNER;
    address public constant NOT_OWNER =
        0x0000000000000000000000000000000000000000;
    address public constant BUYER = 0x0000000000000000000000000000000000000001;
    address[] public SELLERS = [
        0x0000000000000000000000000000000000000002,
        0x0000000000000000000000000000000000000003,
        0x0000000000000000000000000000000000000004
    ];

    function setUp() public {
        OWNER = address(this);

        magic = new Magic();
        weth = new WETH9();
        erc721 = new NFTERC721();
        erc1155 = new NFTERC1155();

        trove = new TroveMarketplace();
        trove.initialize(0, OWNER, magic);
        trove.setWeth(address(weth));
        trove.setTokenApprovalStatus(
            address(erc721),
            TroveMarketplace.TokenApprovalStatus.ERC_721_APPROVED,
            address(magic)
        );

        smolsweep = new TroveSmolSweeper(address(trove), address(magic));
    }

    function test_Owner() public {
        assert(smolsweep.owner() == OWNER);
    }

    function test_NotOwner() public {
        assert(smolsweep.owner() != NOT_OWNER);
    }

    function test_BuySingleFromTrove() public {
        magic.mint(BUYER, 1e18);

        erc721.safeMint(SELLERS[0]);
        uint256 tokenId = 0;

        uint128 price = 1e9;

        CHEATCODES.startPrank(SELLERS[0], SELLERS[0]);
        erc721.setApprovalForAll(address(trove), true);
        trove.createListing(
            address(erc721),
            tokenId,
            1,
            price,
            uint64(block.timestamp + 100),
            address(magic)
        );
        CHEATCODES.stopPrank();

        CHEATCODES.startPrank(BUYER, BUYER);
        magic.approve(address(trove), price);
        BuyItemParams[] memory buyParams = new BuyItemParams[](1);
        buyParams[0] = BuyItemParams(
            address(erc721),
            tokenId,
            SELLERS[0],
            1,
            price,
            address(magic),
            false
        );
        trove.buyItems(buyParams);
    }

    function test_buyItemsSingleTokenSingleERC721() public {
        magic.mint(BUYER, 1e18);

        erc721.safeMint(SELLERS[0]);
        uint256 tokenId = 0;

        uint128 price = 1e9;

        CHEATCODES.startPrank(SELLERS[0], SELLERS[0]);
        erc721.setApprovalForAll(address(trove), true);
        trove.createListing(
            address(erc721),
            tokenId,
            1,
            price,
            uint64(block.timestamp + 100),
            address(magic)
        );
        CHEATCODES.stopPrank();

        CHEATCODES.startPrank(BUYER, BUYER);
        magic.approve(address(smolsweep), 1e19);
        BuyItemParams[] memory buyParams = new BuyItemParams[](1);
        buyParams[0] = BuyItemParams(
            address(erc721),
            tokenId,
            SELLERS[0],
            1,
            price,
            address(magic),
            false
        );
        smolsweep.buyItemsSingleToken(buyParams, 0, address(magic), 1e18);
    }

    function test_buyItemsManyTokensSingleERC721() public {
        magic.mint(BUYER, 1e18);

        erc721.safeMint(SELLERS[0]);
        uint256 tokenId = 0;

        uint128 price = 1e9;

        CHEATCODES.startPrank(SELLERS[0], SELLERS[0]);
        erc721.setApprovalForAll(address(trove), true);
        trove.createListing(
            address(erc721),
            tokenId,
            1,
            price,
            uint64(block.timestamp + 100),
            address(magic)
        );
        CHEATCODES.stopPrank();

        CHEATCODES.startPrank(BUYER, BUYER);
        magic.approve(address(smolsweep), 1e19);
        BuyItemParams[] memory buyParams = new BuyItemParams[](1);
        buyParams[0] = BuyItemParams(
            address(erc721),
            tokenId,
            SELLERS[0],
            1,
            price,
            address(magic),
            false
        );

        address[] memory tokens = new address[](1);
        tokens[0] = address(magic);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e18;
        smolsweep.buyItemsManyTokens(buyParams, 0, tokens, amounts);
    }
}
