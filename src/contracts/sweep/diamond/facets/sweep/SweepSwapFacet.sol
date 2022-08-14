// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../libraries/LibSweep.sol";
import "../OwnershipFacet.sol";

import "../../../../token/ANFTReceiver.sol";
import "../../../libraries/SettingsBitFlag.sol";
import "../../../libraries/Math.sol";
import "../../../../treasure/interfaces/ITroveMarketplace.sol";
import "../../../interfaces/ISmolSweeper.sol";
import "../../../errors/BuyError.sol";

import "../../../structs/BuyOrder.sol";

import "@v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "@contracts/sweep/structs/Swap.sol";

error WrongSwapType();

contract SweepSwapFacet is OwnershipModifers {
  using SafeERC20 for IERC20;
  using SettingsBitFlag for uint16;

  function swapBuyMultiTokens(
    MultiTokenBuyOrder[] calldata _buyOrders,
    uint16 _inputSettingsBitFlag,
    Swap[] calldata _swaps
  ) external payable {
    uint256 length = _swaps.length;
    for (uint256 i = 0; i < _swaps.length; i++) {
      if (_swaps[i].swapType == SwapType.SWAP_ETH_TO_EXACT_TOKEN) {
        _swaps[i].router.swapETHForExactTokens{value: msg.value}(
          _swaps[i].maxSpendIncFees,
          _swaps[i].path,
          address(this),
          _swaps[i].deadline
        );
      } else if (_swaps[i].swapType == SwapType.SWAP_TOKEN_TO_EXACT_TOKEN) {
        if (msg.value != 0) revert MsgValueShouldBeZero();
        IERC20(_swaps[i].path[0]).transferFrom(
          msg.sender,
          address(this),
          _swaps[i].maxInputTokenAmount
        );
        IERC20(_swaps[i].path[0]).approve(
          address(_swaps[i].router),
          _swaps[i].maxInputTokenAmount
        );
        _swaps[i].router.swapTokensForExactTokens(
          _swaps[i].maxSpendIncFees,
          _swaps[i].maxInputTokenAmount,
          _swaps[i].path,
          address(this),
          _swaps[i].deadline
        );
      } else if (_swaps[i].swapType == SwapType.SWAP_TOKEN_TO_EXACT_ETH) {
        if (msg.value != 0) revert MsgValueShouldBeZero();
        IERC20(_swaps[i].path[0]).transferFrom(
          msg.sender,
          address(this),
          _swaps[i].maxInputTokenAmount
        );
        IERC20(_swaps[i].path[0]).approve(
          address(_swaps[i].router),
          _swaps[i].maxInputTokenAmount
        );
        _swaps[i].router.swapTokensForExactETH(
          _swaps[i].maxSpendIncFees,
          _swaps[i].maxInputTokenAmount,
          _swaps[i].path,
          address(this),
          _swaps[i].deadline
        );
      }
    }

    (
      uint256[] memory totalSpentAmount,
      uint256 successCount
    ) = _swapBuyItemsMultiTokens(
        _buyOrders,
        _inputSettingsBitFlag,
        _swaps,
        LibSweep._maxSpendWithoutFees(_swaps)
      );

    // transfer back failed payment tokens to the buyer
    if (successCount == 0) revert AllReverted();

    for (uint256 i = 0; i < length; ++i) {
      uint256 refundAmount = _swaps[i].maxSpendIncFees -
        (totalSpentAmount[i] + LibSweep._calculateFee(totalSpentAmount[i]));

      if (refundAmount > 0) {
        if (
          _inputSettingsBitFlag.checkSetting(
            SettingsBitFlag.REFUND_IN_INPUT_TOKEN
          )
        ) {
          revert("Refund in input token is not supported");
        } else {
          if (_swaps[i].swapType == SwapType.SWAP_ETH_TO_EXACT_TOKEN) {
            payable(msg.sender).transfer(refundAmount);
            emit LibSweep.RefundedToken(address(0), refundAmount);
          } else {
            address paymentToken = _swaps[i].path[0];
            IERC20(paymentToken).safeTransfer(msg.sender, refundAmount);
            emit LibSweep.RefundedToken(paymentToken, refundAmount);
          }
        }
      }
    }
  }

  function _swapBuyItemsMultiTokens(
    MultiTokenBuyOrder[] memory _buyOrders,
    uint16 _inputSettingsBitFlag,
    Swap[] memory _swaps,
    uint256[] memory _maxSpends
  )
    internal
    returns (uint256[] memory totalSpentAmounts, uint256 successCount)
  {
    totalSpentAmounts = new uint256[](_swaps.length);
    // // buy all assets
    for (uint256 i = 0; i < _buyOrders.length; ++i) {
      uint256 j = LibSweep._getTokenIndex(
        _swaps,
        (_buyOrders[i].usingETH) ? address(0) : _buyOrders[i].paymentToken
      );

      if (_buyOrders[i].marketplaceId == LibSweep.TROVE_ID) {
        // check if the listing exists
        uint64 quantityToBuy;

        ITroveMarketplace.ListingOrBid memory listing = ITroveMarketplace(
          LibSweep.diamondStorage().marketplaces[LibSweep.TROVE_ID]
        ).listings(
            _buyOrders[i].assetAddress,
            _buyOrders[i].tokenId,
            _buyOrders[i].seller
          );

        // check if total price is less than max spend allowance left
        if (
          (listing.pricePerItem * _buyOrders[i].quantity) >
          (_maxSpends[j] - totalSpentAmounts[j]) &&
          SettingsBitFlag.checkSetting(
            _inputSettingsBitFlag,
            SettingsBitFlag.EXCEEDING_MAX_SPEND
          )
        ) break;

        // not enough listed items
        if (listing.quantity < _buyOrders[i].quantity) {
          if (
            SettingsBitFlag.checkSetting(
              _inputSettingsBitFlag,
              SettingsBitFlag.INSUFFICIENT_QUANTITY_ERC1155
            )
          ) {
            quantityToBuy = listing.quantity;
          } else {
            continue; // skip item
          }
        } else {
          quantityToBuy = uint64(_buyOrders[i].quantity);
        }

        // buy item
        (uint256 spentAmount, bool success) = LibSweep._troveOrderMultiToken(
          _buyOrders[i],
          quantityToBuy,
          _inputSettingsBitFlag
        );

        if (success) {
          totalSpentAmounts[j] += spentAmount;
          successCount++;
        }
      } else if (_buyOrders[i].marketplaceId == LibSweep.STRATOS_ID) {
        // check if total price is less than max spend allowance left
        if (
          (_buyOrders[i].price * _buyOrders[i].quantity) >
          _maxSpends[j] - totalSpentAmounts[j] &&
          SettingsBitFlag.checkSetting(
            _inputSettingsBitFlag,
            SettingsBitFlag.EXCEEDING_MAX_SPEND
          )
        ) break;

        (bool spentSuccess, bytes memory data) = LibSweep
          .tryBuyItemStratosMulti(_buyOrders[i], payable(msg.sender));

        if (spentSuccess) {
          if (
            SettingsBitFlag.checkSetting(
              _inputSettingsBitFlag,
              SettingsBitFlag.EMIT_SUCCESS_EVENT_LOGS
            )
          ) {
            emit LibSweep.SuccessBuyItem(
              _buyOrders[0].assetAddress,
              _buyOrders[0].tokenId,
              payable(msg.sender),
              _buyOrders[0].quantity,
              _buyOrders[i].price
            );
          }
          totalSpentAmounts[j] += _buyOrders[i].price * _buyOrders[i].quantity;
          successCount++;
        } else {
          if (
            SettingsBitFlag.checkSetting(
              _inputSettingsBitFlag,
              SettingsBitFlag.EMIT_FAILURE_EVENT_LOGS
            )
          ) {
            emit LibSweep.CaughtFailureBuyItem(
              _buyOrders[0].assetAddress,
              _buyOrders[0].tokenId,
              payable(msg.sender),
              _buyOrders[0].quantity,
              _buyOrders[i].price,
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
      } else revert InvalidMarketplaceId();
    }
  }
}
