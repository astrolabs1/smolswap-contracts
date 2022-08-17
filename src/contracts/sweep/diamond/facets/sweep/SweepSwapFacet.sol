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
    address[] calldata _paymentTokens,
    Swap[] calldata _swaps
  ) external payable {
    uint256 length = _swaps.length;
    uint256[] memory amounts = new uint256[](_paymentTokens.length);
    for (uint256 i = 0; i < length; i++) {
      uint256 tokenInd = LibSweep._getTokenIndex(
        _paymentTokens,
        (_buyOrders[i].usingETH) ? address(0) : _buyOrders[i].paymentToken
      );
      if (_swaps[i].swapType == SwapType.SWAP_ETH_TO_EXACT_TOKEN) {
        _swaps[i].router.swapETHForExactTokens{value: msg.value}(
          _swaps[i].amountOut,
          _swaps[i].path,
          address(this),
          _swaps[i].deadline
        );
        amounts[tokenInd] = _swaps[i].amountOut;
      } else if (_swaps[i].swapType == SwapType.SWAP_TOKEN_TO_EXACT_TOKEN) {
        if (msg.value != 0) revert MsgValueShouldBeZero();
        IERC20(_swaps[i].path[0]).transferFrom(
          msg.sender,
          address(this),
          _swaps[i].amountIn
        );
        IERC20(_swaps[i].path[0]).approve(
          address(_swaps[i].router),
          _swaps[i].amountIn
        );
        _swaps[i].router.swapTokensForExactTokens(
          _swaps[i].amountOut,
          _swaps[i].amountIn,
          _swaps[i].path,
          address(this),
          _swaps[i].deadline
        );
        amounts[tokenInd] = _swaps[i].amountOut;
      } else if (_swaps[i].swapType == SwapType.SWAP_TOKEN_TO_EXACT_ETH) {
        if (msg.value != 0) revert MsgValueShouldBeZero();
        IERC20(_swaps[i].path[0]).transferFrom(
          msg.sender,
          address(this),
          _swaps[i].amountIn
        );
        IERC20(_swaps[i].path[0]).approve(
          address(_swaps[i].router),
          _swaps[i].amountIn
        );
        _swaps[i].router.swapTokensForExactETH(
          _swaps[i].amountOut,
          _swaps[i].amountIn,
          _swaps[i].path,
          address(this),
          _swaps[i].deadline
        );
        amounts[tokenInd] = _swaps[i].amountOut;
      } else if (_swaps[i].swapType == SwapType.NO_SWAP) {
        if (msg.value != 0) revert MsgValueShouldBeZero();
        IERC20(_swaps[i].path[0]).transferFrom(
          msg.sender,
          address(this),
          _swaps[i].amountIn
        );
        amounts[tokenInd] = _swaps[i].amountIn;
      } else revert WrongSwapType();
    }

    (uint256[] memory totalSpentAmount, uint256 successCount) = LibSweep
      ._buyItemsMultiTokens(
        _buyOrders,
        _inputSettingsBitFlag,
        _paymentTokens,
        LibSweep._maxSpendWithoutFees(amounts)
      );

    // transfer back failed payment tokens to the buyer
    if (successCount == 0) revert AllReverted();

    for (uint256 i = 0; i < _paymentTokens.length; ++i) {
      uint256 refundAmount = amounts[i] -
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
}
