// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@forge-std/src/Test.sol";

import {IDiamondCut} from "@contracts/sweep/diamond/interfaces/IDiamondCut.sol";

contract ABaseDiamondTest is Test, IDiamondCut {
  function generateSelectors(string memory _facetName)
    internal
    returns (bytes4[] memory selectors)
  {
    string[] memory cmd = new string[](4);
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
