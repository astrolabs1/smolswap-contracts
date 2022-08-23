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

import "@contracts/sweep/structs/Swap.sol";

// import "@forge-std/src/console.sol";

error InvalidNFTAddress();
error FirstBuyReverted(bytes message);
error AllReverted();

error InvalidMsgValue();
error MsgValueShouldBeZero();
error PaymentTokenNotGiven(address _paymentToken);

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

  function tryBuyItemTrove(
    address _troveMarketplace,
    BuyItemParams[] memory _buyOrders
  ) internal returns (bool success, bytes memory data) {
    (success, data) = _troveMarketplace.call{
      value: (_buyOrders[0].usingEth)
        ? (_buyOrders[0].maxPricePerItem * _buyOrders[0].quantity)
        : 0
    }(abi.encodeWithSelector(ITroveMarketplace.buyItems.selector, _buyOrders));
  }

  // function tryBuyItemStratos(
  //   BuyOrder memory _buyOrder,
  //   address _paymentERC20,
  //   address _buyer,
  //   bool _usingETH
  // ) internal returns (bool success, bytes memory data) {
  //   bytes memory encoded = abi.encodeWithSelector(
  //     ExchangeV5.fillSellOrder.selector,
  //     _buyOrder.seller,
  //     _buyOrder.assetAddress,
  //     _buyOrder.tokenId,
  //     _buyOrder.startTime,
  //     _buyOrder.expiration,
  //     _buyOrder.price,
  //     _buyOrder.quantity,
  //     _buyOrder.createdAtBlockNumber,
  //     _paymentERC20,
  //     _buyOrder.signature,
  //     _buyer
  //   );
  //   (success, data) = (_buyOrder.marketplaceAddress).call{
  //     value: (_usingETH) ? (_buyOrder.price * _buyOrder.quantity) : 0
  //   }(encoded);
  // }

  function tryBuyItemStratosMulti(
    MultiTokenBuyOrder memory _buyOrder,
    address payable _buyer
  ) internal returns (bool success, bytes memory data) {
    (success, data) = _buyOrder.marketplaceAddress.call{
      value: (_buyOrder.usingETH) ? (_buyOrder.price * _buyOrder.quantity) : 0
    }(
      abi.encodeWithSelector(
        ExchangeV5.fillSellOrder.selector,
        _buyOrder.seller,
        _buyOrder.assetAddress,
        _buyOrder.tokenId,
        _buyOrder.startTime,
        _buyOrder.expiration,
        _buyOrder.price,
        _buyOrder.quantity,
        _buyOrder.createdAtBlockNumber,
        _buyOrder.paymentToken,
        _buyOrder.signature,
        _buyer
      )
    );
  }

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

  function _getTokenIndex(
    address[] memory _paymentTokens,
    address _buyOrderPaymentToken
  ) internal pure returns (uint256 j) {
    uint256 paymentTokensLength = _paymentTokens.length;
    for (; j < paymentTokensLength; ) {
      if (_paymentTokens[j] == _buyOrderPaymentToken) {
        return j;
      }
      unchecked {
        ++j;
      }
    }
    revert PaymentTokenNotGiven(_buyOrderPaymentToken);
  }

  function _troveOrder(
    BuyOrder memory _buyOrder,
    uint64 _quantityToBuy,
    address _paymentToken,
    bool _usingETH,
    uint16 _inputSettingsBitFlag
  ) internal returns (uint256 spentAmount, bool success) {
    BuyItemParams[] memory buyItemParams = new BuyItemParams[](1);
    buyItemParams[0] = BuyItemParams(
      _buyOrder.assetAddress,
      _buyOrder.tokenId,
      _buyOrder.seller,
      _quantityToBuy,
      uint128(_buyOrder.price),
      _paymentToken,
      _usingETH
    );

    (bool spentSuccess, bytes memory data) = LibSweep.tryBuyItemTrove(
      _buyOrder.marketplaceAddress,
      buyItemParams
    );

    if (spentSuccess) {
      if (
        SettingsBitFlag.checkSetting(
          _inputSettingsBitFlag,
          SettingsBitFlag.EMIT_SUCCESS_EVENT_LOGS
        )
      ) {
        emit LibSweep.SuccessBuyItem(
          _buyOrder.assetAddress,
          _buyOrder.tokenId,
          payable(msg.sender),
          _quantityToBuy,
          _buyOrder.price
        );
      }

      if (
        IERC165(_buyOrder.assetAddress).supportsInterface(
          LibSweep.INTERFACE_ID_ERC721
        )
      ) {
        IERC721(_buyOrder.assetAddress).safeTransferFrom(
          address(this),
          msg.sender,
          _buyOrder.tokenId
        );
      } else if (
        IERC165(_buyOrder.assetAddress).supportsInterface(
          LibSweep.INTERFACE_ID_ERC1155
        )
      ) {
        IERC1155(_buyOrder.assetAddress).safeTransferFrom(
          address(this),
          msg.sender,
          _buyOrder.tokenId,
          _quantityToBuy,
          ""
        );
      } else revert InvalidNFTAddress();

      return (_buyOrder.price * _quantityToBuy, true);
    } else {
      if (
        SettingsBitFlag.checkSetting(
          _inputSettingsBitFlag,
          SettingsBitFlag.EMIT_FAILURE_EVENT_LOGS
        )
      ) {
        emit LibSweep.CaughtFailureBuyItem(
          _buyOrder.assetAddress,
          _buyOrder.tokenId,
          payable(msg.sender),
          _quantityToBuy,
          _buyOrder.price,
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
    return (0, false);
  }

  function _troveOrderMultiToken(
    MultiTokenBuyOrder memory _buyOrder,
    uint64 _quantityToBuy,
    uint16 _inputSettingsBitFlag
  ) internal returns (uint256 spentAmount, bool success) {
    BuyItemParams[] memory buyItemParams = new BuyItemParams[](1);
    buyItemParams[0] = BuyItemParams(
      _buyOrder.assetAddress,
      _buyOrder.tokenId,
      _buyOrder.seller,
      uint64(_quantityToBuy),
      uint128(_buyOrder.price),
      _buyOrder.paymentToken,
      _buyOrder.usingETH
    );

    (bool spentSuccess, bytes memory data) = LibSweep.tryBuyItemTrove(
      _buyOrder.marketplaceAddress,
      buyItemParams
    );

    if (spentSuccess) {
      if (
        SettingsBitFlag.checkSetting(
          _inputSettingsBitFlag,
          SettingsBitFlag.EMIT_SUCCESS_EVENT_LOGS
        )
      ) {
        emit LibSweep.SuccessBuyItem(
          _buyOrder.assetAddress,
          _buyOrder.tokenId,
          payable(msg.sender),
          _quantityToBuy,
          _buyOrder.price
        );
      }

      if (
        IERC165(_buyOrder.assetAddress).supportsInterface(
          LibSweep.INTERFACE_ID_ERC721
        )
      ) {
        IERC721(_buyOrder.assetAddress).safeTransferFrom(
          address(this),
          msg.sender,
          _buyOrder.tokenId
        );
      } else if (
        IERC165(_buyOrder.assetAddress).supportsInterface(
          LibSweep.INTERFACE_ID_ERC1155
        )
      ) {
        IERC1155(_buyOrder.assetAddress).safeTransferFrom(
          address(this),
          msg.sender,
          _buyOrder.tokenId,
          _quantityToBuy,
          ""
        );
      } else revert InvalidNFTAddress();

      return (_buyOrder.price * _quantityToBuy, true);
    } else {
      if (
        SettingsBitFlag.checkSetting(
          _inputSettingsBitFlag,
          SettingsBitFlag.EMIT_FAILURE_EVENT_LOGS
        )
      ) {
        emit LibSweep.CaughtFailureBuyItem(
          _buyOrder.assetAddress,
          _buyOrder.tokenId,
          payable(msg.sender),
          _quantityToBuy,
          _buyOrder.price,
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
    return (0, false);
  }

  // function _buyItemsSingleToken(
  //   BuyOrder[] memory _buyOrders,
  //   address _paymentToken,
  //   bool _usingETH,
  //   uint16 _inputSettingsBitFlag,
  //   uint256 _maxSpend
  // ) internal returns (uint256 totalSpentAmount, uint256 successCount) {
  //   // buy all assets
  //   for (uint256 i = 0; i < _buyOrders.length; ++i) {
  //     if (_buyOrders[i].marketplaceTypeId == LibMarketplaces.TROVE_ID) {
  //       // check if the listing exists
  //       uint64 quantityToBuy;

  //       ITroveMarketplace.ListingOrBid memory listing = ITroveMarketplace(
  //         _buyOrders[i].marketplaceAddress
  //       ).listings(
  //           _buyOrders[i].assetAddress,
  //           _buyOrders[i].tokenId,
  //           _buyOrders[i].seller
  //         );

  //       // check if total price is less than max spend allowance left
  //       if (
  //         (listing.pricePerItem * _buyOrders[i].quantity) >
  //         (_maxSpend - totalSpentAmount) &&
  //         SettingsBitFlag.checkSetting(
  //           _inputSettingsBitFlag,
  //           SettingsBitFlag.EXCEEDING_MAX_SPEND
  //         )
  //       ) break;

  //       // not enough listed items
  //       if (listing.quantity < _buyOrders[i].quantity) {
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _inputSettingsBitFlag,
  //             SettingsBitFlag.INSUFFICIENT_QUANTITY_ERC1155
  //           )
  //         ) {
  //           quantityToBuy = listing.quantity;
  //         } else {
  //           continue; // skip item
  //         }
  //       } else {
  //         quantityToBuy = uint64(_buyOrders[i].quantity);
  //       }

  //       // buy item
  //       (uint256 spentAmount, bool success) = LibSweep._troveOrder(
  //         _buyOrders[i],
  //         quantityToBuy,
  //         _paymentToken,
  //         _usingETH,
  //         _inputSettingsBitFlag
  //       );

  //       if (success) {
  //         totalSpentAmount += spentAmount;
  //         successCount++;
  //       }
  //     } else if (
  //       _buyOrders[i].marketplaceTypeId == LibMarketplaces.STRATOS_ID
  //     ) {
  //       // check if total price is less than max spend allowance left
  //       if (
  //         (_buyOrders[i].price * _buyOrders[i].quantity) >
  //         _maxSpend - totalSpentAmount &&
  //         SettingsBitFlag.checkSetting(
  //           _inputSettingsBitFlag,
  //           SettingsBitFlag.EXCEEDING_MAX_SPEND
  //         )
  //       ) break;

  //       (bool spentSuccess, bytes memory data) = LibSweep
  //         .tryBuyItemStratosMulti(MultiTokenBuyOrder(
  //           _buyOrders[i].marketplaceAddress,
  //           _buyOrders[i].assetAddress,
  //         ), payable(msg.sender));
  //       // (bool spentSuccess, bytes memory data) = LibSweep.tryBuyItemStratos(
  //       //   _buyOrders[i],
  //       //   _paymentToken,
  //       //   payable(msg.sender),
  //       //   _usingETH
  //       // );

  //       if (spentSuccess) {
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _inputSettingsBitFlag,
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
  //       } else {
  //         if (
  //           SettingsBitFlag.checkSetting(
  //             _inputSettingsBitFlag,
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
  //             _inputSettingsBitFlag,
  //             SettingsBitFlag.MARKETPLACE_BUY_ITEM_REVERTED
  //           )
  //         ) revert FirstBuyReverted(data);
  //       }
  //     } else revert InvalidMarketplaceId();
  //   }
  // }

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
    for (uint256 i = 0; i < _buyOrders.length; ++i) {
      uint256 j = LibSweep._getTokenIndex(
        _paymentTokens,
        (_buyOrders[i].usingETH) ? address(0) : _buyOrders[i].paymentToken
      );

      if (_buyOrders[i].marketplaceType == MarketplaceType.TROVE) {
        // check if the listing exists
        uint64 quantityToBuy;

        ITroveMarketplace.ListingOrBid memory listing = ITroveMarketplace(
          _buyOrders[i].marketplaceAddress
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
      } else if (_buyOrders[i].marketplaceType == MarketplaceType.SEAPORT_V1) {
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
