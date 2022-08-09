// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

// import "@forge-std/src/Script.sol";
// import "@contracts/sweep/SmolSweeper.sol";

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

// contract MyScript is Script, IDiamondCut {
//   SmolSweeper public smolsweep;
//   DiamondCutFacet dCutFacet;
//   DiamondLoupeFacet dLoupe;
//   OwnershipFacet ownerF;
//   SweepTroveFacet sweepF;
//   IDiamondInit init;

//   function run() external {
//     vm.startBroadcast();
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

//     vm.stopBroadcast();
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
