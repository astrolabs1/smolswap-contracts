// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.14;

// import "@forge-std/src/Test.sol";
// import {SmolSweeper} from "@contracts/sweep/SmolSweeper.sol";

// import "@contracts/sweep/structs/BuyOrder.sol";
// import "@contracts/treasure/trove/TroveMarketplace.sol";
// import "@contracts/treasure/assets/magic-token/Magic.sol";
// import "@contracts/weth/WETH9.sol";
// import "@contracts/assets/erc721/NFTERC721.sol";
// import "@contracts/assets/erc1155/NFTERC1155.sol";
// import "@contracts/token/ANFTReceiver.sol";

// import "@contracts/sweep/interfaces/ISmolSweeper.sol";

// import {IDiamondCut} from "@contracts/sweep/diamond/interfaces/IDiamondCut.sol";
// import {IDiamondInit} from "@contracts/sweep/diamond/interfaces/IDiamondInit.sol";
// import {DiamondCutFacet} from "@contracts/sweep/diamond/facets/DiamondCutFacet.sol";
// import {DiamondLoupeFacet} from "@contracts/sweep/diamond/facets/DiamondLoupeFacet.sol";
// import {Diamond} from "@contracts/sweep/diamond/Diamond.sol";
// import {OwnershipFacet} from "@contracts/sweep/diamond/facets/OwnershipFacet.sol";
// import {BaseSweepFacet} from "@contracts/sweep/diamond/facets/sweep/BaseSweepFacet.sol";
// import {MarketplacesFacet} from "@contracts/sweep/diamond/facets/sweep/MarketplacesFacet.sol";
// import {SweepFacet} from "@contracts/sweep/diamond/facets/sweep/SweepFacet.sol";
// import {SweepSwapFacet} from "@contracts/sweep/diamond/facets/sweep/SweepSwapFacet.sol";

// import {LibSweep} from "@contracts/sweep/diamond/libraries/LibSweep.sol";
// import {LibMarketplaces} from "@contracts/sweep/diamond/libraries/LibMarketplaces.sol";

// import "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";
// import "@uniswap/v2-core/contracts/UniswapV2Factory.sol";

// contract MyScript is Test, IDiamondCut {
//   SmolSweeper smolsweep;
//   DiamondCutFacet dCutFacet;
//   DiamondLoupeFacet dLoupe;
//   OwnershipFacet ownerF;
//   BaseSweepFacet baseF;
//   MarketplacesFacet marketF;
//   SweepFacet sweepF;
//   SweepSwapFacet sweepSwapF;

//   IDiamondInit init;

//   UniswapV2Router02 uniswapRouter;
//   UniswapV2Router02 sushiswapRouter;

//   UniswapV2Factory uniswapFactory;
//   UniswapV2Factory sushiswapfactory;

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
//     sweepF = new SweepFacet();
//     baseF = new BaseSweepFacet();
//     marketF = new MarketplacesFacet();

//     init = new SmolSweepDiamondInit();
//     // init = new DiamondInit();

//     //build cut struct
//     FacetCut[] memory cut = new FacetCut[](6);

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
//         functionSelectors: generateSelectors("SweepFacet")
//       })
//     );

//     cut[3] = (
//       FacetCut({
//         facetAddress: address(baseF),
//         action: FacetCutAction.Add,
//         functionSelectors: generateSelectors("BaseSweepFacet")
//       })
//     );

//     cut[4] = (
//       FacetCut({
//         facetAddress: address(marketF),
//         action: FacetCutAction.Add,
//         functionSelectors: generateSelectors("MarketplacesFacet")
//       })
//     );

//     cut[5] = (
//       FacetCut({
//         facetAddress: address(smolsweep),
//         action: FacetCutAction.Add,
//         functionSelectors: generateSelectors("SmolSweeper")
//       })
//     );

//     //upgrade diamond
//     IDiamondCut(address(smolsweep)).diamondCut(
//       cut,
//       address(init),
//       abi.encodePacked(IDiamondInit.init.selector)
//     );

//     address[] memory troveTokens = new address[](1);
//     troveTokens[0] = address(magic);
//     MarketplacesFacet(address(smolsweep)).addMarketplace(
//       address(0x09986B4e255B3c548041a30A2Ee312Fe176731c2),
//       // LibMarketplaces.TROVE_ID,
//       troveTokens
//     );

//     address[] memory stratosTokens = new address[](1);
//     stratosTokens[0] = address(0);
//     MarketplacesFacet(address(smolsweep)).addMarketplace(
//       address(0x998EF16Ea4111094EB5eE72fC2c6f4e6E8647666),
//       // LibMarketplaces.STRATOS_ID,
//       // address(0xE5c7b4865D7f2B08FaAdF3F6d392E6D6Fa7B903C),
//       stratosTokens
//     );

//     uniswapFactory = new UniswapV2Factory(OWNER);
//     sushiswapFactory = new UniswapV2Factory(OWNER);

//     uniswapRouter = new UniswapV2Router02(uniswapFactory, weth);
//     sushiswapRouter = new UniswapV2Router02(sushiswapFactory, weth);

//     uint256 liquidity = 1e18;
//     magic.mint(address(this), liquidity);
//     magic.approve(address(uniswapRouter), liquidity);
//     uniswapRouter.addLiquidityETH(
//       address(magic),
//       liquidity / 2,
//       liquidity / 2,
//       liquidity / 2,
//       address(OWNER),
//       block.timestamp + 1
//     );
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
// }
