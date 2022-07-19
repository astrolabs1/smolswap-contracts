pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {LibSweep, PaymentTokenNotGiven} from "../../libraries/LibSweep.sol";
import "../OwnershipFacet.sol";

import "../../../../token/ANFTReceiver.sol";
import "../../../libraries/SettingsBitFlag.sol";
import "../../../libraries/Math.sol";
import "../../../../treasure/interfaces/ITroveMarketplace.sol";
import "../../../interfaces/ISmolSweeper.sol";
import "../../../errors/BuyError.sol";

contract ABaseSweeperFacet is OwnershipModifers {
  using SafeERC20 for IERC20;

  constructor() OwnershipModifers() {}

  function sweepFee() public view returns (uint256) {
    return LibSweep.diamondStorage().sweepFee;
  }

  function defaultPaymentToken() public view returns (IERC20) {
    return LibSweep.diamondStorage().defaultPaymentToken;
  }

  function weth() public view returns (IERC20) {
    return LibSweep.diamondStorage().weth;
  }

  function troveMarketplace() public view returns (ITroveMarketplace) {
    return LibSweep.diamondStorage().troveMarketplace;
  }

  function feeBasisPoints() public pure returns (uint256) {
    return LibSweep.FEE_BASIS_POINTS;
  }

  function calculateFee(uint256 _amount) external view returns (uint256) {
    return LibSweep._calculateFee(_amount);
  }

  function calculateAmountAmountWithoutFees(uint256 _amountWithFee)
    external
    view
    returns (uint256)
  {
    return LibSweep._calculateAmountWithoutFees(_amountWithFee);
  }

  function setFee(uint256 _fee) external onlyOwner {
    LibSweep.diamondStorage().sweepFee = _fee;
  }

  function setMarketplaceContract(ITroveMarketplace _troveMarketplace)
    external
    onlyOwner
  {
    LibSweep.diamondStorage().troveMarketplace = _troveMarketplace;
  }

  function setDefaultPaymentToken(IERC20 _defaultPaymentToken)
    external
    onlyOwner
  {
    LibSweep.diamondStorage().defaultPaymentToken = _defaultPaymentToken;
  }

  function setWeth(IERC20 _weth) external onlyOwner {
    LibSweep.diamondStorage().weth = _weth;
  }

  function TROVE_ID() public pure returns (uint256) {
    return LibSweep.TROVE_ID;
  }

  function STRATOS_ID() public pure returns (uint256) {
    return LibSweep.STRATOS_ID;
  }

  function sumTotalPrice(BuyOrder[] memory _buyOrders)
    internal
    pure
    returns (uint256 totalPrice)
  {
    uint256 i = 0;
    uint256 length = _buyOrders.length;
    for (; i < length; ) {
      totalPrice += _buyOrders[i].quantity * _buyOrders[i].price;
      unchecked {
        ++i;
      }
    }
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
}
