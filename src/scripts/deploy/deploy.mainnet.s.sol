// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "@forge-std/src/Script.sol";
import {SmolSweeper} from "@contracts/sweep/SmolSweeper.sol";

// import "@contracts/treasure/trove/TroveMarketplace.sol";
// import "@contracts/treasure/assets/magic-token/Magic.sol";
// import "@contracts/weth/WETH9.sol";
// import "@contracts/assets/erc721/NFTERC721.sol";
// import "@contracts/assets/erc1155/NFTERC1155.sol";
// import "@contracts/token/ANFTReceiver.sol";

import {IDiamondCut} from "@contracts/sweep/diamond/interfaces/IDiamondCut.sol";
import {IDiamondInit} from "@contracts/sweep/diamond/interfaces/IDiamondInit.sol";
import {DiamondCutFacet} from "@contracts/sweep/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@contracts/sweep/diamond/facets/DiamondLoupeFacet.sol";
import {Diamond} from "@contracts/sweep/diamond/Diamond.sol";
import {OwnershipFacet} from "@contracts/sweep/diamond/facets/OwnershipFacet.sol";
import {BaseSweepFacet} from "@contracts/sweep/diamond/facets/sweep/BaseSweepFacet.sol";
import {MarketplacesFacet} from "@contracts/sweep/diamond/facets/sweep/MarketplacesFacet.sol";
import {SweepFacet} from "@contracts/sweep/diamond/facets/sweep/SweepFacet.sol";
import {SweepSwapFacet} from "@contracts/sweep/diamond/facets/sweep/SweepSwapFacet.sol";
import {LibMarketplaces} from "@contracts/sweep/diamond/libraries/LibMarketplaces.sol";
import {LibSweep} from "@contracts/sweep/diamond/libraries/LibSweep.sol";

contract MyScript is Script, IDiamondCut {
  SmolSweeper smolsweep;
  DiamondCutFacet dCutFacet;
  DiamondLoupeFacet dLoupe;
  OwnershipFacet ownerF;
  BaseSweepFacet baseF;
  MarketplacesFacet marketF;
  SweepFacet sweepF;
  SweepSwapFacet sweepSwapF;

  IDiamondInit init;

  function run() external {
    vm.startBroadcast();
    //deploy facets
    dCutFacet = new DiamondCutFacet();
    smolsweep = new SmolSweeper(
      0x46868d5F72251842289971867243F8dE54f5a127,
      address(dCutFacet)
    );
    dLoupe = new DiamondLoupeFacet();
    ownerF = new OwnershipFacet();
    baseF = new BaseSweepFacet();
    marketF = new MarketplacesFacet();
    sweepF = new SweepFacet();
    sweepSwapF = new SweepSwapFacet();

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
        facetAddress: address(baseF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("BaseSweepFacet")
      })
    );

    cut[3] = (
      FacetCut({
        facetAddress: address(marketF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("MarketplacesFacet")
      })
    );

    cut[4] = (
      FacetCut({
        facetAddress: address(sweepF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("SweepFacet")
      })
    );

    cut[5] = (
      FacetCut({
        facetAddress: address(sweepSwapF),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("SweepSwapFacet")
      })
    );

    // add it's immutable function selectors
    cut[6] = (
      FacetCut({
        facetAddress: address(smolsweep),
        action: FacetCutAction.Add,
        functionSelectors: generateSelectors("SmolSweeper")
      })
    );

    //upgrade diamond
    IDiamondCut(address(smolsweep)).diamondCut(cut, address(init), "");

    address[] memory troveTokens = new address[](3);
    troveTokens[0] = address(0);
    troveTokens[1] = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    troveTokens[2] = address(0xB0c7a3Ba49C7a6EaBa6cD4a96C55a1391070Ac9A);
    MarketplacesFacet(address(smolsweep)).addMarketplace(
      address(0x68D25992B1b04bE8A70104dE8Cb598170aB9aAD5),
      troveTokens
    );

    vm.stopBroadcast();
  }

  function generateSelectors(string memory _facetName)
    internal
    returns (bytes4[] memory selectors)
  {
    string[] memory cmd = new string[](4);
    // cmd[0] = "ls";
    cmd[0] = "node";
    cmd[1] = "scripts/genSelectors.js";
    cmd[2] = _facetName;
    cmd[3] = "fout";
    bytes memory res = vm.ffi(cmd);
    selectors = abi.decode(res, (bytes4[]));
  }

  function diamondCut(
    FacetCut[] calldata _diamondCut,
    address _init,
    bytes calldata _calldata
  ) external override {}
}
