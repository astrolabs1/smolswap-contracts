// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {LibSweep, PaymentTokenNotGiven} from "../../libraries/LibSweep.sol";
import {LibMarketplaces, MarketplaceData} from "../../libraries/LibMarketplaces.sol";
import "../OwnershipFacet.sol";

import "../../../../token/ANFTReceiver.sol";
import "../../../libraries/SettingsBitFlag.sol";
import "../../../libraries/Math.sol";
import "../../../../treasure/interfaces/ITroveMarketplace.sol";
import "../../../interfaces/ISmolSweeper.sol";
import "../../../errors/BuyError.sol";

contract MarketplacesFacet is OwnershipModifers {
  using SafeERC20 for IERC20;

  function TROVE_ID() external pure returns (uint256) {
    return LibMarketplaces.TROVE_ID;
  }

  function STRATOS_ID() external pure returns (uint256) {
    return LibMarketplaces.STRATOS_ID;
  }

  function addMarketplace(
    address _marketplace,
    uint16 _marketplaceTypeId,
    address[] memory _paymentTokens
  ) external onlyOwner {
    LibMarketplaces._addMarketplace(
      _marketplace,
      _marketplaceTypeId,
      _paymentTokens
    );
  }

  function setMarketplaceTypeId(address _marketplace, uint16 _marketplaceTypeId)
    external
    onlyOwner
  {
    LibMarketplaces._setMarketplaceTypeId(_marketplace, _marketplaceTypeId);
  }

  function addMarketplaceToken(address _marketplace, address _paymentToken)
    external
    onlyOwner
  {
    LibMarketplaces._addMarketplaceToken(_marketplace, _paymentToken);
  }

  function getMarketplaceData(address _marketplace)
    external
    view
    returns (MarketplaceData memory)
  {
    return LibMarketplaces._getMarketplaceData(_marketplace);
  }

  function getMarketplacePaymentTokens(address _marketplace)
    external
    view
    returns (address[] memory)
  {
    return LibMarketplaces._getMarketplacePaymentTokens(_marketplace);
  }
}
