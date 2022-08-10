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

// import "@forge-std/src/Test.sol";

contract SweepFacet is OwnershipModifers, ISmolSweeper, ABaseSweeperFacet {
  using SafeERC20 for IERC20;

  function buyItemsSingleToken(
    BuyOrder[] calldata _buyOrders,
    bool _usingETH,
    uint16 _inputSettingsBitFlag,
    address _paymentToken,
    uint256 _maxSpendIncFees
  ) external payable {
    if (_usingETH) {
      if (_maxSpendIncFees != msg.value) revert InvalidMsgValue();
    } else {
      if (msg.value != 0) revert MsgValueShouldBeZero();
      // transfer payment tokens to this contract

      IERC20(_paymentToken).safeTransferFrom(
        msg.sender,
        address(this),
        _maxSpendIncFees
      );
      // IERC20(_paymentToken).approve(
      //   address(LibSweep.diamondStorage().troveMarketplace),
      //   _maxSpendIncFees
      // );
    }
    (uint256 totalSpentAmount, uint256 successCount) = _buyItemsSingleToken(
      _buyOrders,
      _paymentToken,
      _usingETH,
      _inputSettingsBitFlag,
      LibSweep._calculateAmountWithoutFees(_maxSpendIncFees)
    );

    // transfer back failed payment tokens to the buyer
    if (successCount == 0) revert AllReverted();
    uint256 refundAmount = _maxSpendIncFees -
      (totalSpentAmount + LibSweep._calculateFee(totalSpentAmount));
    if (_usingETH) {
      payable(msg.sender).transfer(refundAmount);
      emit LibSweep.RefundedToken(address(0), refundAmount);
      // emit refunded event
    } else {
      IERC20(_paymentToken).safeTransfer(msg.sender, refundAmount);
      emit LibSweep.RefundedToken(address(_paymentToken), refundAmount);
    }
  }

  function _buyItemsSingleToken(
    BuyOrder[] memory _buyOrders,
    address _paymentToken,
    bool _usingETH,
    uint16 _inputSettingsBitFlag,
    uint256 _maxSpend
  ) internal returns (uint256 totalSpentAmount, uint256 successCount) {
    // buy all assets
    for (uint256 i = 0; i < _buyOrders.length; ++i) {
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
          (_maxSpend - totalSpentAmount) &&
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
        (uint256 spentAmount, bool success) = LibSweep._troveOrder(
          _buyOrders[i],
          quantityToBuy,
          _paymentToken,
          _usingETH,
          _inputSettingsBitFlag
        );

        if (success) {
          totalSpentAmount += spentAmount;
          successCount++;
        }
      } else if (_buyOrders[i].marketplaceId == LibSweep.STRATOS_ID) {
        // check if total price is less than max spend allowance left
        if (
          (_buyOrders[i].price * _buyOrders[i].quantity) >
          _maxSpend - totalSpentAmount &&
          SettingsBitFlag.checkSetting(
            _inputSettingsBitFlag,
            SettingsBitFlag.EXCEEDING_MAX_SPEND
          )
        ) break;

        (bool spentSuccess, bytes memory data) = LibSweep.tryBuyItemStratos(
          _buyOrders[i],
          _paymentToken,
          payable(msg.sender)
        );

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
          totalSpentAmount += _buyOrders[i].price * _buyOrders[i].quantity;
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

  function buyItemsMultiTokens(
    MultiTokenBuyOrder[] calldata _buyOrders,
    uint16 _inputSettingsBitFlag,
    address[] calldata _paymentTokens,
    uint256[] calldata _maxSpendIncFees
  ) external payable {
    // transfer payment tokens to this contract
    // uint256 i = 0;
    uint256 length = _paymentTokens.length;

    for (uint256 i = 0; i < length; ) {
      if (_buyOrders[i].usingETH) {
        if (_maxSpendIncFees[i] != msg.value) revert InvalidMsgValue();
      } else {
        // if (msg.value != 0) revert MsgValueShouldBeZero();
        // transfer payment tokens to this contract
        IERC20(_paymentTokens[i]).safeTransferFrom(
          msg.sender,
          address(this),
          _maxSpendIncFees[i]
        );
      }

      unchecked {
        ++i;
      }
    }

    (
      uint256[] memory totalSpentAmount,
      uint256 successCount
    ) = _buyItemsMultiTokens(
        _buyOrders,
        _inputSettingsBitFlag,
        _paymentTokens,
        LibSweep._maxSpendWithoutFees(_maxSpendIncFees)
      );

    // transfer back failed payment tokens to the buyer
    if (successCount == 0) revert AllReverted();

    for (uint256 i = 0; i < length; ) {
      uint256 refundAmount = _maxSpendIncFees[i] -
        (totalSpentAmount[i] + LibSweep._calculateFee(totalSpentAmount[i]));

      if (_buyOrders[i].usingETH) {
        payable(msg.sender).transfer(refundAmount);
        emit LibSweep.RefundedToken(address(0), refundAmount);
      } else {
        IERC20(_paymentTokens[i]).safeTransfer(msg.sender, refundAmount);
        emit LibSweep.RefundedToken(_paymentTokens[i], refundAmount);
      }

      unchecked {
        ++i;
      }
    }
  }

  function _buyItemsMultiTokens(
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
    for (uint256 i = 0; i < _buyOrders.length; ) {
      uint256 j = LibSweep._getTokenIndex(
        _paymentTokens,
        _buyOrders[i].paymentToken
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

      unchecked {
        ++i;
      }
    }
  }

  // struct SweepParams {
  //   uint256 minSpend;
  //   address paymentToken;
  //   uint32 maxSuccesses;
  //   uint32 maxFailures;
  //   uint16 inputSettingsBitFlag;
  //   bool usingETH;
  // }

  // function sweepItemsSingleToken(
  //   BuyOrder[] calldata _buyOrders,
  //   bytes[] calldata _signatures,
  //   SweepParams memory _sweepParams,
  //   uint256 _maxSpendIncFees
  // ) external payable {
  //   if (_sweepParams.usingETH) {
  //     if (_maxSpendIncFees != msg.value) revert InvalidMsgValue();
  //   } else {
  //     if (msg.value != 0) revert MsgValueShouldBeZero();
  //     // transfer payment tokens to this contract
  //     IERC20(_sweepParams.paymentToken).safeTransferFrom(
  //       msg.sender,
  //       address(this),
  //       _maxSpendIncFees
  //     );
  //     // IERC20(_inputTokenAddress).approve(
  //     //   address(LibSweep.diamondStorage().troveMarketplace),
  //     //   _maxSpendIncFees
  //     // );
  //   }
  //   (uint256 totalSpentAmount, uint32 successCount, ) = _sweepItemsSingleToken(
  //     _buyOrders,
  //     _signatures,
  //     _sweepParams,
  //     LibSweep._calculateAmountWithoutFees(_maxSpendIncFees)

  //     // SweepParams(
  //     //   LibSweep._calculateAmountWithoutFees(_sweepParams.maxSpendIncFees),
  //     //   _sweepParams.minSpend,
  //     //   _sweepParams.paymentToken,
  //     //   _sweepParams.maxSuccesses,
  //     //   _sweepParams.maxFailures,
  //     //   _sweepParams.inputSettingsBitFlag,
  //     //   _sweepParams.usingETH
  //     // )
  //   );
  //   // transfer back failed payment tokens to the buyer
  //   if (successCount == 0) revert AllReverted();
  //   uint256 refundAmount = _maxSpendIncFees -
  //     (totalSpentAmount + LibSweep._calculateFee(totalSpentAmount));
  //   if (_sweepParams.usingETH) {
  //     payable(msg.sender).transfer(refundAmount);
  //     emit LibSweep.RefundedToken(address(0), refundAmount);
  //   } else {
  //     IERC20(_sweepParams.paymentToken).safeTransfer(msg.sender, refundAmount);
  //     emit LibSweep.RefundedToken(
  //       address(_sweepParams.paymentToken),
  //       refundAmount
  //     );
  //   }
  // }

  // function _sweepItemsSingleToken(
  //   BuyOrder[] memory _buyOrders,
  //   bytes[] memory _signatures,
  //   SweepParams memory _sweepParams,
  //   uint256 _maxSpend
  // )
  //   internal
  //   returns (
  //     uint256 totalSpentAmount,
  //     uint32 successCount,
  //     uint32 failCount
  //   )
  // {
  //   // buy all assets
  //   for (uint256 i = 0; i < _buyOrders.length; ) {
  //     if (_buyOrders[i].marketplaceId == LibSweep.TROVE_ID) {
  //       // check if the listing exists
  //       ITroveMarketplace.ListingOrBid memory listing;
  //       {
  //         listing = ITroveMarketplace(
  //           LibSweep.diamondStorage().marketplaces[LibSweep.TROVE_ID]
  //         ).listings(
  //             _buyOrders[i].assetAddress,
  //             _buyOrders[i].tokenId,
  //             _buyOrders[i].seller
  //           );
  //       }

  //       // check if total price is less than max spend allowance left
  //       if (
  //         (listing.pricePerItem * _buyOrders[i].quantity) >
  //         (_maxSpend - totalSpentAmount) &&
  //         SettingsBitFlag.checkSetting(
  //           _sweepParams.inputSettingsBitFlag,
  //           SettingsBitFlag.EXCEEDING_MAX_SPEND
  //         )
  //       ) break;

  //       // not enough listed items
  //       if (
  //         listing.quantity < _buyOrders[i].quantity &&
  //         !SettingsBitFlag.checkSetting(
  //           _sweepParams.inputSettingsBitFlag,
  //           SettingsBitFlag.INSUFFICIENT_QUANTITY_ERC1155
  //         )
  //       ) continue; // skip item

  //       BuyItemParams[] memory buyItemParams = new BuyItemParams[](1);
  //       buyItemParams[0] = BuyItemParams(
  //         _buyOrders[i].assetAddress,
  //         _buyOrders[i].tokenId,
  //         _buyOrders[i].seller,
  //         uint64(listing.quantity),
  //         uint128(_buyOrders[i].price),
  //         _sweepParams.paymentToken,
  //         _sweepParams.usingETH
  //       );

  //       (bool spentSuccess, bytes memory data) = LibSweep.tryBuyItemTrove(
  //         buyItemParams
  //       );

  //       if (spentSuccess) {
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _sweepParams.inputSettingsBitFlag,
  //             SettingsBitFlag.EMIT_SUCCESS_EVENT_LOGS
  //           )
  //         ) {
  //           emit LibSweep.SuccessBuyItem(
  //             _buyOrders[0].assetAddress,
  //             _buyOrders[0].tokenId,
  //             payable(msg.sender),
  //             listing.quantity,
  //             listing.pricePerItem
  //           );
  //         }
  //         totalSpentAmount += _buyOrders[i].price * _buyOrders[i].quantity;
  //         successCount++;
  //       } else {
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _sweepParams.inputSettingsBitFlag,
  //             SettingsBitFlag.EMIT_FAILURE_EVENT_LOGS
  //           )
  //         ) {
  //           emit LibSweep.CaughtFailureBuyItem(
  //             _buyOrders[0].assetAddress,
  //             _buyOrders[0].tokenId,
  //             payable(msg.sender),
  //             listing.quantity,
  //             listing.pricePerItem,
  //             data
  //           );
  //         }
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _sweepParams.inputSettingsBitFlag,
  //             SettingsBitFlag.MARKETPLACE_BUY_ITEM_REVERTED
  //           )
  //         ) revert FirstBuyReverted(data);
  //       }
  //     } else if (_buyOrders[i].marketplaceId == LibSweep.STRATOS_ID) {
  //       // check if total price is less than max spend allowance left
  //       if (
  //         (_buyOrders[i].price * _buyOrders[i].quantity) >
  //         _maxSpend - totalSpentAmount &&
  //         SettingsBitFlag.checkSetting(
  //           _sweepParams.inputSettingsBitFlag,
  //           SettingsBitFlag.EXCEEDING_MAX_SPEND
  //         )
  //       ) break;

  //       (bool spentSuccess, bytes memory data) = LibSweep.tryBuyItemStratos(
  //         _buyOrders[i],
  //         _sweepParams.paymentToken,
  //         _signatures[i],
  //         payable(msg.sender)
  //       );

  //       if (spentSuccess) {
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _sweepParams.inputSettingsBitFlag,
  //             SettingsBitFlag.EMIT_SUCCESS_EVENT_LOGS
  //           )
  //         ) {
  //           emit LibSweep.SuccessBuyItem(
  //             _buyOrders[0].assetAddress,
  //             _buyOrders[0].tokenId,
  //             payable(msg.sender),
  //             _buyOrders[0].quantity,
  //             _buyOrders[i].price
  //           );
  //         }
  //         totalSpentAmount += _buyOrders[i].price * _buyOrders[i].quantity;
  //         successCount++;

  //         if (
  //           IERC165(_buyOrders[i].assetAddress).supportsInterface(
  //             LibSweep.INTERFACE_ID_ERC721
  //           )
  //         ) {
  //           IERC721(_buyOrders[i].assetAddress).safeTransferFrom(
  //             address(this),
  //             msg.sender,
  //             _buyOrders[i].tokenId
  //           );
  //         } else if (
  //           IERC165(_buyOrders[i].assetAddress).supportsInterface(
  //             LibSweep.INTERFACE_ID_ERC1155
  //           )
  //         ) {
  //           IERC1155(_buyOrders[i].assetAddress).safeTransferFrom(
  //             address(this),
  //             msg.sender,
  //             _buyOrders[i].tokenId,
  //             _buyOrders[0].quantity,
  //             ""
  //           );
  //         } else revert InvalidNFTAddress();
  //       } else {
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _sweepParams.inputSettingsBitFlag,
  //             SettingsBitFlag.EMIT_FAILURE_EVENT_LOGS
  //           )
  //         ) {
  //           emit LibSweep.CaughtFailureBuyItem(
  //             _buyOrders[0].assetAddress,
  //             _buyOrders[0].tokenId,
  //             payable(msg.sender),
  //             _buyOrders[0].quantity,
  //             _buyOrders[i].price,
  //             data
  //           );
  //         }
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _sweepParams.inputSettingsBitFlag,
  //             SettingsBitFlag.MARKETPLACE_BUY_ITEM_REVERTED
  //           )
  //         ) revert FirstBuyReverted(data);
  //         failCount++;
  //       }
  //     } else revert InvalidMarketplaceId();

  //     if (
  //       successCount >= _sweepParams.maxSuccesses ||
  //       failCount >= _sweepParams.maxFailures
  //     ) break;
  //     if (totalSpentAmount >= _sweepParams.minSpend) break;

  //     unchecked {
  //       ++i;
  //     }
  //   }
  // }

  // struct SweepParamsMulti {
  //   uint256[] minSpends;
  //   address[] paymentTokens;
  //   uint32 maxSuccesses;
  //   uint32 maxFailures;
  //   uint16 inputSettingsBitFlag;
  //   bool[] usingETH;
  // }

  // function sweepItemsMultiTokens(
  //   MultiTokenBuyOrder[] calldata _buyOrders,
  //   bytes[] calldata _signatures,
  //   uint256[] calldata _maxSpendIncFees,
  //   SweepParamsMulti calldata _sweepParams
  // )
  //   external
  //   payable
  //   returns (uint256[] memory totalSpentAmount, uint32 successCount)
  // {
  //   // // transfer payment tokens to this contract
  //   for (uint256 i = 0; i < _maxSpendIncFees.length; ) {
  //     if (_buyOrders[i].usingETH) {
  //       if (_maxSpendIncFees[i] != msg.value) revert InvalidMsgValue();
  //     } else {
  //       // if (msg.value != 0) revert MsgValueShouldBeZero();
  //       // transfer payment tokens to this contract
  //       IERC20(_sweepParams.paymentTokens[i]).safeTransferFrom(
  //         msg.sender,
  //         address(this),
  //         _maxSpendIncFees[i]
  //       );
  //       // IERC20(_inputTokenAddresses[i]).approve(
  //       //   address(LibSweep.diamondStorage().troveMarketplace),
  //       //   _maxSpendIncFees[i]
  //       // );
  //     }
  //     unchecked {
  //       ++i;
  //     }
  //   }
  //   (totalSpentAmount, successCount, ) = _sweepItemsMultiTokens(
  //     _buyOrders,
  //     _signatures,
  //     _sweepParams,
  //     _maxSpendWithoutFees(_maxSpendIncFees)
  //   );
  //   // transfer back failed payment tokens to the buyer
  //   if (successCount == 0) revert AllReverted();
  //   for (uint256 i = 0; i < _maxSpendIncFees.length; ) {
  //     uint256 refundAmount = _maxSpendIncFees[i] -
  //       (totalSpentAmount[i] + LibSweep._calculateFee(totalSpentAmount[i]));
  //     if (_buyOrders[0].usingETH) {
  //       payable(msg.sender).transfer(refundAmount);
  //       emit LibSweep.RefundedToken(address(0), refundAmount);
  //     } else {
  //       IERC20(_sweepParams.paymentTokens[i]).safeTransfer(
  //         msg.sender,
  //         refundAmount
  //       );
  //       emit LibSweep.RefundedToken(
  //         _sweepParams.paymentTokens[i],
  //         refundAmount
  //       );
  //     }
  //     unchecked {
  //       ++i;
  //     }
  //   }
  // }

  // function _sweepItemsMultiTokens(
  //   MultiTokenBuyOrder[] memory _buyOrders,
  //   bytes[] memory _signatures,
  //   SweepParamsMulti calldata _sweepParams,
  //   uint256[] memory _maxSpends
  // )
  //   internal
  //   returns (
  //     uint256[] memory totalSpentAmounts,
  //     uint32 successCount,
  //     uint32 failCount
  //   )
  // {
  //   totalSpentAmounts = new uint256[](_sweepParams.paymentTokens.length);
  //   for (uint256 i = 0; i < _buyOrders.length; ) {
  //     uint256 j = _getTokenIndex(
  //       _sweepParams.paymentTokens,
  //       _buyOrders[i].paymentToken
  //     );

  //     bool spentSuccess;
  //     bytes memory data;

  //     if (_buyOrders[i].marketplaceId == LibSweep.TROVE_ID) {
  //       // check if the listing exists
  //       ITroveMarketplace.ListingOrBid memory listing = ITroveMarketplace(
  //         LibSweep.diamondStorage().marketplaces[LibSweep.TROVE_ID]
  //       ).listings(
  //           _buyOrders[i].assetAddress,
  //           _buyOrders[i].tokenId,
  //           _buyOrders[i].seller
  //         );

  //       // check if total price is less than max spend allowance left
  //       if (
  //         (listing.pricePerItem * _buyOrders[i].quantity) >
  //         (_maxSpends[j] - totalSpentAmounts[j]) &&
  //         SettingsBitFlag.checkSetting(
  //           _sweepParams.inputSettingsBitFlag,
  //           SettingsBitFlag.EXCEEDING_MAX_SPEND
  //         )
  //       ) break;

  //       // not enough listed items
  //       if (
  //         listing.quantity < _buyOrders[i].quantity &&
  //         !SettingsBitFlag.checkSetting(
  //           _sweepParams.inputSettingsBitFlag,
  //           SettingsBitFlag.INSUFFICIENT_QUANTITY_ERC1155
  //         )
  //       ) {
  //         continue; // skip item
  //       }
  //       BuyItemParams[] memory buyItemParams = new BuyItemParams[](1);
  //       buyItemParams[0] = BuyItemParams(
  //         _buyOrders[i].assetAddress,
  //         _buyOrders[i].tokenId,
  //         _buyOrders[i].seller,
  //         uint64(listing.quantity),
  //         uint128(_buyOrders[i].price),
  //         _sweepParams.paymentTokens[j],
  //         _buyOrders[i].usingETH
  //       );

  //       (spentSuccess, data) = LibSweep.tryBuyItemTrove(buyItemParams);

  //       if (spentSuccess) {
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _sweepParams.inputSettingsBitFlag,
  //             SettingsBitFlag.EMIT_SUCCESS_EVENT_LOGS
  //           )
  //         ) {
  //           emit LibSweep.SuccessBuyItem(
  //             _buyOrders[0].assetAddress,
  //             _buyOrders[0].tokenId,
  //             payable(msg.sender),
  //             listing.quantity,
  //             listing.pricePerItem
  //           );
  //         }
  //         totalSpentAmounts[j] += _buyOrders[i].price * _buyOrders[i].quantity;
  //         successCount++;
  //       } else {
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _sweepParams.inputSettingsBitFlag,
  //             SettingsBitFlag.EMIT_FAILURE_EVENT_LOGS
  //           )
  //         ) {
  //           emit LibSweep.CaughtFailureBuyItem(
  //             _buyOrders[0].assetAddress,
  //             _buyOrders[0].tokenId,
  //             payable(msg.sender),
  //             listing.quantity,
  //             listing.pricePerItem,
  //             data
  //           );
  //         }
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _sweepParams.inputSettingsBitFlag,
  //             SettingsBitFlag.MARKETPLACE_BUY_ITEM_REVERTED
  //           )
  //         ) revert FirstBuyReverted(data);
  //       }
  //     } else if (_buyOrders[i].marketplaceId == LibSweep.STRATOS_ID) {
  //       // check if total price is less than max spend allowance left
  //       if (
  //         (_buyOrders[i].price * _buyOrders[i].quantity) >
  //         _maxSpends[j] - totalSpentAmounts[j] &&
  //         SettingsBitFlag.checkSetting(
  //           _sweepParams.inputSettingsBitFlag,
  //           SettingsBitFlag.EXCEEDING_MAX_SPEND
  //         )
  //       ) break;

  //       (spentSuccess, data) = LibSweep.tryBuyItemStratosMulti(
  //         _buyOrders[i],
  //         _signatures[i],
  //         payable(msg.sender)
  //       );

  //       if (spentSuccess) {
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _sweepParams.inputSettingsBitFlag,
  //             SettingsBitFlag.EMIT_SUCCESS_EVENT_LOGS
  //           )
  //         ) {
  //           emit LibSweep.SuccessBuyItem(
  //             _buyOrders[0].assetAddress,
  //             _buyOrders[0].tokenId,
  //             payable(msg.sender),
  //             _buyOrders[0].quantity,
  //             _buyOrders[i].price
  //           );
  //         }
  //         totalSpentAmounts[j] += _buyOrders[i].price * _buyOrders[i].quantity;
  //         successCount++;

  //         if (
  //           IERC165(_buyOrders[i].assetAddress).supportsInterface(
  //             LibSweep.INTERFACE_ID_ERC721
  //           )
  //         ) {
  //           IERC721(_buyOrders[i].assetAddress).safeTransferFrom(
  //             address(this),
  //             msg.sender,
  //             _buyOrders[i].tokenId
  //           );
  //         } else if (
  //           IERC165(_buyOrders[i].assetAddress).supportsInterface(
  //             LibSweep.INTERFACE_ID_ERC1155
  //           )
  //         ) {
  //           IERC1155(_buyOrders[i].assetAddress).safeTransferFrom(
  //             address(this),
  //             msg.sender,
  //             _buyOrders[i].tokenId,
  //             _buyOrders[0].quantity,
  //             ""
  //           );
  //         } else revert InvalidNFTAddress();
  //       } else {
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _sweepParams.inputSettingsBitFlag,
  //             SettingsBitFlag.EMIT_FAILURE_EVENT_LOGS
  //           )
  //         ) {
  //           emit LibSweep.CaughtFailureBuyItem(
  //             _buyOrders[0].assetAddress,
  //             _buyOrders[0].tokenId,
  //             payable(msg.sender),
  //             _buyOrders[0].quantity,
  //             _buyOrders[i].price,
  //             data
  //           );
  //         }
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _sweepParams.inputSettingsBitFlag,
  //             SettingsBitFlag.MARKETPLACE_BUY_ITEM_REVERTED
  //           )
  //         ) revert FirstBuyReverted(data);
  //         failCount++;
  //       }
  //     } else revert InvalidMarketplaceId();

  //     if (
  //       successCount >= _sweepParams.maxSuccesses ||
  //       failCount >= _sweepParams.maxFailures
  //     ) break;
  //     if (totalSpentAmounts[j] >= _sweepParams.minSpends[j]) break;

  //     unchecked {
  //       ++i;
  //     }
  //   }
  // }
}
