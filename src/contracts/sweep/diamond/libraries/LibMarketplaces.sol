// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../treasure/interfaces/ITroveMarketplace.sol";

import "@forge-std/src/console.sol";

struct MarketplaceData {
  address[] paymentTokens;
  uint16 marketplaceTypeId;
}

error InvalidMarketplaceId();
error InvalidMarketplace();

library LibMarketplaces {
  bytes32 constant DIAMOND_STORAGE_POSITION =
    keccak256("diamond.standard.sweep.storage");

  struct MarketplacesStorage {
    mapping(address => MarketplaceData) marketplacesData;
  }

  uint16 internal constant TROVE_ID = 0;
  uint16 internal constant STRATOS_ID = 1;

  function diamondStorage()
    internal
    pure
    returns (MarketplacesStorage storage ds)
  {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
      ds.slot := position
    }
  }

  function _addMarketplace(
    address _marketplace,
    uint16 _marketplaceTypeId,
    address[] memory _paymentTokens
  ) internal {
    if (_marketplace == address(0)) revert InvalidMarketplace();

    diamondStorage().marketplacesData[_marketplace] = MarketplaceData(
      _paymentTokens,
      _marketplaceTypeId
    );

    for (uint256 i = 0; i < _paymentTokens.length; i++) {
      console.log(i, _paymentTokens[i]);
      if (_paymentTokens[i] != address(0)) {
        IERC20(_paymentTokens[i]).approve(_marketplace, type(uint256).max);
      }
    }
  }

  function _setMarketplaceTypeId(
    address _marketplace,
    uint16 _marketplaceTypeId
  ) internal {
    diamondStorage()
      .marketplacesData[_marketplace]
      .marketplaceTypeId = _marketplaceTypeId;
  }

  function _addMarketplaceToken(address _marketplace, address _token) internal {
    diamondStorage().marketplacesData[_marketplace].paymentTokens.push(_token);
    IERC20(_token).approve(_marketplace, type(uint256).max);
  }

  function _getMarketplaceData(address _marketplace)
    internal
    view
    returns (MarketplaceData storage marketplaceData)
  {
    marketplaceData = diamondStorage().marketplacesData[_marketplace];
  }

  function _getMarketplacePaymentTokens(address _marketplace)
    internal
    view
    returns (address[] storage paymentTokens)
  {
    paymentTokens = diamondStorage()
      .marketplacesData[_marketplace]
      .paymentTokens;
  }
}
