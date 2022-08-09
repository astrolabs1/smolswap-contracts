// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "@forge-std/src/Script.sol";
import "@contracts/sweep/SmolSweeper.sol";

import "@contracts/treasure/trove/TroveMarketplace.sol";
import "@contracts/treasure/assets/magic-token/Magic.sol";
import "@contracts/weth/WETH9.sol";
import "@contracts/assets/erc721/NFTERC721.sol";
import "@contracts/assets/erc1155/NFTERC1155.sol";
import "@contracts/token/ANFTReceiver.sol";

import "@contracts/sweep/interfaces/ITroveSmolSweeper.sol";

import "@contracts/sweep/diamond/interfaces/IDiamondCut.sol";
import "@contracts/sweep/diamond/facets/DiamondCutFacet.sol";
import "@contracts/sweep/diamond/facets/OwnershipFacet.sol";
// import "@contracts/sweep/diamond/facets/sweep/SweepTroveFacet.sol";
import "@contracts/sweep/diamond/facets/sweep/SweepFacet.sol";
import {DiamondLoupeFacet} from "@contracts/sweep/diamond/facets/DiamondLoupeFacet.sol";
import "@contracts/sweep/diamond/Diamond.sol";

contract MyScript is Script, IDiamondCut {
  SmolSweeper public smolsweep;
  DiamondCutFacet dCutFacet;
  DiamondLoupeFacet dLoupe;
  OwnershipFacet ownerF;
  SweepFacet sweepF;
  IDiamondInit init;

  function run() external {
    vm.startBroadcast();
    //deploy facets
    dCutFacet = new DiamondCutFacet();
    smolsweep = new SmolSweeper(
      0x5Fc8A00e4141165BCb67419a7498959E4351cc94,
      address(dCutFacet)
    );
    dLoupe = new DiamondLoupeFacet();
    ownerF = new OwnershipFacet();
    sweepF = new SweepFacet();

    //build cut struct
    FacetCut[] memory cut = new FacetCut[](3);

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

    // add it's immutable function selectors
    // cut[2] = (
    //   FacetCut({
    //     facetAddress: address(sweepF),
    //     action: FacetCutAction.Add,
    //     functionSelectors: generateSelectors("SweepTroveFacet")
    //   })
    // );

    //upgrade diamond
    IDiamondCut(address(smolsweep)).diamondCut(cut, address(init), "");

    SweepFacet(address(smolsweep)).addMarketplace(
      address(0x09986B4e255B3c548041a30A2Ee312Fe176731c2),
      address(0xd1D7B842D04C43FDe2B91453E91d678506A0620B)
    );

    SweepFacet(address(smolsweep)).addMarketplace(
      address(0xE5c7b4865D7f2B08FaAdF3F6d392E6D6Fa7B903C),
      address(0)
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
