// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "@forge-std/src/Test.sol";
import {SmolSweeper} from "@contracts/sweep/SmolSweeper.sol";

import "@contracts/sweep/structs/BuyOrder.sol";
import "@contracts/treasure/trove/TroveMarketplace.sol";
import "@contracts/treasure/assets/magic-token/Magic.sol";
import "@contracts/weth/WETH9.sol";
import "@contracts/assets/erc721/NFTERC721.sol";
import "@contracts/assets/erc1155/NFTERC1155.sol";
import "@contracts/token/ANFTReceiver.sol";

import {ISmolSweeper} from "@contracts/sweep/interfaces/ISmolSweeper.sol";
import {ISmolSweepSwapper} from "@contracts/sweep/interfaces/ISmolSweepSwapper.sol";

import {IDiamondCut} from "@contracts/sweep/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@contracts/sweep/diamond/interfaces/IDiamondLoupe.sol";
import {IDiamondInit} from "@contracts/sweep/diamond/interfaces/IDiamondInit.sol";
import {DiamondCutFacet} from "@contracts/sweep/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@contracts/sweep/diamond/facets/DiamondLoupeFacet.sol";
import {Diamond} from "@contracts/sweep/diamond/Diamond.sol";
import {SmolSweepSwapDiamondInit} from "@contracts/sweep/SmolSweepSwapDiamondInit.sol";
import {OwnershipFacet, IERC173} from "@contracts/sweep/diamond/facets/OwnershipFacet.sol";
import {BaseSweepFacet} from "@contracts/sweep/diamond/facets/sweep/BaseSweepFacet.sol";
import {MarketplacesFacet} from "@contracts/sweep/diamond/facets/sweep/MarketplacesFacet.sol";
import {SweepFacet} from "@contracts/sweep/diamond/facets/sweep/SweepFacet.sol";
import {SweepSwapFacet} from "@contracts/sweep/diamond/facets/sweep/SweepSwapFacet.sol";

import {LibSweep} from "@contracts/sweep/diamond/libraries/LibSweep.sol";
import {LibMarketplaces, MarketplaceType} from "@contracts/sweep/diamond/libraries/LibMarketplaces.sol";

import "@seaport/contracts/lib/ConsiderationStructs.sol";

import {ABaseDiamondTest} from "@test/lib/ABaseDiamondTest.sol";
import {ABaseTestWithUniswapV2} from "@test/lib/ABaseTestWithUniswapV2.sol";

contract SmolSweepSwapperTest is
  Test,
  AERC721Receiver,
  ABaseDiamondTest,
  ABaseTestWithUniswapV2
{
  SmolSweeper public shiftsweep;
  DiamondCutFacet dCutFacet;
  DiamondLoupeFacet dLoupe;
  OwnershipFacet ownerF;
  BaseSweepFacet baseF;
  MarketplacesFacet marketF;
  SweepFacet sweepF;
  SweepSwapFacet sweepSwapF;
  IDiamondInit init;

  TroveMarketplace public trove;
  Magic public magic;
  WETH9 public weth;
  NFTERC721 public erc721;
  NFTERC721 public erc721ETH;

  NFTERC1155 public erc1155;

  address public OWNER;
  address public constant NOT_OWNER =
    0x0000000000000000000000000000000000000001;
  address public constant NEW_OWNER =
    0x0000000000000000000000000000000000000002;
  address public constant BUYER = 0x0000000000000000000000000000000000000003;
  address[] public SELLERS = [
    0x0000000000000000000000000000000000000004,
    0x0000000000000000000000000000000000000005,
    0x0000000000000000000000000000000000000006
  ];

  function setUp() public {
    OWNER = address(this);

    magic = new Magic();
    weth = new WETH9();
    erc721 = new NFTERC721();
    erc721ETH = new NFTERC721();
    erc1155 = new NFTERC1155();

    trove = new TroveMarketplace();
    trove.initialize(0, OWNER, magic);
    trove.setWeth(address(weth));
    trove.setTokenApprovalStatus(
      address(erc721),
      TroveMarketplace.TokenApprovalStatus.ERC_721_APPROVED,
      address(magic)
    );

    trove.setTokenApprovalStatus(
      address(erc721ETH),
      TroveMarketplace.TokenApprovalStatus.ERC_721_APPROVED,
      address(weth)
    );

    //deploy facets
    dCutFacet = new DiamondCutFacet();
    shiftsweep = new SmolSweeper(address(this), address(dCutFacet));
    dLoupe = new DiamondLoupeFacet();
    ownerF = new OwnershipFacet();
    sweepF = new SweepFacet();
    sweepSwapF = new SweepSwapFacet();
    baseF = new BaseSweepFacet();
    marketF = new MarketplacesFacet();

    init = new SmolSweepSwapDiamondInit();
    // init = new DiamondInit();

    //build cut struct
    FacetCut[] memory cut = new FacetCut[](7);

    cut[0] = (
      FacetCut({
        facetAddress: address(dLoupe),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("DiamondLoupeFacet")
      })
    );

    cut[1] = (
      FacetCut({
        facetAddress: address(ownerF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("OwnershipFacet")
      })
    );

    cut[2] = (
      FacetCut({
        facetAddress: address(sweepF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("SweepFacet")
      })
    );

    cut[3] = (
      FacetCut({
        facetAddress: address(sweepSwapF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("SweepSwapFacet")
      })
    );

    cut[4] = (
      FacetCut({
        facetAddress: address(baseF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("BaseSweepFacet")
      })
    );

    cut[5] = (
      FacetCut({
        facetAddress: address(marketF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("MarketplacesFacet")
      })
    );

    cut[6] = (
      FacetCut({
        facetAddress: address(shiftsweep),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("SmolSweeper")
      })
    );

    //upgrade diamond
    IDiamondCut(address(shiftsweep)).diamondCut(
      cut,
      address(init),
      abi.encodePacked(IDiamondInit.init.selector)
    );

    address[] memory troveTokens = new address[](1);
    troveTokens[0] = address(magic);
    MarketplacesFacet(address(shiftsweep)).addMarketplace(
      address(trove),
      troveTokens
    );

    address[] memory stratosTokens = new address[](1);
    stratosTokens[0] = address(0);
    MarketplacesFacet(address(shiftsweep)).addMarketplace(
      address(0x998EF16Ea4111094EB5eE72fC2c6f4e6E8647666),
      stratosTokens
    );
  }

  function test_owner() public {
    assertEq(IERC173(address(shiftsweep)).owner(), OWNER);
  }

  function test_transferOwnership() public {
    IERC173(address(shiftsweep)).transferOwnership(NEW_OWNER);
    assertEq(IERC173(address(shiftsweep)).owner(), NEW_OWNER);
  }

  function test_supportsInterface() public {
    assertTrue(
      IERC165(address(shiftsweep)).supportsInterface(type(IERC165).interfaceId)
    );
    assertTrue(
      IERC165(address(shiftsweep)).supportsInterface(type(IERC173).interfaceId)
    );
    assertTrue(
      IERC165(address(shiftsweep)).supportsInterface(
        type(IDiamondCut).interfaceId
      )
    );
    assertTrue(
      IERC165(address(shiftsweep)).supportsInterface(
        type(IDiamondLoupe).interfaceId
      )
    );
    assertTrue(
      IERC165(address(shiftsweep)).supportsInterface(
        type(IERC721Receiver).interfaceId
      )
    );
    assertTrue(
      IERC165(address(shiftsweep)).supportsInterface(
        type(IERC1155Receiver).interfaceId
      )
    );
    assertTrue(
      IERC165(address(shiftsweep)).supportsInterface(
        type(ISmolSweeper).interfaceId
      )
    );
    assertTrue(
      IERC165(address(shiftsweep)).supportsInterface(
        type(ISmolSweepSwapper).interfaceId
      )
    );
  }

  function test_buySingleFromTrove() public {
    magic.mint(BUYER, 1e18);

    erc721.safeMint(SELLERS[0]);
    uint256 tokenId = 0;

    uint128 price = 1e9;

    vm.startPrank(SELLERS[0], SELLERS[0]);
    erc721.setApprovalForAll(address(trove), true);
    trove.createListing(
      address(erc721),
      tokenId,
      1,
      price,
      uint64(block.timestamp + 100),
      address(magic)
    );
    vm.stopPrank();

    vm.startPrank(BUYER, BUYER);
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

  // function test_buyItemsMultiTokensTroveSingleERC721() public {
  //   magic.mint(BUYER, 1e18);

  //   erc721.safeMint(SELLERS[0]);
  //   uint256 tokenId = 0;

  //   uint128 price = 1e9;

  //   vm.startPrank(SELLERS[0], SELLERS[0]);
  //   erc721.setApprovalForAll(address(trove), true);
  //   trove.createListing(
  //     address(erc721),
  //     tokenId,
  //     1,
  //     price,
  //     uint64(block.timestamp + 100),
  //     address(magic)
  //   );
  //   vm.stopPrank();

  //   vm.startPrank(BUYER, BUYER);
  //   magic.approve(address(smolsweep), 1e19);

  //   MultiTokenBuyOrder[] memory buyOrders = new MultiTokenBuyOrder[](1);
  //   buyOrders[0] = MultiTokenBuyOrder(
  //     BuyItemParams(
  //       address(erc721),
  //       tokenId,
  //       SELLERS[0],
  //       1,
  //       price,
  //       address(magic),
  //       false
  //     ),
  //     new Order[](0),
  //     new CriteriaResolver[](0),
  //     new Fulfillment[](0),
  //     address(trove),
  //     MarketplaceType.TROVE,
  //     address(magic),
  //     0
  //   );

  //   address[] memory tokens = new address[](1);
  //   tokens[0] = address(magic);
  //   uint256[] memory amounts = new uint256[](1);
  //   amounts[0] = 1e18;
  //   uint256 sellerBalanceMagicBefore = magic.balanceOf(SELLERS[0]);
  //   uint256 buyerBalanceMagicBefore = magic.balanceOf(BUYER);
  //   ISmolSweepSwapper(address(smolsweep)).buyOrdersMultiTokens(
  //     buyOrders,
  //     0,
  //     tokens,
  //     amounts
  //   );
  //   vm.stopPrank();
  //   uint256 sellerBalanceMagicAfter = magic.balanceOf(SELLERS[0]);
  //   uint256 buyerBalanceMagicAfter = magic.balanceOf(BUYER);
  //   assertEq(
  //     sellerBalanceMagicAfter - sellerBalanceMagicBefore,
  //     price,
  //     "seller magic balance diff"
  //   );
  //   assertEq(
  //     buyerBalanceMagicBefore - buyerBalanceMagicAfter,
  //     price,
  //     "buyer magic balance diff"
  //   );

  //   assertEq(erc721.ownerOf(tokenId), BUYER, "buyer is new token owner");
  //   assertEq(erc721.balanceOf(BUYER), 1, "buyer has 1 token");
  //   assertEq(erc721.balanceOf(SELLERS[0]), 0, "seller has 0 tokens");
  // }

  // function test_buyItemsMultiTokenTroveUsingETHSingleERC721() public {
  //   erc721ETH.safeMint(SELLERS[0]);
  //   uint256 tokenId = 0;

  //   uint128 price = 1e9;

  //   vm.startPrank(SELLERS[0], SELLERS[0]);
  //   erc721ETH.setApprovalForAll(address(trove), true);
  //   trove.createListing(
  //     address(erc721ETH),
  //     tokenId,
  //     1,
  //     price,
  //     uint64(block.timestamp + 100),
  //     address(weth)
  //   );
  //   vm.stopPrank();

  //   vm.prank(BUYER, BUYER);
  //   magic.approve(address(smolsweep), 1e19);

  //   MultiTokenBuyOrder[] memory buyOrders = new MultiTokenBuyOrder[](1);
  //   buyOrders[0] = MultiTokenBuyOrder(
  //     BuyItemParams(
  //       address(erc721ETH),
  //       tokenId,
  //       SELLERS[0],
  //       1,
  //       price,
  //       address(weth),
  //       true
  //     ),
  //     new Order[](0),
  //     new CriteriaResolver[](0),
  //     new Fulfillment[](0),
  //     address(trove),
  //     MarketplaceType.TROVE,
  //     address(0),
  //     0
  //   );

  //   address[] memory tokens = new address[](1);
  //   tokens[0] = address(0);
  //   uint256[] memory amounts = new uint256[](1);
  //   amounts[0] = 1e18;
  //   payable(address(BUYER)).transfer(2e19);
  //   vm.startPrank(BUYER, BUYER);

  //   uint256 sellerBalanceETHBefore = address(SELLERS[0]).balance;
  //   uint256 buyerBalanceETHBefore = address(BUYER).balance;
  //   ISmolSweepSwapper(address(smolsweep)).buyOrdersMultiTokens{
  //     value: amounts[0]
  //   }(buyOrders, 0, tokens, amounts);
  //   vm.stopPrank();
  //   uint256 sellerBalanceETHAfter = address(SELLERS[0]).balance;
  //   uint256 buyerBalanceETHAfter = address(BUYER).balance;
  //   assertEq(
  //     sellerBalanceETHAfter - sellerBalanceETHBefore,
  //     price,
  //     "seller balance diff"
  //   );
  //   assertEq(
  //     buyerBalanceETHBefore - buyerBalanceETHAfter,
  //     price,
  //     "buyer balance diff"
  //   );

  //   assertEq(erc721ETH.ownerOf(tokenId), BUYER, "buyer is new owner of token");
  //   assertEq(erc721ETH.balanceOf(BUYER), 1, "buyer has 1 token");
  //   assertEq(erc721ETH.balanceOf(SELLERS[0]), 0, "seller has 0 tokens");
  // }

  // function test_buyItemsMultiTokenTroveUsingMagicAndETHSingleERC721() public {
  //   magic.mint(BUYER, 1e18);

  //   erc721.safeMint(SELLERS[0]);
  //   erc721ETH.safeMint(SELLERS[1]);
  //   uint256 tokenId = 0;

  //   uint128 price0 = 1e9;
  //   uint128 price1 = 1e9;

  //   vm.startPrank(SELLERS[0], SELLERS[0]);
  //   erc721.setApprovalForAll(address(trove), true);
  //   trove.createListing(
  //     address(erc721),
  //     tokenId,
  //     1,
  //     price1,
  //     uint64(block.timestamp + 100),
  //     address(magic)
  //   );
  //   vm.stopPrank();

  //   vm.startPrank(SELLERS[1], SELLERS[1]);
  //   erc721ETH.setApprovalForAll(address(trove), true);
  //   trove.createListing(
  //     address(erc721ETH),
  //     tokenId,
  //     1,
  //     price0,
  //     uint64(block.timestamp + 100),
  //     address(weth)
  //   );
  //   vm.stopPrank();

  //   vm.prank(BUYER, BUYER);
  //   magic.approve(address(smolsweep), 1e19);

  //   {
  //     MultiTokenBuyOrder[] memory buyOrders = new MultiTokenBuyOrder[](2);
  //     buyOrders[0] = MultiTokenBuyOrder(
  //       BuyItemParams(
  //         address(erc721),
  //         tokenId,
  //         SELLERS[0],
  //         1,
  //         price1,
  //         address(magic),
  //         false
  //       ),
  //       new Order[](0),
  //       new CriteriaResolver[](0),
  //       new Fulfillment[](0),
  //       address(trove),
  //       MarketplaceType.TROVE,
  //       address(magic),
  //       0
  //     );

  //     buyOrders[1] = MultiTokenBuyOrder(
  //       BuyItemParams(
  //         address(erc721ETH),
  //         tokenId,
  //         SELLERS[1],
  //         1,
  //         price1,
  //         address(weth),
  //         true
  //       ),
  //       new Order[](0),
  //       new CriteriaResolver[](0),
  //       new Fulfillment[](0),
  //       address(trove),
  //       MarketplaceType.TROVE,
  //       address(0),
  //       1
  //     );

  //     address[] memory tokens = new address[](2);
  //     tokens[0] = address(magic);
  //     tokens[1] = address(0);
  //     uint256[] memory maxSpends = new uint256[](2);
  //     maxSpends[0] = 1e18;
  //     maxSpends[1] = 1e18;

  //     payable(address(BUYER)).transfer(maxSpends[1]);
  //     uint256 seller0BalanceMagicBefore = magic.balanceOf(SELLERS[0]);
  //     uint256 buyerBalanceMagicBefore = magic.balanceOf(BUYER);
  //     uint256 seller1BalanceETHBefore = SELLERS[1].balance;
  //     uint256 buyerBalanceETHBefore = BUYER.balance;
  //     vm.startPrank(BUYER, BUYER);
  //     ISmolSweepSwapper(address(smolsweep)).buyOrdersMultiTokens{
  //       value: maxSpends[1]
  //     }(buyOrders, 0, tokens, maxSpends);
  //     vm.stopPrank();
  //     uint256 seller0BalanceMagicAfter = magic.balanceOf(SELLERS[0]);
  //     uint256 buyerBalanceMagicAfter = magic.balanceOf(BUYER);
  //     uint256 seller1BalanceETHAfter = SELLERS[1].balance;
  //     uint256 buyerBalanceETHAfter = BUYER.balance;

  //     assertEq(
  //       seller0BalanceMagicAfter - seller0BalanceMagicBefore,
  //       price0,
  //       "seller0 magic balance diff"
  //     );
  //     assertEq(
  //       seller1BalanceETHAfter - seller1BalanceETHBefore,
  //       price1,
  //       "seller1 ETH balance diff"
  //     );
  //     assertEq(
  //       buyerBalanceMagicBefore - buyerBalanceMagicAfter,
  //       price0,
  //       "buyer magic balance diff"
  //     );
  //     assertEq(
  //       buyerBalanceETHBefore - buyerBalanceETHAfter,
  //       price1,
  //       "buyer ETH balance diff"
  //     );
  //   }

  //   assertEq(erc721.balanceOf(BUYER), 1, "buyer has 1 token");
  //   assertEq(erc721.balanceOf(SELLERS[0]), 0, "seller0 has 0 tokens");
  //   assertEq(erc721.ownerOf(tokenId), BUYER, "buyer is new owner of token");
  //   assertEq(erc721ETH.balanceOf(BUYER), 1, "buyer has 1 token");
  //   assertEq(erc721ETH.balanceOf(SELLERS[1]), 0, "seller1 has 0 tokens");
  //   assertEq(erc721ETH.ownerOf(tokenId), BUYER, "buyer is new owner of token");
  // }
}
