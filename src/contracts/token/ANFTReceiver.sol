// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../token/ERC1155/AERC1155Receiver.sol";
import "../token/ERC721/AERC721Receiver.sol";

abstract contract ANFTReceiver is AERC721Receiver, AERC1155Receiver {}
