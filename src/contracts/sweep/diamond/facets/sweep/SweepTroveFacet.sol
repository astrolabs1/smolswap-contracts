// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

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

// import "@forge-std/src/console.sol";

contract SweepFacet is OwnershipModifers, ISmolSweeper {
  using SafeERC20 for IERC20;

  function buyItemsMultiTokens(
    MultiTokenBuyOrder[] calldata _buyOrders,
    uint16 _inputSettingsBitFlag,
    address[] calldata _paymentTokens,
    uint256[] calldata _maxSpendIncFees
  ) external payable {
    // transfer payment tokens to this contract
    // uint256 i = 0;
    uint256 length = _paymentTokens.length;

    for (uint256 i = 0; i < length; ++i) {
      if (_paymentTokens[i] == address(0)) {
        if (_maxSpendIncFees[i] != msg.value) revert InvalidMsgValue();
      } else {
        // transfer payment tokens to this contract
        IERC20(_paymentTokens[i]).safeTransferFrom(
          msg.sender,
          address(this),
          _maxSpendIncFees[i]
        );
      }
    }

    (uint256[] memory totalSpentAmount, uint256 successCount) = LibSweep
      ._buyItemsMultiTokens(
        _buyOrders,
        _inputSettingsBitFlag,
        _paymentTokens,
        LibSweep._maxSpendWithoutFees(_maxSpendIncFees)
      );

    // transfer back failed payment tokens to the buyer
    if (successCount == 0) revert AllReverted();

    for (uint256 i = 0; i < length; ++i) {
      uint256 refundAmount = _maxSpendIncFees[i] -
        (totalSpentAmount[i] + LibSweep._calculateFee(totalSpentAmount[i]));

      if (refundAmount > 0) {
        if (_paymentTokens[i] == address(0)) {
          payable(msg.sender).transfer(refundAmount);
          emit LibSweep.RefundedToken(address(0), refundAmount);
        } else {
          IERC20(_paymentTokens[i]).safeTransfer(msg.sender, refundAmount);
          emit LibSweep.RefundedToken(_paymentTokens[i], refundAmount);
        }
      }
    }
  }
}
