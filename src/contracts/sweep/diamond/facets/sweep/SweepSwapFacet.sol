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

import "@contracts/sweep/structs/InputToken.sol";

error WrongInputType();

contract SweepSwapFacet is OwnershipModifers {
  using SafeERC20 for IERC20;
  using SettingsBitFlag for uint16;

  function swapOrdersMultiTokens(
    MultiTokenBuyOrder[] calldata _buyOrders,
    uint16 _inputSettingsBitFlag,
    address[] calldata _paymentTokens,
    InputToken[][] calldata _swapsArrs
  ) external payable {
    uint256 length = _swapsArrs.length;
    uint256[] memory amounts = new uint256[](_paymentTokens.length);

    for (uint256 i = 0; i < length; i++) {
      InputToken[] memory swaps = _swapsArrs[i];

      uint256[] memory swapAmounts;
      uint256 swapLength = swaps.length;
      for (uint256 j = 0; j < swapLength; i++) {
        if (swaps[i].inputType == InputType.PAYMENT_TOKENS) {
          IERC20(swaps[i].path[0]).transferFrom(
            msg.sender,
            address(this),
            swaps[i].amountIn
          );

          amounts[
            swaps[swaps.length - 1].tokenIndexes[
              swaps[swaps.length - 1].path.length - 1
            ]
          ] += swaps[i].amountIn;
        } else if (swaps[i].inputType == InputType.SWAP_EXACT_ETH_TO_TOKENS) {
          swapAmounts = IUniswapV2Router02(swaps[i].router)
            .swapExactETHForTokens{value: msg.value}(
            swaps[i].amountOut,
            swaps[i].path,
            address(this),
            swaps[i].deadline
          );
          amounts[
            swaps[swaps.length - 1].tokenIndexes[
              swaps[swaps.length - 1].path.length - 1
            ]
          ] += swapAmounts[swapAmounts.length - 1];
        } else if (swaps[i].inputType == InputType.SWAP_EXACT_TOKENS_TO_ETH) {
          IERC20(swaps[i].path[0]).transferFrom(
            msg.sender,
            address(this),
            swaps[i].amountIn
          );
          IERC20(swaps[i].path[0]).approve(swaps[i].router, swaps[i].amountIn);
          swapAmounts = IUniswapV2Router02(swaps[i].router)
            .swapTokensForExactETH(
              swaps[i].amountOut,
              swaps[i].amountIn,
              swaps[i].path,
              address(this),
              swaps[i].deadline
            );
          amounts[
            swaps[swaps.length - 1].tokenIndexes[
              swaps[swaps.length - 1].path.length - 1
            ]
          ] += swapAmounts[swapAmounts.length - 1];
        } else if (
          swaps[i].inputType == InputType.SWAP_EXACT_TOKENS_TO_TOKENS
        ) {
          IERC20(swaps[i].path[0]).transferFrom(
            msg.sender,
            address(this),
            swaps[i].amountIn
          );
          IERC20(swaps[i].path[0]).approve(swaps[i].router, swaps[i].amountIn);
          swapAmounts = IUniswapV2Router02(swaps[i].router)
            .swapTokensForExactTokens(
              swaps[i].amountOut,
              swaps[i].amountIn,
              swaps[i].path,
              address(this),
              swaps[i].deadline
            );
          amounts[
            swaps[swaps.length - 1].tokenIndexes[
              swaps[swaps.length - 1].path.length - 1
            ]
          ] += swapAmounts[swapAmounts.length - 1];
        } else if (swaps[i].inputType == InputType.SWAP_ETH_TO_EXACT_TOKENS) {
          swapAmounts = IUniswapV2Router02(swaps[i].router)
            .swapETHForExactTokens{value: msg.value}(
            swaps[i].amountOut,
            swaps[i].path,
            address(this),
            swaps[i].deadline
          );
          amounts[
            swaps[swaps.length - 1].tokenIndexes[
              swaps[swaps.length - 1].path.length - 1
            ]
          ] += swapAmounts[swapAmounts.length - 1];
        } else if (swaps[i].inputType == InputType.SWAP_TOKENS_TO_EXACT_ETH) {
          IERC20(swaps[i].path[0]).transferFrom(
            msg.sender,
            address(this),
            swaps[i].amountIn
          );
          IERC20(swaps[i].path[0]).approve(swaps[i].router, swaps[i].amountIn);
          swapAmounts = IUniswapV2Router02(swaps[i].router)
            .swapTokensForExactETH(
              swaps[i].amountOut,
              swaps[i].amountIn,
              swaps[i].path,
              address(this),
              swaps[i].deadline
            );

          amounts[
            swaps[swaps.length - 1].tokenIndexes[
              swaps[swaps.length - 1].path.length - 1
            ]
          ] += swapAmounts[swapAmounts.length - 1];
        } else if (
          swaps[i].inputType == InputType.SWAP_TOKENS_TO_EXACT_TOKENS
        ) {
          IERC20(swaps[i].path[0]).transferFrom(
            msg.sender,
            address(this),
            swaps[i].amountIn
          );
          IERC20(swaps[i].path[0]).approve(swaps[i].router, swaps[i].amountIn);
          swapAmounts = IUniswapV2Router02(swaps[i].router)
            .swapTokensForExactTokens(
              swaps[i].amountOut,
              swaps[i].amountIn,
              swaps[i].path,
              address(this),
              swaps[i].deadline
            );

          amounts[
            swaps[swaps.length - 1].tokenIndexes[
              swaps[swaps.length - 1].path.length - 1
            ]
          ] += swapAmounts[swapAmounts.length - 1];
          // refund extra input
        } else revert WrongInputType();
      }
    }

    (uint256[] memory totalSpentAmount, uint256 successCount) = LibSweep
      ._buyOrdersMultiTokens(
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
          address paymentToken = _paymentTokens[i];
          if (paymentToken == address(0)) {
            payable(msg.sender).transfer(refundAmount);
            emit LibSweep.RefundedToken(address(0), refundAmount);
          } else {
            IERC20(paymentToken).safeTransfer(msg.sender, refundAmount);
            emit LibSweep.RefundedToken(paymentToken, refundAmount);
          }
        }
      }
    }
  }
}
