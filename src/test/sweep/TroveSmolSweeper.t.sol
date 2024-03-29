// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@forge-std/src/Test.sol";
import "@contracts/sweep/SmolSweeper.sol";

// import "@contracts/treasure/trove/TroveMarketplace.sol";
// import "@contracts/treasure/assets/magic-token/Magic.sol";
// import "@contracts/weth/WETH9.sol";
// import "@contracts/assets/erc721/NFTERC721.sol";
// import "@contracts/assets/erc1155/NFTERC1155.sol";
// import "@contracts/token/ANFTReceiver.sol";

// import "@contracts/sweep/interfaces/ITroveSmolSweeper.sol";

// import "@contracts/sweep/diamond/interfaces/IDiamondCut.sol";
// import "@contracts/sweep/diamond/facets/DiamondCutFacet.sol";
// import "@contracts/sweep/diamond/facets/OwnershipFacet.sol";
// import "@contracts/sweep/diamond/facets/sweep/SweepTroveFacet.sol";
// import {DiamondLoupeFacet} from "@contracts/sweep/diamond/facets/DiamondLoupeFacet.sol";
// import "@contracts/sweep/diamond/Diamond.sol";

// contract TroveSmolSweeperTest is Test, AERC721Receiver, IDiamondCut {
//   SmolSweeper public smolsweep;
//   DiamondCutFacet dCutFacet;
//   DiamondLoupeFacet dLoupe;
//   OwnershipFacet ownerF;
//   SweepTroveFacet sweepF;
//   IDiamondInit init;

//   TroveMarketplace public trove;
//   Magic public magic;
//   WETH9 public weth;
//   NFTERC721 public erc721;
//   NFTERC721 public erc721ETH;

//   NFTERC1155 public erc1155;

//   address public OWNER;
//   address public constant NOT_OWNER =
//     0x0000000000000000000000000000000000000001;
//   address public constant NEW_OWNER =
//     0x0000000000000000000000000000000000000002;
//   address public constant BUYER = 0x0000000000000000000000000000000000000003;
//   address[] public SELLERS = [
//     0x0000000000000000000000000000000000000004,
//     0x0000000000000000000000000000000000000005,
//     0x0000000000000000000000000000000000000006
//   ];

//   function setUp() public {
//     OWNER = address(this);

//     magic = new Magic();
//     weth = new WETH9();
//     erc721 = new NFTERC721();
//     erc721ETH = new NFTERC721();
//     erc1155 = new NFTERC1155();

//     trove = new TroveMarketplace();
//     trove.initialize(0, OWNER, magic);
//     trove.setWeth(address(weth));
//     trove.setTokenApprovalStatus(
//       address(erc721),
//       TroveMarketplace.TokenApprovalStatus.ERC_721_APPROVED,
//       address(magic)
//     );

//     trove.setTokenApprovalStatus(
//       address(erc721ETH),
//       TroveMarketplace.TokenApprovalStatus.ERC_721_APPROVED,
//       address(weth)
//     );

//     //deploy facets
//     dCutFacet = new DiamondCutFacet();
//     smolsweep = new SmolSweeper(address(this), address(dCutFacet));
//     dLoupe = new DiamondLoupeFacet();
//     ownerF = new OwnershipFacet();
//     sweepF = new SweepTroveFacet();

//     //build cut struct
//     FacetCut[] memory cut = new FacetCut[](3);

//     cut[0] = (
//       FacetCut({
//         facetAddress: address(dLoupe),
//         action: FacetCutAction.Add,
//         functionSelectors: generateSelectors("DiamondLoupeFacet")
//       })
//     );

//     cut[1] = (
//       FacetCut({
//         facetAddress: address(ownerF),
//         action: FacetCutAction.Add,
//         functionSelectors: generateSelectors("OwnershipFacet")
//       })
//     );

//     cut[2] = (
//       FacetCut({
//         facetAddress: address(sweepF),
//         action: FacetCutAction.Add,
//         functionSelectors: generateSelectors("SweepTroveFacet")
//       })
//     );

//     //upgrade diamond
//     IDiamondCut(address(smolsweep)).diamondCut(cut, address(init), "");

//     //call a function
//     // DiamondLoupeFacet(address(smolsweep)).facetAddresses();

//     SweepTroveFacet(address(smolsweep)).setMarketplaceContract(
//       ITroveMarketplace(address(trove))
//     );
//     SweepTroveFacet(address(smolsweep)).setWeth(IERC20(address(weth)));
//   }

//   function generateSelectors(string memory _facetName)
//     internal
//     returns (bytes4[] memory selectors)
//   {
//     string[] memory cmd = new string[](4);
//     // cmd[0] = "ls";
//     cmd[0] = "node";
//     cmd[1] = "scripts/genSelectors.js";
//     cmd[2] = _facetName;
//     cmd[3] = "fout";
//     bytes memory res = vm.ffi(cmd);
//     selectors = abi.decode(res, (bytes4[]));
//   }

//   function diamondCut(
//     FacetCut[] calldata _diamondCut,
//     address _init,
//     bytes calldata _calldata
//   ) external override {}

//   function test_owner() public {
//     assertEq(IERC173(address(smolsweep)).owner(), OWNER);
//   }

//   function test_transferOwnership() public {
//     IERC173(address(smolsweep)).transferOwnership(NEW_OWNER);
//     assertEq(IERC173(address(smolsweep)).owner(), NEW_OWNER);
//   }

//   function test_buySingleFromTrove() public {
//     magic.mint(BUYER, 1e18);

//     erc721.safeMint(SELLERS[0]);
//     uint256 tokenId = 0;

//     uint128 price = 1e9;

//     vm.startPrank(SELLERS[0], SELLERS[0]);
//     erc721.setApprovalForAll(address(trove), true);
//     trove.createListing(
//       address(erc721),
//       tokenId,
//       1,
//       price,
//       uint64(block.timestamp + 100),
//       address(magic)
//     );
//     vm.stopPrank();

//     vm.startPrank(BUYER, BUYER);
//     magic.approve(address(trove), price);
//     BuyItemParams[] memory buyParams = new BuyItemParams[](1);
//     buyParams[0] = BuyItemParams(
//       address(erc721),
//       tokenId,
//       SELLERS[0],
//       1,
//       price,
//       address(magic),
//       false
//     );
//     trove.buyItems(buyParams);
//   }

//   function test_buyItemsSingleTokenSingleERC721() public {
//     magic.mint(BUYER, 1e18);

//     erc721.safeMint(SELLERS[0]);
//     uint256 tokenId = 0;

//     uint128 price = 1e9;

//     vm.startPrank(SELLERS[0], SELLERS[0]);
//     erc721.setApprovalForAll(address(trove), true);
//     trove.createListing(
//       address(erc721),
//       tokenId,
//       1,
//       price,
//       uint64(block.timestamp + 100),
//       address(magic)
//     );
//     vm.stopPrank();

//     vm.startPrank(BUYER, BUYER);
//     magic.approve(address(smolsweep), 1e19);
//     BuyItemParams[] memory buyParams = new BuyItemParams[](1);
//     buyParams[0] = BuyItemParams(
//       address(erc721),
//       tokenId,
//       SELLERS[0],
//       1,
//       price,
//       address(magic),
//       false
//     );
//     uint256 sellerBalanceMagicBefore = magic.balanceOf(SELLERS[0]);
//     uint256 buyerBalanceMagicBefore = magic.balanceOf(BUYER);
//     ITroveSmolSweeper(address(smolsweep)).buyItemsSingleToken(
//       buyParams,
//       0,
//       address(magic),
//       1e18
//     );
//     uint256 sellerBalanceMagicAfter = magic.balanceOf(SELLERS[0]);
//     uint256 buyerBalanceMagicAfter = magic.balanceOf(BUYER);
//     assertEq(sellerBalanceMagicAfter - sellerBalanceMagicBefore, price);
//     assertEq(buyerBalanceMagicBefore - buyerBalanceMagicAfter, price);

//     assertEq(erc721.ownerOf(tokenId), BUYER);
//     assertEq(erc721.balanceOf(BUYER), 1);
//     assertEq(erc721.balanceOf(SELLERS[0]), 0);
//   }

//   function test_buyItemsMultiTokensSingleERC721() public {
//     magic.mint(BUYER, 1e18);

//     erc721.safeMint(SELLERS[0]);
//     uint256 tokenId = 0;

//     uint128 price = 1e9;

//     vm.startPrank(SELLERS[0], SELLERS[0]);
//     erc721.setApprovalForAll(address(trove), true);
//     trove.createListing(
//       address(erc721),
//       tokenId,
//       1,
//       price,
//       uint64(block.timestamp + 100),
//       address(magic)
//     );
//     vm.stopPrank();

//     vm.startPrank(BUYER, BUYER);
//     magic.approve(address(smolsweep), 1e19);
//     BuyItemParams[] memory buyParams = new BuyItemParams[](1);
//     buyParams[0] = BuyItemParams(
//       address(erc721),
//       tokenId,
//       SELLERS[0],
//       1,
//       price,
//       address(magic),
//       false
//     );

//     address[] memory tokens = new address[](1);
//     tokens[0] = address(magic);
//     uint256[] memory amounts = new uint256[](1);
//     amounts[0] = 1e18;
//     uint256 sellerBalanceMagicBefore = magic.balanceOf(SELLERS[0]);
//     uint256 buyerBalanceMagicBefore = magic.balanceOf(BUYER);
//     ITroveSmolSweeper(address(smolsweep)).buyItemsMultiTokens(
//       buyParams,
//       0,
//       tokens,
//       amounts
//     );

//     uint256 sellerBalanceMagicAfter = magic.balanceOf(SELLERS[0]);
//     uint256 buyerBalanceMagicAfter = magic.balanceOf(BUYER);
//     assertEq(sellerBalanceMagicAfter - sellerBalanceMagicBefore, price);
//     assertEq(buyerBalanceMagicBefore - buyerBalanceMagicAfter, price);

//     assertEq(erc721.ownerOf(tokenId), BUYER);
//     assertEq(erc721.balanceOf(BUYER), 1);
//     assertEq(erc721.balanceOf(SELLERS[0]), 0);
//   }

//   function test_buyItemsSingleTokenUsingETHSingleERC721() public {
//     magic.mint(OWNER, 1e18);

//     erc721ETH.safeMint(SELLERS[0]);
//     uint256 tokenId = 0;

//     uint128 price = 1e9;

//     vm.startPrank(SELLERS[0], SELLERS[0]);
//     erc721ETH.setApprovalForAll(address(trove), true);
//     trove.createListing(
//       address(erc721ETH),
//       tokenId,
//       1,
//       price,
//       uint64(block.timestamp + 100),
//       address(weth)
//     );
//     vm.stopPrank();

//     // uint256 sellerBalanceMagicBefore = magic.balanceOf(SELLERS[0]);
//     // uint256 buyerBalanceMagicBefore = magic.balanceOf(BUYER);
//     //         vm.prank(BUYER, BUYER);
//     BuyItemParams[] memory buyParams = new BuyItemParams[](1);
//     buyParams[0] = BuyItemParams(
//       address(erc721ETH),
//       tokenId,
//       SELLERS[0],
//       1,
//       price,
//       address(weth),
//       true
//     );
//     ITroveSmolSweeper(address(smolsweep)).buyItemsSingleToken{value: 1e18}(
//       buyParams,
//       0,
//       address(weth),
//       1e18
//     );
//   }

//   function test_buyItemsManyTokenUsingMagicAndETHSingleERC721() public {
//     magic.mint(BUYER, 1e18);

//     erc721.safeMint(SELLERS[0]);
//     erc721ETH.safeMint(SELLERS[1]);
//     uint256 tokenId = 0;

//     uint128 price0 = 1e9;
//     uint128 price1 = 1e9;

//     {
//       vm.startPrank(SELLERS[0], SELLERS[0]);
//       erc721.setApprovalForAll(address(trove), true);
//       trove.createListing(
//         address(erc721),
//         tokenId,
//         1,
//         price1,
//         uint64(block.timestamp + 100),
//         address(magic)
//       );
//       vm.stopPrank();

//       vm.startPrank(SELLERS[1], SELLERS[1]);
//       erc721ETH.setApprovalForAll(address(trove), true);
//       trove.createListing(
//         address(erc721ETH),
//         tokenId,
//         1,
//         price0,
//         uint64(block.timestamp + 100),
//         address(weth)
//       );
//       vm.stopPrank();

//       vm.prank(BUYER, BUYER);
//       magic.approve(address(smolsweep), 1e19);
//       BuyItemParams[] memory buyParams = new BuyItemParams[](2);
//       buyParams[0] = BuyItemParams(
//         address(erc721),
//         tokenId,
//         SELLERS[0],
//         1,
//         price0,
//         address(magic),
//         false
//       );
//       buyParams[1] = BuyItemParams(
//         address(erc721ETH),
//         tokenId,
//         SELLERS[1],
//         1,
//         price1,
//         address(weth),
//         true
//       );

//       address[] memory tokens = new address[](2);
//       tokens[0] = address(magic);
//       tokens[1] = address(weth);
//       uint256[] memory amounts = new uint256[](2);
//       amounts[0] = price0;
//       amounts[1] = price1;

//       payable(BUYER).transfer(price1);
//       uint256 seller0BalanceMagicBefore = magic.balanceOf(SELLERS[0]);
//       uint256 seller1BalanceETHBefore = SELLERS[1].balance;
//       uint256 buyerBalanceMagicBefore = magic.balanceOf(BUYER);
//       uint256 buyerBalanceETHBefore = BUYER.balance;

//       vm.prank(BUYER, BUYER);
//       ITroveSmolSweeper(address(smolsweep)).buyItemsMultiTokens{value: price1}(
//         buyParams,
//         0,
//         tokens,
//         amounts
//       );
//       uint256 seller0BalanceMagicAfter = magic.balanceOf(SELLERS[0]);
//       uint256 seller1BalanceETHAfter = SELLERS[1].balance;
//       uint256 buyerBalanceMagicAfter = magic.balanceOf(BUYER);
//       uint256 buyerBalanceETHAfter = BUYER.balance;

//       assertEq(seller0BalanceMagicAfter - seller0BalanceMagicBefore, price0);
//       assertEq(seller1BalanceETHAfter - seller1BalanceETHBefore, price1);
//       assertEq(buyerBalanceMagicBefore - buyerBalanceMagicAfter, price0);
//       assertEq(buyerBalanceETHBefore - buyerBalanceETHAfter, price1);
//     }

//     assertEq(erc721.balanceOf(BUYER), 1);
//     assertEq(erc721.balanceOf(SELLERS[0]), 0);
//     assertEq(erc721.ownerOf(tokenId), BUYER);
//     assertEq(erc721ETH.balanceOf(BUYER), 1);
//     assertEq(erc721ETH.balanceOf(SELLERS[1]), 0);
//     assertEq(erc721ETH.ownerOf(tokenId), BUYER);
//   }

//   function test_sweepItemsSingleTokenSingleERC721() public {
//     magic.mint(BUYER, 1e18);

//     erc721.safeMint(SELLERS[0]);
//     uint256 tokenId = 0;

//     uint128 price = 1e9;

//     vm.startPrank(SELLERS[0], SELLERS[0]);
//     erc721.setApprovalForAll(address(trove), true);
//     trove.createListing(
//       address(erc721),
//       tokenId,
//       1,
//       price,
//       uint64(block.timestamp + 100),
//       address(magic)
//     );
//     vm.stopPrank();

//     vm.prank(BUYER, BUYER);
//     magic.approve(address(smolsweep), 1e19);
//     BuyItemParams[] memory buyParams = new BuyItemParams[](1);
//     buyParams[0] = BuyItemParams(
//       address(erc721),
//       tokenId,
//       SELLERS[0],
//       1,
//       price,
//       address(magic),
//       false
//     );

//     uint256 sellerBalanceMagicBefore = magic.balanceOf(SELLERS[0]);
//     uint256 buyerBalanceMagicBefore = magic.balanceOf(BUYER);
//     vm.prank(BUYER, BUYER);
//     ITroveSmolSweeper(address(smolsweep)).sweepItemsSingleToken(
//       buyParams,
//       0,
//       address(magic),
//       price,
//       price,
//       1,
//       1
//     );
//     uint256 sellerBalanceMagicAfter = magic.balanceOf(SELLERS[0]);
//     uint256 buyerBalanceMagicAfter = magic.balanceOf(BUYER);

//     assertEq(sellerBalanceMagicAfter - sellerBalanceMagicBefore, price);
//     assertEq(buyerBalanceMagicBefore - buyerBalanceMagicAfter, price);

//     assertEq(erc721.balanceOf(BUYER), 1);
//     assertEq(erc721.balanceOf(SELLERS[0]), 0);
//     assertEq(erc721.ownerOf(tokenId), BUYER);
//   }

//   function test_sweepItemsMultiTokensSingleERC721() public {
//     magic.mint(BUYER, 1e18);

//     erc721.safeMint(SELLERS[0]);
//     uint256 tokenId = 0;

//     uint128 price = 1e9;

//     vm.startPrank(SELLERS[0], SELLERS[0]);
//     erc721.setApprovalForAll(address(trove), true);
//     trove.createListing(
//       address(erc721),
//       tokenId,
//       1,
//       price,
//       uint64(block.timestamp + 100),
//       address(magic)
//     );
//     vm.stopPrank();

//     vm.prank(BUYER, BUYER);
//     magic.approve(address(smolsweep), 1e19);
//     BuyItemParams[] memory buyParams = new BuyItemParams[](1);
//     buyParams[0] = BuyItemParams(
//       address(erc721),
//       tokenId,
//       SELLERS[0],
//       1,
//       price,
//       address(magic),
//       false
//     );

//     address[] memory tokens = new address[](1);
//     tokens[0] = address(magic);
//     uint256[] memory maxSpends = new uint256[](1);
//     maxSpends[0] = price;
//     uint256[] memory minSpends = new uint256[](1);
//     minSpends[0] = price;

//     uint256 sellerBalanceMagicBefore = magic.balanceOf(SELLERS[0]);
//     uint256 buyerBalanceMagicBefore = magic.balanceOf(BUYER);
//     vm.prank(BUYER, BUYER);
//     ITroveSmolSweeper(address(smolsweep)).sweepItemsMultiTokens(
//       buyParams,
//       0,
//       tokens,
//       maxSpends,
//       minSpends,
//       1,
//       1
//     );
//     uint256 sellerBalanceMagicAfter = magic.balanceOf(SELLERS[0]);
//     uint256 buyerBalanceMagicAfter = magic.balanceOf(BUYER);

//     assertEq(sellerBalanceMagicAfter - sellerBalanceMagicBefore, price);
//     assertEq(buyerBalanceMagicBefore - buyerBalanceMagicAfter, price);

//     assertEq(erc721.balanceOf(BUYER), 1);
//     assertEq(erc721.balanceOf(SELLERS[0]), 0);
//     assertEq(erc721.ownerOf(tokenId), BUYER);
//   }

//   function test_sweepItemsSingleTokenUsingETHSingleERC721() public {
//     magic.mint(OWNER, 1e18);

//     erc721ETH.safeMint(SELLERS[0]);
//     uint256 tokenId = 0;
//     uint128 price = 1e9;

//     vm.startPrank(SELLERS[0], SELLERS[0]);
//     erc721ETH.setApprovalForAll(address(trove), true);
//     trove.createListing(
//       address(erc721ETH),
//       tokenId,
//       1,
//       price,
//       uint64(block.timestamp + 100),
//       address(weth)
//     );
//     vm.stopPrank();

//     BuyItemParams[] memory buyParams = new BuyItemParams[](1);
//     buyParams[0] = BuyItemParams(
//       address(erc721ETH),
//       tokenId,
//       SELLERS[0],
//       1,
//       price,
//       address(weth),
//       true
//     );

//     payable(BUYER).transfer(price);
//     uint256 sellerBalanceETHBefore = SELLERS[0].balance;
//     uint256 buyerBalanceETHBefore = BUYER.balance;
//     vm.prank(BUYER, BUYER);
//     ITroveSmolSweeper(address(smolsweep)).sweepItemsSingleToken{value: price}(
//       buyParams,
//       0,
//       address(weth),
//       price,
//       price,
//       1,
//       1
//     );
//     uint256 sellerBalanceETHAfter = SELLERS[0].balance;
//     uint256 buyerBalanceETHAfter = BUYER.balance;

//     assertEq(sellerBalanceETHAfter - sellerBalanceETHBefore, price);
//     assertEq(buyerBalanceETHBefore - buyerBalanceETHAfter, price);
//     assertEq(erc721ETH.balanceOf(SELLERS[0]), 0);
//     assertEq(erc721ETH.balanceOf(BUYER), 1);
//     assertEq(erc721ETH.ownerOf(0), BUYER);
//   }

//   function test_sweepItemsMultiTokensUsingETHSingleERC721() public {
//     magic.mint(OWNER, 1e18);

//     erc721ETH.safeMint(SELLERS[0]);
//     uint256 tokenId = 0;
//     uint128 price = 1e9;

//     vm.startPrank(SELLERS[0], SELLERS[0]);
//     erc721ETH.setApprovalForAll(address(trove), true);
//     trove.createListing(
//       address(erc721ETH),
//       tokenId,
//       1,
//       price,
//       uint64(block.timestamp + 100),
//       address(weth)
//     );
//     vm.stopPrank();

//     BuyItemParams[] memory buyParams = new BuyItemParams[](1);
//     buyParams[0] = BuyItemParams(
//       address(erc721ETH),
//       tokenId,
//       SELLERS[0],
//       1,
//       price,
//       address(weth),
//       true
//     );

//     address[] memory tokens = new address[](1);
//     tokens[0] = address(weth);
//     uint256[] memory maxSpends = new uint256[](1);
//     maxSpends[0] = price;
//     uint256[] memory minSpends = new uint256[](1);
//     minSpends[0] = price;

//     payable(BUYER).transfer(price);
//     uint256 sellerBalanceETHBefore = SELLERS[0].balance;
//     uint256 buyerBalanceETHBefore = BUYER.balance;

//     vm.prank(BUYER, BUYER);
//     ITroveSmolSweeper(address(smolsweep)).sweepItemsMultiTokens{value: price}(
//       buyParams,
//       0,
//       tokens,
//       maxSpends,
//       minSpends,
//       1,
//       1
//     );
//     uint256 sellerBalanceETHAfter = SELLERS[0].balance;
//     uint256 buyerBalanceETHAfter = BUYER.balance;

//     assertEq(sellerBalanceETHAfter - sellerBalanceETHBefore, price);
//     assertEq(buyerBalanceETHBefore - buyerBalanceETHAfter, price);
//     assertEq(erc721ETH.balanceOf(SELLERS[0]), 0);
//     assertEq(erc721ETH.balanceOf(BUYER), 1);
//     assertEq(erc721ETH.ownerOf(0), BUYER);
//   }

//   function test_sweepItemsManyTokenUsingETHAndMagicSingleERC721() public {
//     magic.mint(BUYER, 1e18);

//     erc721.safeMint(SELLERS[0]);
//     erc721ETH.safeMint(SELLERS[1]);
//     uint256 tokenId = 0;

//     uint128 price0 = 1e9;
//     uint128 price1 = 1e9;

//     {
//       vm.startPrank(SELLERS[0], SELLERS[0]);
//       erc721.setApprovalForAll(address(trove), true);
//       trove.createListing(
//         address(erc721),
//         tokenId,
//         1,
//         price1,
//         uint64(block.timestamp + 100),
//         address(magic)
//       );
//       vm.stopPrank();

//       vm.startPrank(SELLERS[1], SELLERS[1]);
//       erc721ETH.setApprovalForAll(address(trove), true);
//       trove.createListing(
//         address(erc721ETH),
//         tokenId,
//         1,
//         price0,
//         uint64(block.timestamp + 100),
//         address(weth)
//       );
//       vm.stopPrank();

//       vm.prank(BUYER, BUYER);
//       magic.approve(address(smolsweep), 1e19);
//       BuyItemParams[] memory buyParams = new BuyItemParams[](2);
//       buyParams[0] = BuyItemParams(
//         address(erc721),
//         tokenId,
//         SELLERS[0],
//         1,
//         price0,
//         address(magic),
//         false
//       );
//       buyParams[1] = BuyItemParams(
//         address(erc721ETH),
//         tokenId,
//         SELLERS[1],
//         1,
//         price1,
//         address(weth),
//         true
//       );

//       address[] memory tokens = new address[](2);
//       tokens[0] = address(magic);
//       tokens[1] = address(weth);
//       uint256[] memory maxSpends = new uint256[](2);
//       maxSpends[0] = price0;
//       maxSpends[1] = price1;
//       uint256[] memory minSpends = new uint256[](2);
//       minSpends[0] = price0;
//       minSpends[1] = price1;

//       payable(BUYER).transfer(price1);
//       uint256 seller0BalanceMagicBefore = magic.balanceOf(SELLERS[0]);
//       uint256 seller1BalanceETHBefore = SELLERS[1].balance;
//       uint256 buyerBalanceMagicBefore = magic.balanceOf(BUYER);
//       uint256 buyerBalanceETHBefore = BUYER.balance;

//       vm.prank(BUYER, BUYER);
//       ITroveSmolSweeper(address(smolsweep)).sweepItemsMultiTokens{
//         value: price1
//       }(buyParams, 0, tokens, maxSpends, minSpends, 2, 2);
//       uint256 seller0BalanceMagicAfter = magic.balanceOf(SELLERS[0]);
//       uint256 seller1BalanceETHAfter = SELLERS[1].balance;
//       uint256 buyerBalanceMagicAfter = magic.balanceOf(BUYER);
//       uint256 buyerBalanceETHAfter = BUYER.balance;

//       assertEq(seller0BalanceMagicAfter - seller0BalanceMagicBefore, price0);
//       assertEq(seller1BalanceETHAfter - seller1BalanceETHBefore, price1);
//       assertEq(buyerBalanceMagicBefore - buyerBalanceMagicAfter, price0);
//       assertEq(buyerBalanceETHBefore - buyerBalanceETHAfter, price1);
//     }

//     assertEq(erc721.balanceOf(BUYER), 1);
//     assertEq(erc721.balanceOf(SELLERS[0]), 0);
//     assertEq(erc721.ownerOf(tokenId), BUYER);
//     assertEq(erc721ETH.balanceOf(BUYER), 1);
//     assertEq(erc721ETH.balanceOf(SELLERS[1]), 0);
//     assertEq(erc721ETH.ownerOf(tokenId), BUYER);
//   }

//   receive() external payable {}
// }
