// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../../treasure/interfaces/ITroveMarketplace.sol";

import {LibDiamond} from "./LibDiamond.sol";

import "../../errors/BuyError.sol";
import "../../../token/ANFTReceiver.sol";
import "../../libraries/SettingsBitFlag.sol";
import "../../libraries/Math.sol";
import "../../../treasure/interfaces/ITroveMarketplace.sol";
import "../../../stratos/ExchangeV5.sol";

import "../../structs/BuyOrder.sol";

error InvalidNFTAddress();
error FirstBuyReverted(bytes message);
error AllReverted();

error InvalidMsgValue();
error MsgValueShouldBeZero();
error PaymentTokenNotGiven(address _paymentToken);

error InvalidMarketplaceId();

library LibSweep {
  using SafeERC20 for IERC20;

  event SuccessBuyItem(
    address indexed _nftAddress,
    uint256 _tokenId,
    address indexed _seller,
    address indexed _buyer,
    uint256 _quantity,
    uint256 _price
  );

  event CaughtFailureBuyItem(
    address indexed _nftAddress,
    uint256 _tokenId,
    address indexed _seller,
    address indexed _buyer,
    uint256 _quantity,
    uint256 _price,
    bytes _errorReason
  );
  event refundToken(address tokenAddress, uint256 amount);

  bytes32 constant DIAMOND_STORAGE_POSITION =
    keccak256("diamond.standard.sweep.storage");

  struct SweepStorage {
    // owner of the contract
    uint256 sweepFee;
    IERC20 defaultPaymentToken;
    IERC20 weth;
    ITroveMarketplace troveMarketplace;
    ExchangeV5 stratosMarketplace;
  }

  uint256 constant FEE_BASIS_POINTS = 1_000_000;

  bytes4 internal constant INTERFACE_ID_ERC721 = 0x80ac58cd;
  bytes4 internal constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

  uint8 internal constant TROVE_ID = 1;
  uint8 internal constant STRATOS_ID = 2;

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
    BuyItemParams memory _buyOrder,
    uint16 _inputSettingsBitFlag,
    uint256 _maxSpendAllowanceLeft
  )
    internal
    returns (
      uint256 totalPrice,
      bool success,
      BuyError buyError
    )
  {
    uint256 quantityToBuy = _buyOrder.quantity;
    // ITroveMarketplace marketplace = LibSweep.diamondStorage().troveMarketplace;
    // check if the listing exists
    ITroveMarketplace.ListingOrBid memory listing = LibSweep
      .diamondStorage()
      .troveMarketplace
      .listings(_buyOrder.nftAddress, _buyOrder.tokenId, _buyOrder.owner);

    // // check if the price is correct
    // if (listing.pricePerItem > _buyOrder.maxPricePerItem) {
    //     // skip this item
    //     return (0, false, SettingsBitFlag.MAX_PRICE_PER_ITEM_EXCEEDED);
    // }

    // not enough listed items
    if (listing.quantity < quantityToBuy) {
      if (
        SettingsBitFlag.checkSetting(
          _inputSettingsBitFlag,
          SettingsBitFlag.INSUFFICIENT_QUANTITY_ERC1155
        )
      ) {
        // else buy all listed items even if it's less than requested
        quantityToBuy = listing.quantity;
      } else {
        // skip this item
        return (0, false, BuyError.INSUFFICIENT_QUANTITY_ERC1155);
      }
    }

    // check if total price is less than max spend allowance left
    if ((listing.pricePerItem * quantityToBuy) > _maxSpendAllowanceLeft) {
      return (0, false, BuyError.EXCEEDING_MAX_SPEND);
    }

    BuyItemParams[] memory buyItemParams = new BuyItemParams[](1);
    buyItemParams[0] = _buyOrder;

    uint256 totalSpent = 0;
    uint256 value = (_buyOrder.paymentToken ==
      address(LibSweep.diamondStorage().weth))
      ? (_buyOrder.maxPricePerItem * quantityToBuy)
      : 0;

    try
      LibSweep.diamondStorage().troveMarketplace.buyItems{value: value}(
        buyItemParams
      )
    {
      if (
        SettingsBitFlag.checkSetting(
          _inputSettingsBitFlag,
          SettingsBitFlag.EMIT_SUCCESS_EVENT_LOGS
        )
      ) {
        emit SuccessBuyItem(
          _buyOrder.nftAddress,
          _buyOrder.tokenId,
          _buyOrder.owner,
          msg.sender,
          quantityToBuy,
          listing.pricePerItem
        );
      }

      if (
        IERC165(_buyOrder.nftAddress).supportsInterface(
          LibSweep.INTERFACE_ID_ERC721
        )
      ) {
        IERC721(_buyOrder.nftAddress).safeTransferFrom(
          address(this),
          msg.sender,
          _buyOrder.tokenId
        );
      } else if (
        IERC165(_buyOrder.nftAddress).supportsInterface(
          LibSweep.INTERFACE_ID_ERC1155
        )
      ) {
        IERC1155(_buyOrder.nftAddress).safeTransferFrom(
          address(this),
          msg.sender,
          _buyOrder.tokenId,
          quantityToBuy,
          ""
        );
      } else revert InvalidNFTAddress();

      totalSpent = listing.pricePerItem * quantityToBuy;
    } catch (bytes memory errorReason) {
      if (
        SettingsBitFlag.checkSetting(
          _inputSettingsBitFlag,
          SettingsBitFlag.EMIT_FAILURE_EVENT_LOGS
        )
      ) {
        emit CaughtFailureBuyItem(
          _buyOrder.nftAddress,
          _buyOrder.tokenId,
          _buyOrder.owner,
          msg.sender,
          quantityToBuy,
          listing.pricePerItem,
          errorReason
        );
      }

      if (
        SettingsBitFlag.checkSetting(
          _inputSettingsBitFlag,
          SettingsBitFlag.MARKETPLACE_BUY_ITEM_REVERTED
        )
      ) revert FirstBuyReverted(errorReason);
      // skip this item
      return (0, false, BuyError.BUY_ITEM_REVERTED);
    }

    return (totalSpent, true, BuyError.NONE);
  }

  function helper(
    BuyOrder memory _buyOrder,
    address paymentERC20,
    bytes memory signature,
    address payable buyer
  ) internal returns (bool success, bytes memory data) {
    return
      address(LibSweep.diamondStorage().stratosMarketplace).call{
        value: (paymentERC20 == address(0))
          ? (_buyOrder.price * _buyOrder.quantity)
          : 0,
        gas: gasleft()
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
          paymentERC20,
          signature,
          buyer
        )

        // abi.encodeWithSignature(
        //   "fillSellOrder(address payable seller,address contractAddress,uint256 tokenId,uint256 startTime,uint256 expiration,uint256 price,uint256 quantity,uint256 createdAtBlockNumber,address paymentERC20,bytes memory signature,address payable buyer)",
        //   _buyOrder.seller,
        //   _buyOrder.assetAddress,
        //   _buyOrder.tokenId,
        //   _buyOrder.startTime,
        //   _buyOrder.expiration,
        //   _buyOrder.price,
        //   _buyOrder.quantity,
        //   _buyOrder.createdAtBlockNumber,
        //   paymentERC20,
        //   signature,
        //   buyer
        // )
      );
  }

  function tryBuyItemStratos(
    BuyOrder memory _buyOrder,
    address paymentERC20,
    bytes memory signature,
    address payable buyer,
    uint16 _inputSettingsBitFlag,
    uint256 _maxSpendAllowanceLeft
  )
    internal
    returns (
      uint256 totalSpent,
      bool success,
      BuyError buyError
    )
  {
    // check if total price is less than max spend allowance left
    {
      if ((_buyOrder.price * _buyOrder.quantity) > _maxSpendAllowanceLeft)
        return (0, false, BuyError.EXCEEDING_MAX_SPEND);
    }

    helper(_buyOrder, paymentERC20, signature, buyer);

    // (bool success, bytes memory data) = address(
    //   LibSweep.diamondStorage().stratosMarketplace
    // ).call{
    //   value: (paymentERC20 == address(0))
    //     ? (_buyOrder.price * _buyOrder.quantity)
    //     : 0,
    //   gas: gasleft()
    // }(
    //   abi.encodeWithSignature(
    //     "fillSellOrder(address payable seller,address contractAddress,uint256 tokenId,uint256 startTime,uint256 expiration,uint256 price,uint256 quantity,uint256 createdAtBlockNumber,address paymentERC20,bytes memory signature,address payable buyer)",
    //     _buyOrder.seller,
    //     _buyOrder.assetAddress,
    //     _buyOrder.tokenId,
    //     _buyOrder.startTime,
    //     _buyOrder.expiration,
    //     _buyOrder.price,
    //     _buyOrder.quantity,
    //     _buyOrder.createdAtBlockNumber,
    //     paymentERC20,
    //     signature,
    //     buyer
    //   )
    // );

    // try
    //   LibSweep.diamondStorage().stratosMarketplace.fillSellOrder{
    //     value: (paymentERC20 == address(0))
    //       ? (_buyOrder.price * _buyOrder.quantity)
    //       : 0
    //   }(
    //     _buyOrder.seller,
    //     _buyOrder.assetAddress,
    //     _buyOrder.tokenId,
    //     _buyOrder.startTime,
    //     _buyOrder.expiration,
    //     _buyOrder.price,
    //     _buyOrder.quantity,
    //     _buyOrder.createdAtBlockNumber,
    //     paymentERC20,
    //     signature,
    //     buyer
    //   )
    // {
    //   if (
    //     SettingsBitFlag.checkSetting(
    //       _inputSettingsBitFlag,
    //       SettingsBitFlag.EMIT_SUCCESS_EVENT_LOGS
    //     )
    //   ) {
    //     emit SuccessBuyItem(
    //       _buyOrder.assetAddress,
    //       _buyOrder.tokenId,
    //       _buyOrder.seller,
    //       buyer,
    //       _buyOrder.quantity,
    //       _buyOrder.price
    //     );
    //   }

    //   totalSpent = _buyOrder.price * _buyOrder.quantity;
    // } catch (bytes memory errorReason) {
    //   if (
    //     SettingsBitFlag.checkSetting(
    //       _inputSettingsBitFlag,
    //       SettingsBitFlag.EMIT_FAILURE_EVENT_LOGS
    //     )
    //   ) {
    //     emit CaughtFailureBuyItem(
    //       _buyOrder.assetAddress,
    //       _buyOrder.tokenId,
    //       _buyOrder.seller,
    //       buyer,
    //       _buyOrder.quantity,
    //       _buyOrder.price,
    //       errorReason
    //     );
    //   }

    //   if (
    //     SettingsBitFlag.checkSetting(
    //       _inputSettingsBitFlag,
    //       SettingsBitFlag.MARKETPLACE_BUY_ITEM_REVERTED
    //     )
    //   ) revert FirstBuyReverted(errorReason);
    //   // skip this item
    //   return (0, false, BuyError.BUY_ITEM_REVERTED);
    // }

    return (totalSpent, true, BuyError.NONE);
  }
}
