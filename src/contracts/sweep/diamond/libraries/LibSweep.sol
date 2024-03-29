// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../treasure/interfaces/ITroveMarketplace.sol";

import {LibDiamond} from "./LibDiamond.sol";
import {LibMarketplaces, MarketplaceType} from "./LibMarketplaces.sol";

import "../../errors/BuyError.sol";
import "../../../token/ANFTReceiver.sol";
import "../../libraries/SettingsBitFlag.sol";
import "../../libraries/Math.sol";
import "../../../treasure/interfaces/ITroveMarketplace.sol";
import "../../../stratos/ExchangeV5.sol";

import "../../structs/BuyOrder.sol";

import "@contracts/sweep/structs/InputToken.sol";

import "@seaport/contracts/lib/ConsiderationStructs.sol";
import "@seaport/contracts/interfaces/SeaportInterface.sol";

// import "@forge-std/src/console.sol";

error InvalidNFTAddress();
error FirstBuyReverted(bytes message);
error AllReverted();

error InvalidMsgValue();
error MsgValueShouldBeZero();
error PaymentTokenNotGiven(address _paymentToken);
error NotEnoughPaymentToken(address _paymentToken, uint256 _amount);

library LibSweep {
  using SafeERC20 for IERC20;

  event SuccessBuyItem(
    address indexed _nftAddress,
    uint256 _tokenId,
    // address indexed _seller,
    address indexed _buyer,
    uint256 _quantity,
    uint256 _price
  );

  event CaughtFailureBuyItem(
    address indexed _nftAddress,
    uint256 _tokenId,
    // address indexed _seller,
    address indexed _buyer,
    uint256 _quantity,
    uint256 _price,
    bytes _errorReason
  );
  event RefundedToken(address tokenAddress, uint256 amount);

  bytes32 constant DIAMOND_STORAGE_POSITION =
    keccak256("diamond.standard.sweep.storage");

  struct SweepStorage {
    // owner of the contract
    uint256 sweepFee;
    IERC721 sweepNFT;
  }

  uint256 constant FEE_BASIS_POINTS = 1_000_000;

  bytes4 internal constant INTERFACE_ID_ERC721 = 0x80ac58cd;
  bytes4 internal constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

  function diamondStorage() internal pure returns (SweepStorage storage ds) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
      ds.slot := position
    }
  }

  function _calculateFee(uint256 _amount) internal view returns (uint256) {
    SweepStorage storage ds = diamondStorage();
    return (_amount * ds.sweepFee) / FEE_BASIS_POINTS;
  }

  function _calculateAmountWithoutFees(uint256 _amountWithFee)
    internal
    view
    returns (uint256)
  {
    SweepStorage storage ds = diamondStorage();
    return ((_amountWithFee * FEE_BASIS_POINTS) /
      (FEE_BASIS_POINTS + ds.sweepFee));
  }

  // function tryBuyItemTrove(
  //   address _troveMarketplace,
  //   BuyItemParams[] memory _buyItemParamsArr,
  //   bool _usingEth,
  //   uint256 _totalPrice
  // ) internal returns (bool success, bytes memory data) {
  //   (success, data) = _troveMarketplace.call{
  //     value: (_usingEth) ? (_totalPrice) : 0
  //   }(
  //     abi.encodeWithSelector(
  //       ITroveMarketplace.buyItems.selector,
  //       _buyItemParamsArr
  //     )
  //   );
  // }

  function _maxSpendWithoutFees(uint256[] memory _maxSpendIncFees)
    internal
    view
    returns (uint256[] memory maxSpends)
  {
    uint256 maxSpendLength = _maxSpendIncFees.length;
    maxSpends = new uint256[](maxSpendLength);

    for (uint256 i = 0; i < maxSpendLength; ) {
      maxSpends[i] = LibSweep._calculateAmountWithoutFees(_maxSpendIncFees[i]);
      unchecked {
        ++i;
      }
    }
  }

  function _buyOrdersMultiTokens(
    MultiTokenBuyOrder[] memory _buyOrders,
    uint16 _inputSettingsBitFlag,
    address[] memory _paymentTokens,
    uint256[] memory _maxSpends
  )
    internal
    returns (uint256[] memory totalSpentAmounts, uint256 successCount)
  {
    totalSpentAmounts = new uint256[](_paymentTokens.length);
    // // buy all assets
    for (uint256 i = 0; i < _buyOrders.length; ++i) {
      MultiTokenBuyOrder memory _buyOrder = _buyOrders[i];

      if (_buyOrder.marketplaceType == MarketplaceType.TROVE) {
        // check if the listing exists

        uint64 quantityToBuy = 0;
        uint256 pricesPerItem = 0;
        uint256 totalPrice = 0;
        ITroveMarketplace.ListingOrBid memory listing = ITroveMarketplace(
          _buyOrder.marketplaceAddress
        ).listings(
            _buyOrder.buyItemParamsOrder.nftAddress,
            _buyOrder.buyItemParamsOrder.tokenId,
            _buyOrder.buyItemParamsOrder.owner
          );

        // check if total price is less than max spend allowance left
        if (
          (listing.pricePerItem * _buyOrder.buyItemParamsOrder.quantity) >
          (_maxSpends[_buyOrder.tokenIndex] -
            totalSpentAmounts[_buyOrder.tokenIndex]) &&
          SettingsBitFlag.checkSetting(
            _inputSettingsBitFlag,
            SettingsBitFlag.EXCEEDING_MAX_SPEND
          )
        ) break;
        // not enough listed items
        if (listing.quantity < _buyOrder.buyItemParamsOrder.quantity) {
          if (
            SettingsBitFlag.checkSetting(
              _inputSettingsBitFlag,
              SettingsBitFlag.INSUFFICIENT_QUANTITY_ERC1155
            )
          ) quantityToBuy = listing.quantity;
          else continue; // skip item
        } else {
          quantityToBuy = uint64(_buyOrder.buyItemParamsOrder.quantity);
        }

        pricesPerItem = listing.pricePerItem;
        totalPrice += listing.pricePerItem * quantityToBuy;

        BuyItemParams[] memory buyItemParamsArr = new BuyItemParams[](1);
        buyItemParamsArr[0] = _buyOrder.buyItemParamsOrder;
        // buy item
        (bool success, bytes memory data) = _buyOrder.marketplaceAddress.call{
          value: (_buyOrder.buyItemParamsOrder.usingEth) ? (totalPrice) : 0
        }(
          abi.encodeWithSelector(
            ITroveMarketplace.buyItems.selector,
            buyItemParamsArr
          )
        );

        if (success) {
          if (
            SettingsBitFlag.checkSetting(
              _inputSettingsBitFlag,
              SettingsBitFlag.EMIT_SUCCESS_EVENT_LOGS
            )
          ) {
            emit LibSweep.SuccessBuyItem(
              _buyOrder.buyItemParamsOrder.nftAddress,
              _buyOrder.buyItemParamsOrder.tokenId,
              payable(msg.sender),
              quantityToBuy,
              pricesPerItem
            );
          }
          if (
            IERC165(_buyOrder.buyItemParamsOrder.nftAddress).supportsInterface(
              LibSweep.INTERFACE_ID_ERC721
            )
          ) {
            IERC721(_buyOrder.buyItemParamsOrder.nftAddress).safeTransferFrom(
              address(this),
              msg.sender,
              _buyOrder.buyItemParamsOrder.tokenId
            );
          } else if (
            IERC165(_buyOrder.buyItemParamsOrder.nftAddress).supportsInterface(
              LibSweep.INTERFACE_ID_ERC1155
            )
          ) {
            IERC1155(_buyOrder.buyItemParamsOrder.nftAddress).safeTransferFrom(
              address(this),
              msg.sender,
              _buyOrder.buyItemParamsOrder.tokenId,
              quantityToBuy,
              ""
            );
          } else revert InvalidNFTAddress();
          success = true;
          totalSpentAmounts[_buyOrder.tokenIndex] += totalPrice;
          successCount++;
        } else {
          if (
            SettingsBitFlag.checkSetting(
              _inputSettingsBitFlag,
              SettingsBitFlag.EMIT_FAILURE_EVENT_LOGS
            )
          ) {
            emit LibSweep.CaughtFailureBuyItem(
              _buyOrder.buyItemParamsOrder.nftAddress,
              _buyOrder.buyItemParamsOrder.tokenId,
              payable(msg.sender),
              _buyOrder.buyItemParamsOrder.quantity,
              pricesPerItem,
              data
            );
          }
          if (
            SettingsBitFlag.checkSetting(
              _inputSettingsBitFlag,
              SettingsBitFlag.MARKETPLACE_BUY_ITEM_REVERTED
            )
          ) revert FirstBuyReverted(data);
        }
        success = false;
      } else if (_buyOrder.marketplaceType == MarketplaceType.SEAPORT_V1) {
        // check if total price is less than max spend allowance left
        // if (
        //   (_buyOrder.price * _buyOrder.quantity) >
        //   _maxSpends[_buyOrder.tokenIndex] - totalSpentAmounts[_buyOrder.tokenIndex] &&
        //   SettingsBitFlag.checkSetting(
        //     _inputSettingsBitFlag,
        //     SettingsBitFlag.EXCEEDING_MAX_SPEND
        //   )
        // ) break;

        Execution[] memory executions = SeaportInterface(
          _buyOrder.marketplaceAddress
        ).matchOrders{value: LibSweep._calculateAmountWithoutFees(msg.value)}(
          _buyOrder.seaportOrders,
          _buyOrder.fulfillments
        );

        // if (spentSuccess) {
        //   if (
        //     SettingsBitFlag.checkSetting(
        //       _inputSettingsBitFlag,
        //       SettingsBitFlag.EMIT_SUCCESS_EVENT_LOGS
        //     )
        //   ) {
        //     emit LibSweep.SuccessBuyItem(
        //       _buyOrders[0].assetAddress,
        //       _buyOrders[0].tokenId,
        //       payable(msg.sender),
        //       _buyOrders[0].quantity,
        //       _buyOrder.price
        //     );
        //   }
        //   totalSpentAmounts[_buyOrder.tokenIndex] += _buyOrder.price * _buyOrder.quantity;
        //   successCount++;
        // } else {
        //   if (
        //     SettingsBitFlag.checkSetting(
        //       _inputSettingsBitFlag,
        //       SettingsBitFlag.EMIT_FAILURE_EVENT_LOGS
        //     )
        //   ) {
        //     emit LibSweep.CaughtFailureBuyItem(
        //       _buyOrders[0].assetAddress,
        //       _buyOrders[0].tokenId,
        //       payable(msg.sender),
        //       _buyOrders[0].quantity,
        //       _buyOrder.price,
        //       data
        //     );
        //   }
        //   if (
        //     SettingsBitFlag.checkSetting(
        //       _inputSettingsBitFlag,
        //       SettingsBitFlag.MARKETPLACE_BUY_ITEM_REVERTED
        //     )
        //   ) revert FirstBuyReverted(data);
        // }
      } else revert InvalidMarketplaceId();
    }
  }
}
