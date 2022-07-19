// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../token/ERC1155/AERC1155Receiver2.sol";
import "../token/ERC721/AERC721Receiver2.sol";

abstract contract ANFTReceiver2 is AERC721Receiver2, AERC1155Receiver2 {}
