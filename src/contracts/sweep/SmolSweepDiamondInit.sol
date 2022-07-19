// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IDiamondLoupe} from "./diamond/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "./diamond/interfaces/IDiamondCut.sol";
import {IERC173} from "./diamond/interfaces/IERC173.sol";
import {IDiamondInit} from "./diamond/interfaces/IDiamondInit.sol";
import {LibDiamond} from "./diamond/libraries/LibDiamond.sol";

contract SmolSweepDiamondInit is IDiamondInit {
  // You can add parameters to this function in order to pass in
  // data to set your own state variables
  function init() external {
    // adding ERC165 data
    LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
    ds.supportedInterfaces[type(IERC165).interfaceId] = true;
    ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
    ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
    ds.supportedInterfaces[type(IERC173).interfaceId] = true;

    // add your own state variables
    // EIP-2535 specifies that the `diamondCut` function takes two optional
    // arguments: address _init and bytes calldata _calldata
    // These arguments are used to execute an arbitrary function using delegatecall
    // in order to set state variables in the diamond during deployment or an upgrade
    // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface
    ds.supportedInterfaces[type(IERC1155Receiver).interfaceId] = true;
    ds.supportedInterfaces[type(IERC721Receiver).interfaceId] = true;
  }
}
