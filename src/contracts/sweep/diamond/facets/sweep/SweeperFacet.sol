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

import "./ABaseSweeperFacet.sol";

import "../../../structs/BuyOrder.sol";

contract SweepFacet is OwnershipModifers, ISmolSweeper, ABaseSweeperFacet {
  using SafeERC20 for IERC20;

  function buyItemsSingleToken(
    BuyOrder[] calldata _buyOrders,
    bytes[] memory _signatures,
    bool _usingETH,
    uint16 _inputSettingsBitFlag,
    address _paymentToken,
    uint256 _maxSpendIncFees
  ) external payable {
    if (_usingETH && msg.value > 0) {
      if (_maxSpendIncFees != msg.value) revert InvalidMsgValue();
    } else {
      if (msg.value != 0) revert MsgValueShouldBeZero();
      // transfer payment tokens to this contract
      IERC20(_paymentToken).safeTransferFrom(
        msg.sender,
        address(this),
        _maxSpendIncFees
      );
      IERC20(_paymentToken).approve(
        address(LibSweep.diamondStorage().troveMarketplace),
        _maxSpendIncFees
      );
    }
    (uint256 totalSpentAmount, uint256 successCount) = _buyItemsSingleToken(
      _buyOrders,
      _signatures,
      _paymentToken,
      _usingETH,
      _inputSettingsBitFlag,
      _maxSpendIncFees
    );
    // transfer back failed payment tokens to the buyer
    if (successCount == 0) revert AllReverted();
    uint256 feeAmount = LibSweep._calculateFee(totalSpentAmount);
    if (_usingETH) {
      payable(msg.sender).transfer(
        _maxSpendIncFees - (totalSpentAmount + feeAmount)
      );
      // emit refunded event
    } else {
      IERC20(_paymentToken).safeTransfer(
        msg.sender,
        _maxSpendIncFees - (totalSpentAmount + feeAmount)
      );
    }
  }

  function _buyItemsSingleToken(
    BuyOrder[] memory _buyOrders,
    bytes[] memory _signatures,
    address _paymentToken,
    bool _usingETH,
    uint16 _inputSettingsBitFlag,
    uint256 _maxSpendIncFees
  ) internal returns (uint256 totalSpentAmount, uint256 successCount) {
    // buy all assets
    uint256 _maxSpendIncFees = LibSweep._calculateAmountWithoutFees(
      _maxSpendIncFees
    );

    // uint256 i = 0;
    // uint256 length = _buyOrders.length;
    for (uint256 i = 0; i < _buyOrders.length; ) {
      if (_buyOrders[i].marketplaceId == LibSweep.TROVE_ID) {
        (uint256 spentAmount, bool spentSuccess, BuyError buyError) = LibSweep
          .tryBuyItemTrove(
            BuyItemParams(
              _buyOrders[i].assetAddress,
              _buyOrders[i].tokenId,
              _buyOrders[i].seller,
              uint64(_buyOrders[i].quantity),
              uint128(_buyOrders[i].price),
              _paymentToken,
              _usingETH
            ),
            _inputSettingsBitFlag,
            _maxSpendIncFees - totalSpentAmount
          );

        if (spentSuccess) {
          totalSpentAmount += spentAmount;
          successCount++;
        } else {
          if (
            buyError == BuyError.EXCEEDING_MAX_SPEND &&
            SettingsBitFlag.checkSetting(
              _inputSettingsBitFlag,
              SettingsBitFlag.EXCEEDING_MAX_SPEND
            )
          ) break;
        }
      } else if (_buyOrders[i].marketplaceId == LibSweep.STRATOS_ID) {
        (uint256 spentAmount, bool spentSuccess, BuyError buyError) = LibSweep
          .tryBuyItemStratos(
            _buyOrders[i],
            _paymentToken,
            _signatures[i],
            payable(msg.sender),
            _inputSettingsBitFlag,
            _maxSpendIncFees - totalSpentAmount
          );
        if (spentSuccess) {
          totalSpentAmount += spentAmount;
          successCount++;
        } else {
          if (
            buyError == BuyError.EXCEEDING_MAX_SPEND &&
            SettingsBitFlag.checkSetting(
              _inputSettingsBitFlag,
              SettingsBitFlag.EXCEEDING_MAX_SPEND
            )
          ) break;
        }
      } else {
        revert InvalidMarketplaceId();
      }

      unchecked {
        ++i;
      }
    }
  }

  function buyItemsMultiTokens(
    BuyItemParams[] calldata _buyOrders,
    uint16 _inputSettingsBitFlag,
    address[] calldata _paymentTokens,
    uint256[] calldata _maxSpendIncFees
  ) external payable {
    // transfer payment tokens to this contract
    uint256 i = 0;
    uint256 length = _paymentTokens.length;

    for (; i < length; ) {
      if (
        _paymentTokens[i] == address(LibSweep.diamondStorage().weth) &&
        msg.value > 0
      ) {
        if (_maxSpendIncFees[i] != msg.value) revert InvalidMsgValue();
      } else {
        // if (msg.value != 0) revert MsgValueShouldBeZero();
        // transfer payment tokens to this contract
        IERC20(_paymentTokens[i]).safeTransferFrom(
          msg.sender,
          address(this),
          _maxSpendIncFees[i]
        );
        IERC20(_paymentTokens[i]).approve(
          address(LibSweep.diamondStorage().troveMarketplace),
          _maxSpendIncFees[i]
        );
      }

      unchecked {
        ++i;
      }
    }

    uint256[] memory maxSpends = _maxSpendWithoutFees(_maxSpendIncFees);
    (
      uint256[] memory totalSpentAmount,
      uint256 successCount
    ) = _buyItemsMultiTokens(
        _buyOrders,
        _inputSettingsBitFlag,
        _paymentTokens,
        maxSpends
      );

    // transfer back failed payment tokens to the buyer
    if (successCount == 0) revert AllReverted();

    i = 0;
    for (; i < length; ) {
      uint256 feeAmount = LibSweep._calculateFee(totalSpentAmount[i]);

      if (
        _paymentTokens[i] == address(LibSweep.diamondStorage().weth) &&
        _buyOrders[0].usingEth
      ) {
        payable(msg.sender).transfer(
          _maxSpendIncFees[i] - (totalSpentAmount[i] + feeAmount)
        );
      } else {
        IERC20(_paymentTokens[i]).safeTransfer(
          msg.sender,
          _maxSpendIncFees[i] - (totalSpentAmount[i] + feeAmount)
        );
      }

      unchecked {
        ++i;
      }
    }
  }

  function _buyItemsMultiTokens(
    BuyItemParams[] memory _buyOrders,
    uint16 _inputSettingsBitFlag,
    address[] memory _inputTokenAddresses,
    uint256[] memory _maxSpends
  )
    internal
    returns (uint256[] memory totalSpentAmounts, uint256 successCount)
  {
    // totalSpentAmounts = new uint256[](_inputTokenAddresses.length);
    // // buy all assets
    // for (uint256 i = 0; i < _buyOrders.length; ) {
    //   uint256 j = _getTokenIndex(
    //     _inputTokenAddresses,
    //     _buyOrders[i].paymentToken
    //   );
    //   (uint256 spentAmount, bool spentSuccess, BuyError buyError) = tryBuyItem(
    //     _buyOrders[i],
    //     _inputSettingsBitFlag,
    //     _maxSpends[j] - totalSpentAmounts[j]
    //   );
    //   if (spentSuccess) {
    //     totalSpentAmounts[j] += spentAmount;
    //     successCount++;
    //   } else {
    //     if (
    //       buyError == BuyError.EXCEEDING_MAX_SPEND &&
    //       SettingsBitFlag.checkSetting(
    //         _inputSettingsBitFlag,
    //         SettingsBitFlag.EXCEEDING_MAX_SPEND
    //       )
    //     ) break;
    //   }
    //   unchecked {
    //     ++i;
    //   }
    // }
  }

  // function sweepItemsSingleToken(
  //   BuyOrder[] calldata _buyOrders,
  //   bytes[] memory _signatures,
  //   uint16 _inputSettingsBitFlag,
  //   address _inputTokenAddress,
  //   uint256 _maxSpendIncFees,
  //   uint256 _minSpend,
  //   uint32 _maxSuccesses,
  //   uint32 _maxFailures
  // ) external payable {
  //   // if (
  //   //   _inputTokenAddress == address(LibSweep.diamondStorage().weth) &&
  //   //   msg.value > 0
  //   // ) {
  //   //   if (_maxSpendIncFees != msg.value) revert InvalidMsgValue();
  //   // } else {
  //   //   if (msg.value != 0) revert MsgValueShouldBeZero();
  //   //   // transfer payment tokens to this contract
  //   //   IERC20(_inputTokenAddress).safeTransferFrom(
  //   //     msg.sender,
  //   //     address(this),
  //   //     _maxSpendIncFees
  //   //   );
  //   //   IERC20(_inputTokenAddress).approve(
  //   //     address(LibSweep.diamondStorage().troveMarketplace),
  //   //     _maxSpendIncFees
  //   //   );
  //   // }
  //   // (uint256 totalSpentAmount, uint256 successCount, ) = _sweepItemsSingleToken(
  //   //   _buyOrders,
  //   //   _inputSettingsBitFlag,
  //   //   _maxSpendIncFees,
  //   //   _minSpend,
  //   //   _maxSuccesses,
  //   //   _maxFailures
  //   // );
  //   // // transfer back failed payment tokens to the buyer
  //   // if (successCount == 0) revert AllReverted();
  //   // uint256 feeAmount = LibSweep._calculateFee(totalSpentAmount);
  //   // if (
  //   //   _inputTokenAddress == address(LibSweep.diamondStorage().weth) &&
  //   //   _buyOrders[0].usingEth
  //   // ) {
  //   //   payable(msg.sender).transfer(
  //   //     _maxSpendIncFees - (totalSpentAmount + feeAmount)
  //   //   );
  //   // } else {
  //   //   IERC20(_inputTokenAddress).safeTransfer(
  //   //     msg.sender,
  //   //     _maxSpendIncFees - (totalSpentAmount + feeAmount)
  //   //   );
  //   // }
  // }

  // function _sweepItemsSingleToken(
  //   BuyItemParams[] memory _buyOrders,
  //   uint16 _inputSettingsBitFlag,
  //   uint256 _maxSpendIncFees,
  //   uint256 _minSpend,
  //   uint32 _maxSuccesses,
  //   uint32 _maxFailures
  // )
  //   internal
  //   returns (
  //     uint256 totalSpentAmount,
  //     uint256 successCount,
  //     uint256 failCount
  //   )
  // {
  //   // buy all assets
  //   for (uint256 i = 0; i < _buyOrders.length; ) {
  //     if (successCount >= _maxSuccesses || failCount >= _maxFailures) break;

  //     if (totalSpentAmount >= _minSpend) break;

  //     (uint256 spentAmount, bool spentSuccess, BuyError buyError) = tryBuyItem(
  //       _buyOrders[i],
  //       _inputSettingsBitFlag,
  //       _maxSpendIncFees - totalSpentAmount
  //     );

  //     if (spentSuccess) {
  //       totalSpentAmount += spentAmount;
  //       successCount++;
  //     } else {
  //       if (
  //         buyError == BuyError.EXCEEDING_MAX_SPEND &&
  //         SettingsBitFlag.checkSetting(
  //           _inputSettingsBitFlag,
  //           SettingsBitFlag.EXCEEDING_MAX_SPEND
  //         )
  //       ) break;
  //       failCount++;
  //     }

  //     unchecked {
  //       ++i;
  //     }
  //   }
  // }

  // function sweepItemsMultiTokens(
  //   BuyOrder[] calldata _buyOrders,
  //   bytes[] memory _signatures,
  //   uint16 _inputSettingsBitFlag,
  //   address[] calldata _inputTokenAddresses,
  //   uint256[] calldata _maxSpendIncFees,
  //   uint256[] calldata _minSpends,
  //   uint32 _maxSuccesses,
  //   uint32 _maxFailures
  // ) external payable {
  //   // // transfer payment tokens to this contract
  //   // for (uint256 i = 0; i < _maxSpendIncFees.length; ) {
  //   //   if (
  //   //     _inputTokenAddresses[i] == address(LibSweep.diamondStorage().weth) &&
  //   //     msg.value > 0
  //   //   ) {
  //   //     if (_maxSpendIncFees[i] != msg.value) revert InvalidMsgValue();
  //   //   } else {
  //   //     // if (msg.value != 0) revert MsgValueShouldBeZero();
  //   //     // transfer payment tokens to this contract
  //   //     IERC20(_inputTokenAddresses[i]).safeTransferFrom(
  //   //       msg.sender,
  //   //       address(this),
  //   //       _maxSpendIncFees[i]
  //   //     );
  //   //     IERC20(_inputTokenAddresses[i]).approve(
  //   //       address(LibSweep.diamondStorage().troveMarketplace),
  //   //       _maxSpendIncFees[i]
  //   //     );
  //   //   }
  //   //   unchecked {
  //   //     ++i;
  //   //   }
  //   // }
  //   // uint256[] memory _maxSpendIncFeesAmount = _maxSpendWithoutFees(
  //   //   _maxSpendIncFees
  //   // );
  //   // (
  //   //   uint256[] memory totalSpentAmount,
  //   //   uint256 successCount,
  //   // ) = _sweepItemsMultiTokens(
  //   //     _buyOrders,
  //   //     _inputSettingsBitFlag,
  //   //     _inputTokenAddresses,
  //   //     _maxSpendIncFeesAmount,
  //   //     _minSpends,
  //   //     _maxSuccesses,
  //   //     _maxFailures
  //   //   );
  //   // // transfer back failed payment tokens to the buyer
  //   // if (successCount == 0) revert AllReverted();
  //   // for (uint256 i = 0; i < _maxSpendIncFees.length; ) {
  //   //   uint256 feeAmount = LibSweep._calculateFee(totalSpentAmount[i]);
  //   //   if (
  //   //     _inputTokenAddresses[i] == address(LibSweep.diamondStorage().weth) &&
  //   //     _buyOrders[0].usingEth
  //   //   ) {
  //   //     payable(msg.sender).transfer(
  //   //       _maxSpendIncFees[i] - (totalSpentAmount[i] + feeAmount)
  //   //     );
  //   //   } else {
  //   //     IERC20(_inputTokenAddresses[i]).safeTransfer(
  //   //       msg.sender,
  //   //       _maxSpendIncFees[i] - (totalSpentAmount[i] + feeAmount)
  //   //     );
  //   //   }
  //   //   unchecked {
  //   //     ++i;
  //   //   }
  //   // }
  // }

  // function _sweepItemsMultiTokens(
  //   BuyItemParams[] memory _buyOrders,
  //   uint16 _inputSettingsBitFlag,
  //   address[] memory _inputTokenAddresses,
  //   uint256[] memory _maxSpendIncFeesAmount,
  //   uint256[] memory _minSpends,
  //   uint32 _maxSuccesses,
  //   uint32 _maxFailures
  // )
  //   internal
  //   returns (
  //     uint256[] memory totalSpentAmounts,
  //     uint256 successCount,
  //     uint256 failCount
  //   )
  // {
  //   totalSpentAmounts = new uint256[](_inputTokenAddresses.length);

  //   for (uint256 i = 0; i < _buyOrders.length; ) {
  //     if (successCount >= _maxSuccesses || failCount >= _maxFailures) break;

  //     uint256 j = _getTokenIndex(
  //       _inputTokenAddresses,
  //       _buyOrders[i].paymentToken
  //     );

  //     if (totalSpentAmounts[j] >= _minSpends[j]) break;

  //     (uint256 spentAmount, bool spentSuccess, BuyError buyError) = tryBuyItem(
  //       _buyOrders[i],
  //       _inputSettingsBitFlag,
  //       _maxSpendIncFeesAmount[j] - totalSpentAmounts[j]
  //     );

  //     if (spentSuccess) {
  //       totalSpentAmounts[j] += spentAmount;
  //       successCount++;
  //     } else {
  //       if (
  //         buyError == BuyError.EXCEEDING_MAX_SPEND &&
  //         SettingsBitFlag.checkSetting(
  //           _inputSettingsBitFlag,
  //           SettingsBitFlag.EXCEEDING_MAX_SPEND
  //         )
  //       ) break;
  //       failCount++;
  //     }
  //     unchecked {
  //       ++i;
  //     }
  //   }
  // }
}
