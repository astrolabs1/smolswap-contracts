// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

struct BuyOrder {
    address assetAddress;
    uint256 tokenId;
    address seller;
    uint256 quantity;
    uint256 maxPricePerItem;
}
