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

// import "@forge-std/src/Console2.sol";

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
    // IERC20 weth;
    uint256 sweepFee;
    IERC721 sweepNFT;
    // IERC20 defaultPaymentToken;

    address[] marketplaces;
    address[] paymentTokens;
    // ITroveMarketplace troveMarketplace;
    // ExchangeV5 stratosMarketplace;
  }

  uint256 constant FEE_BASIS_POINTS = 1_000_000;

  bytes4 internal constant INTERFACE_ID_ERC721 = 0x80ac58cd;
  bytes4 internal constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

  uint16 internal constant TROVE_ID = 0;
  uint16 internal constant STRATOS_ID = 1;

  function _addMarketplace(address _marketplace, address _paymentToken)
    internal
  {
    require(_marketplace != address(0));
    diamondStorage().marketplaces.push(_marketplace);
    diamondStorage().paymentTokens.push(_paymentToken);

    if (_paymentToken != address(0)) {
      IERC20(_paymentToken).approve(_marketplace, type(uint256).max);
    }
  }

  function _setMarketplace(
    uint256 _marketplaceId,
    address _marketplace,
    address _paymentToken
  ) internal {
    diamondStorage().marketplaces[_marketplaceId] = _marketplace;
    diamondStorage().paymentTokens[_marketplaceId] = _paymentToken;
  }

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

  function tryBuyItemTrove(BuyItemParams[] memory _buyOrders)
    internal
    returns (bool success, bytes memory data)
  {
    address marketplace = LibSweep.diamondStorage().marketplaces[TROVE_ID];
    (success, data) = marketplace.call{
      value: (_buyOrders[0].paymentToken ==
        ITroveMarketplace(marketplace).weth())
        ? (_buyOrders[0].maxPricePerItem * _buyOrders[0].quantity)
        : 0
    }(abi.encodeWithSelector(ITroveMarketplace.buyItems.selector, _buyOrders));
  }

  function tryBuyItemStratos(
    BuyOrder memory _buyOrder,
    address paymentERC20,
    address buyer
  ) internal returns (bool success, bytes memory data) {
    bytes memory encoded = abi.encodeWithSelector(
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
      _buyOrder.signature,
      buyer
    );
    (success, data) = LibSweep.diamondStorage().marketplaces[STRATOS_ID].call{
      value: (paymentERC20 == address(0))
        ? (_buyOrder.price * _buyOrder.quantity)
        : 0
    }(encoded);
  }

  function tryBuyItemStratosMulti(
    MultiTokenBuyOrder memory _buyOrder,
    address payable buyer
  ) internal returns (bool success, bytes memory data) {
    (success, data) = LibSweep.diamondStorage().marketplaces[STRATOS_ID].call{
      value: (_buyOrder.paymentToken == address(0))
        ? (_buyOrder.price * _buyOrder.quantity)
        : 0
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
        buyer
      )
    );
  }

  function _maxSpendWithoutFees(uint256[] memory _maxSpendIncFees)
    internal
    view
    returns (uint256[] memory maxSpendIncFeesAmount)
  {
    maxSpendIncFeesAmount = new uint256[](_maxSpendIncFees.length);

    uint256 maxSpendLength = _maxSpendIncFees.length;
    for (uint256 i = 0; i < maxSpendLength; ) {
      maxSpendIncFeesAmount[i] = LibSweep._calculateAmountWithoutFees(
        _maxSpendIncFees[i]
      );
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
      uint64(_quantityToBuy),
      uint128(_buyOrder.price),
      _paymentToken,
      _usingETH
    );

    address marketplace = LibSweep.diamondStorage().marketplaces[
      LibSweep.TROVE_ID
    ];
    (bool spentSuccess, bytes memory data) = marketplace.call{
      value: (_paymentToken == ITroveMarketplace(marketplace).weth())
        ? (uint128(_buyOrder.price) * _quantityToBuy)
        : 0
    }(
      abi.encodeWithSelector(ITroveMarketplace.buyItems.selector, buyItemParams)
    );

    // (bool spentSuccess, bytes memory data) = LibSweep.tryBuyItemTrove(
    //   buyItemParams
    // );

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
}
