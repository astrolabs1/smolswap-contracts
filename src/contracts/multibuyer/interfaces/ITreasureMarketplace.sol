// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
interface ITreasureMarketplace {
    struct Listing {
        uint256 quantity;
        uint256 pricePerItem;
        uint256 expirationTime;
    }

    function listings(
        address _nftAddress,
        uint256 _tokenId,
        address _seller
    ) external view returns (Listing memory);

    function createListing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _pricePerItem,
        uint256 _expirationTime
    ) external;

    function updateListing(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _newQuantity,
        uint256 _newPricePerItem,
        uint256 _newExpirationTime
    ) external;

    function cancelListing(address _nftAddress, uint256 _tokenId) external;

    function buyItem(
        address _nftAddress,
        uint256 _tokenId,
        address _owner,
        uint256 _quantity
    ) external;

    function addToWhitelist(address _nft) external;

    function removeFromWhitelist(address _nft) external;
}