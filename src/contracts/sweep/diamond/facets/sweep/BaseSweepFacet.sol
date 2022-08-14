// SPDX-License-Identifier: MIT
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

contract BaseSweepFacet is OwnershipModifers {
  using SafeERC20 for IERC20;

  constructor() OwnershipModifers() {}

  function sweepFee() public view returns (uint256) {
    return LibSweep.diamondStorage().sweepFee;
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

  function getFee() external view onlyOwner returns (uint256) {
    return LibSweep.diamondStorage().sweepFee;
  }

  function _approveERC20TokenToContract(
    IERC20 _token,
    address _contract,
    uint256 _amount
  ) internal {
    _token.safeApprove(address(_contract), uint256(_amount));
  }

  function approveERC20TokenToContract(
    IERC20 _token,
    address _contract,
    uint256 _amount
  ) external onlyOwner {
    _approveERC20TokenToContract(_token, _contract, _amount);
  }

  // rescue functions
  // those have not been tested yet
  function transferETHTo(address payable _to, uint256 _amount)
    external
    onlyOwner
  {
    _to.transfer(_amount);
  }

  function transferERC20TokenTo(
    IERC20 _token,
    address _address,
    uint256 _amount
  ) external onlyOwner {
    _token.safeTransfer(address(_address), uint256(_amount));
  }

  function transferERC721To(
    IERC721 _token,
    address _to,
    uint256 _tokenId
  ) external onlyOwner {
    _token.safeTransferFrom(address(this), _to, _tokenId);
  }

  function transferERC1155To(
    IERC1155 _token,
    address _to,
    uint256[] calldata _tokenIds,
    uint256[] calldata _amounts,
    bytes calldata _data
  ) external onlyOwner {
    _token.safeBatchTransferFrom(
      address(this),
      _to,
      _tokenIds,
      _amounts,
      _data
    );
  }

  function TROVE_ID() external pure returns (uint256) {
    return LibSweep.TROVE_ID;
  }

  function STRATOS_ID() external pure returns (uint256) {
    return LibSweep.STRATOS_ID;
  }

  function addMarketplace(address _marketplace, address _paymentToken)
    external
    onlyOwner
  {
    LibSweep._addMarketplace(_marketplace, _paymentToken);
  }

  function setMarketplace(
    uint256 _marketplaceId,
    address _marketplace,
    address _paymentToken
  ) external onlyOwner {
    LibSweep._setMarketplace(_marketplaceId, _marketplace, _paymentToken);
  }

  function getMarketplace(uint16 _marketplaceId)
    external
    view
    returns (address)
  {
    return LibSweep.diamondStorage().marketplaces[_marketplaceId];
  }

  function getMarketplacePaymentToken(uint16 _marketplaceId)
    external
    view
    returns (address)
  {
    return LibSweep.diamondStorage().paymentTokens[_marketplaceId];
  }
}
