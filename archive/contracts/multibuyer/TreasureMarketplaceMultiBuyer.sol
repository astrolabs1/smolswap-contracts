// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";

import "./TokenReceiver.sol";

import "./libraries/FailureActions.sol";

// import "./libraries/Math.sol";
// import "./libraries/SafeMath.sol";
import "./interfaces/ITreasureMarketplace.sol";

import "hardhat/console.sol";

contract TreasureMarketplaceMultiBuyer is
    Ownable,
    ReentrancyGuard,
    TokenReceiver,
    ERC165
{
    using SafeERC20 for IERC20;

    struct BuyOrder {
        address assetAddress;
        uint256 tokenId;
        address seller;
        uint256 quantity;
        uint256 maxPricePerItem;
        uint8 failureAction;
    }

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    uint256 public constant MAX_UINT256 =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    uint256 public fees;
    address public feeRecipient;
    uint256 public minTotalPriceForFee = 1000000000;
    uint256 public constant BASIS_POINTS = 1000000000;

    IERC20 public defaultPaymentToken;

    IUniswapV2Router02 public uniswapRouter;
    IUniswapV2Router02 public sushiswapRouter;

    ITreasureMarketplace public marketplace;

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

    function emitSuccessBuyItemEvent(
        address _nftAddress,
        uint256 _tokenId,
        address _seller,
        address _buyer,
        uint256 _quantity,
        uint256 _price
    ) internal {
        emit SuccessBuyItem(
            _nftAddress,
            _tokenId,
            _seller,
            _buyer,
            _quantity,
            _price
        );
    }

    function emitCaughtFailureBuyItemEvent(
        address _nftAddress,
        uint256 _tokenId,
        address _seller,
        address _buyer,
        uint256 _quantity,
        uint256 _price,
        bytes memory _errorReason
    ) internal {
        emit CaughtFailureBuyItem(
            _nftAddress,
            _tokenId,
            _seller,
            _buyer,
            _quantity,
            _price,
            _errorReason
        );
    }

    constructor(
        ITreasureMarketplace _treasureMarketplace,
        address _defaultPaymentToken,
        address _uniswapRouter,
        address _sushiswapRouter,
        uint256 _fees,
        address _feeRecipient
    ) {
        marketplace = _treasureMarketplace;

        defaultPaymentToken = IERC20(_defaultPaymentToken);

        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        sushiswapRouter = IUniswapV2Router02(_sushiswapRouter);

        fees = _fees;
        feeRecipient = _feeRecipient;
    }

    // constructor() {}

    function calculateFee(uint256 _amount) public view returns (uint256) {
        if (_amount < minTotalPriceForFee) {
            return 0;
        }
        return (_amount * fees) / BASIS_POINTS;
    }

    function _calculateFee(uint256 _amount) internal view returns (uint256) {
        if (_amount < minTotalPriceForFee) {
            return 0;
        }
        return (_amount * fees) / BASIS_POINTS;
    }

    function setMarketplaceContract(ITreasureMarketplace _treasureMarketplace)
        external
        onlyOwner
    {
        marketplace = _treasureMarketplace;
    }

    function setFees(uint256 _fees) external onlyOwner {
        fees = _fees;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
    }

    function setMinTotalPriceForFee(uint256 _minTotalPriceForFee)
        external
        onlyOwner
    {
        minTotalPriceForFee = _minTotalPriceForFee;
    }

    function setDefaultPaymentToken(IERC20 _defaultPaymentToken)
        external
        onlyOwner
    {
        defaultPaymentToken = _defaultPaymentToken;
    }

    // approve token to TreasureMarketplace contract address
    function approveDefaultPaymentTokensToTreasureMarketplace()
        external
        onlyOwner
        nonReentrant
    {
        defaultPaymentToken.safeApprove(address(marketplace), MAX_UINT256);
    }

    function approveERC20TokenToContract(
        IERC20 _token,
        address _contract,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        _token.safeApprove(address(_contract), uint256(_amount));
    }

    function transferERC20TokenTo(
        IERC20 _token,
        address _address,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        _token.safeTransfer(address(_address), uint256(_amount));
    }

    function setUniswapRouter(IUniswapV2Router02 _uniswapRouter)
        external
        onlyOwner
    {
        uniswapRouter = _uniswapRouter;
    }

    function setSushiswapRouter(IUniswapV2Router02 _sushiswapRouter)
        external
        onlyOwner
    {
        sushiswapRouter = _sushiswapRouter;
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function calculateMinETHInputForOutputPaymentTokens(
        uint256 _outputPaymentTokenAmount,
        uint8 _routerId
    ) public view returns (uint256[] memory) {
        address[] memory path = new address[](2);
        if (_routerId == 0) {
            path[0] = uniswapRouter.WETH();
            path[1] = address(defaultPaymentToken);
            return uniswapRouter.getAmountsIn(_outputPaymentTokenAmount, path);
        } else {
            path[0] = sushiswapRouter.WETH();
            path[1] = address(defaultPaymentToken);
            return
                sushiswapRouter.getAmountsIn(_outputPaymentTokenAmount, path);
        }
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function calculateMinTokensInputForOutputPaymentTokens(
        address _inputTokenAddress,
        uint256 _outputPaymentTokenAmount,
        uint8 _routerId
    ) public view returns (uint256[] memory) {
        address[] memory path = new address[](2);
        if (_routerId == 0) {
            path[0] = _inputTokenAddress;
            path[1] = address(defaultPaymentToken);
            return uniswapRouter.getAmountsIn(_outputPaymentTokenAmount, path);
        } else {
            path[0] = _inputTokenAddress;
            path[1] = address(defaultPaymentToken);
            return
                sushiswapRouter.getAmountsIn(_outputPaymentTokenAmount, path);
        }
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function swapETHForExactDefaultPaymentTokens(
        uint256 _amountOut,
        uint8 _routerId,
        uint256 _deadline
    ) internal returns (uint256[] memory) {
        address[] memory path = new address[](2);

        if (_routerId == 0) {
            path[0] = uniswapRouter.WETH();
            path[1] = address(defaultPaymentToken);
            return
                uniswapRouter.swapETHForExactTokens{value: msg.value}(
                    _amountOut,
                    path,
                    address(this),
                    _deadline
                );
        } else {
            path[0] = sushiswapRouter.WETH();
            path[1] = address(defaultPaymentToken);
            return
                sushiswapRouter.swapETHForExactTokens{value: msg.value}(
                    _amountOut,
                    path,
                    address(this),
                    _deadline
                );
        }
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function swapTokensForExactDefaultPaymentTokens(
        uint256 _amountOut,
        uint256 _amountInMax,
        address _inputERC20,
        uint256 _deadline,
        uint8 _routerId
    ) internal returns (uint256[] memory) {
        IERC20(_inputERC20).safeTransferFrom(
            msg.sender,
            address(this),
            _amountInMax
        );
        address[] memory path = new address[](2);

        if (_routerId == 0) {
            path[0] = _inputERC20;
            path[1] = address(defaultPaymentToken);
            IERC20(_inputERC20).approve(address(uniswapRouter), _amountInMax);
            return
                uniswapRouter.swapTokensForExactTokens(
                    _amountOut,
                    _amountInMax,
                    path,
                    address(this),
                    _deadline
                );
        } else {
            path[0] = _inputERC20;
            path[1] = address(defaultPaymentToken);
            IERC20(_inputERC20).approve(address(uniswapRouter), _amountInMax);
            return
                sushiswapRouter.swapTokensForExactTokens(
                    _amountOut,
                    _amountInMax,
                    path,
                    address(this),
                    _deadline
                );
        }
    }

    function sumTotalPrice(BuyOrder[] memory _buyOrders)
        internal
        pure
        returns (uint256)
    {
        uint256 totalPrice = 0;
        for (uint256 i = 0; i < _buyOrders.length; i++) {
            totalPrice +=
                _buyOrders[i].quantity *
                _buyOrders[i].maxPricePerItem;
        }
        return totalPrice;
    }

    function getListing(
        address _nftAddress,
        uint256 _tokenId,
        address _seller
    ) internal view returns (ITreasureMarketplace.Listing memory) {
        return marketplace.listings(_nftAddress, _tokenId, _seller);
    }

    function tryBuyItem(
        BuyOrder memory _buyOrder,
        uint256 _maxSpendAllowanceLeft
    )
        internal
        returns (
            uint256 totalPrice,
            bool success,
            uint8 failureAction
        )
    {
        // check if the listing exists
        ITreasureMarketplace.Listing memory listing = getListing(
            _buyOrder.assetAddress,
            _buyOrder.tokenId,
            _buyOrder.seller
        );

        // check if the price is correct
        if (listing.pricePerItem > _buyOrder.maxPricePerItem) {
            // skip this item
            return (0, false, FailureActions.MAX_PRICE_PER_ITEM_EXCEEDED);
        }

        // not enough listed items
        if (listing.quantity < _buyOrder.quantity) {
            if (
                FailureActions.checkFailure(
                    _buyOrder.failureAction,
                    FailureActions.INSUFFICIENT_QUANTITIES_ERC1155
                )
            ) {
                // else buy all listed items even if it's less than requested
                _buyOrder.quantity = listing.quantity;
            } else {
                // skip this item
                return (
                    0,
                    false,
                    FailureActions.INSUFFICIENT_QUANTITIES_ERC1155
                );
            }
        }

        // check if total price is less than max spend allowance left
        if (
            (listing.pricePerItem * _buyOrder.quantity) > _maxSpendAllowanceLeft
        ) {
            // skip this item
            return (0, false, FailureActions.MAX_SPEND_ALLOWANCE_EXCEEDED);
        }

        uint256 totalSpent = 0;

        try
            marketplace.buyItem(
                _buyOrder.assetAddress,
                _buyOrder.tokenId,
                _buyOrder.seller,
                _buyOrder.quantity
            )
        {
            emitSuccessBuyItemEvent(
                _buyOrder.assetAddress,
                _buyOrder.tokenId,
                _buyOrder.seller,
                msg.sender,
                _buyOrder.quantity,
                listing.pricePerItem
            );

            if (
                IERC165(_buyOrder.assetAddress).supportsInterface(
                    INTERFACE_ID_ERC721
                )
            ) {
                IERC721(_buyOrder.assetAddress).safeTransferFrom(
                    address(this),
                    msg.sender,
                    _buyOrder.tokenId
                );
            } else if (
                IERC165(_buyOrder.assetAddress).supportsInterface(
                    INTERFACE_ID_ERC1155
                )
            ) {
                IERC1155(_buyOrder.assetAddress).safeTransferFrom(
                    address(this),
                    msg.sender,
                    _buyOrder.tokenId,
                    _buyOrder.quantity,
                    bytes("")
                );
            } else {
                revert("invalid nft address, (ERC165)");
            }
            totalSpent = listing.pricePerItem * _buyOrder.quantity;
        } catch (bytes memory errorReason) {
            emitCaughtFailureBuyItemEvent(
                _buyOrder.assetAddress,
                _buyOrder.tokenId,
                _buyOrder.seller,
                msg.sender,
                _buyOrder.quantity,
                listing.pricePerItem,
                errorReason
            );

            if (
                FailureActions.checkFailure(
                    _buyOrder.failureAction,
                    FailureActions.MARKETPLACE_BUY_ITEM_REVERTED
                )
            ) {
                revert("Order Fail: revert (settings)");
            } else {
                // skip this item
                return (0, false, FailureActions.MARKETPLACE_BUY_ITEM_REVERTED);
            }
        }

        return (totalSpent, true, FailureActions.NONE);
    }

    function multiBuyUsingPaymentTokenWithTryCatch(
        BuyOrder[] memory _buyOrders,
        uint8 _failureAction,
        uint256 _maxTotalPrice
    ) external nonReentrant {
        uint256 totalPrice = sumTotalPrice(_buyOrders);

        totalPrice += calculateFee(totalPrice);

        // transfer payment tokens to this contract
        defaultPaymentToken.safeTransferFrom(
            msg.sender,
            address(this),
            totalPrice
        );

        // approve tokens to TreasureMarketplace contract address
        // already done in the previous step

        // buy items
        uint256 totalSpentTokenAmount = _multiBuyUsingPaymentTokenWithTryCatch(
            _buyOrders,
            _maxTotalPrice
        );

        // transfer back failed payment tokens to the buyer
        if (totalSpentTokenAmount == 0) {
            if (
                FailureActions.checkFailure(
                    _failureAction,
                    FailureActions.EVERY_BUY_FAILURE
                )
            ) {
                revert("All tokens failed to be bought!");
            }
        } else if (totalSpentTokenAmount < totalPrice) {
            defaultPaymentToken.safeTransfer(
                msg.sender,
                totalPrice - totalSpentTokenAmount
            );
        }
    }

    function _multiBuyUsingPaymentTokenWithTryCatch(
        BuyOrder[] memory _buyOrders,
        uint256 _maxTotalPrice
    ) internal returns (uint256) {
        // buy all assets
        uint256 totalSpentTokenAmount = 0;
        for (uint256 i = 0; i < _buyOrders.length; i++) {
            uint256 maxAmountLeft = _maxTotalPrice - totalSpentTokenAmount;
            (
                uint256 spentAmount,
                bool spentSuccess,
                uint8 spentError
            ) = tryBuyItem(_buyOrders[i], maxAmountLeft);

            if (spentSuccess) {
                totalSpentTokenAmount += spentAmount;
            } else {
                if (spentError == FailureActions.MAX_SPEND_ALLOWANCE_EXCEEDED) {
                    if (
                        FailureActions.checkFailure(
                            _buyOrders[i].failureAction,
                            FailureActions.MAX_SPEND_ALLOWANCE_EXCEEDED
                        )
                    ) {
                        return totalSpentTokenAmount;
                    }
                }
            }
        }

        // calculate fee
        uint256 totalFees = calculateFee(totalSpentTokenAmount);

        // transfer fee to fee recipient
        if (totalFees > 0) {
            defaultPaymentToken.safeTransfer(feeRecipient, totalFees);
        }

        return totalSpentTokenAmount + totalFees;
    }

    function sweepUsingPaymentToken(
        BuyOrder[] memory _buyOrders,
        uint256[] memory _maxSuccessAndFailCounts,
        uint256 _maxTotalPrice
    ) external {
        uint256 totalPrice = _maxTotalPrice;

        totalPrice += calculateFee(totalPrice);

        // transfer payment tokens to this contract
        defaultPaymentToken.safeTransferFrom(
            msg.sender,
            address(this),
            totalPrice
        );

        // approve tokens to TreasureMarketplace contract address
        // already done in the previous step

        // BuyOrder[] memory buyOrders = new BuyOrder[](
        //     _outputAssetsAddresses.length
        // );

        // {
        //     for (uint256 i = 0; i < _outputAssetsAddresses.length; i++) {
        //         buyOrders[i] = BuyOrder(
        //             _outputAssetsAddresses[i],
        //             _outputAssetsTokenIds[i],
        //             _outputAssetsOwners[i],
        //             _outputAssetsQuantities[i],
        //             _outputAssetsMaxPricesPerItem[i],
        //             _failureAction
        //         );
        //     }
        // }

        // buy items
        uint256 totalSpentTokenAmount = _sweepUsingPaymentToken(
            _buyOrders,
            _maxSuccessAndFailCounts,
            _maxTotalPrice
        );

        // transfer back failed payment tokens to the buyer
        if (totalSpentTokenAmount == 0) {
            if (
                FailureActions.checkFailure(
                    _buyOrders[0].failureAction,
                    FailureActions.EVERY_BUY_FAILURE
                )
            ) {
                revert("All tokens failed to be bought!");
            }
        } else if (totalSpentTokenAmount < totalPrice) {
            defaultPaymentToken.safeTransfer(
                msg.sender,
                totalPrice - totalSpentTokenAmount
            );
        }
    }

    function _sweepUsingPaymentToken(
        BuyOrder[] memory _buyOrders,
        uint256[] memory _maxSuccessAndFailCounts,
        uint256 _maxTotalPrice
    ) internal returns (uint256) {
        // buy all assets
        uint256 totalSpentTokenAmount = 0;
        uint256[] memory successAndFailCounts = new uint256[](2);
        for (uint256 i = 0; i < _buyOrders.length; i++) {
            {
                if (
                    successAndFailCounts[0] >= _maxSuccessAndFailCounts[0] ||
                    successAndFailCounts[1] >= _maxSuccessAndFailCounts[1]
                ) {
                    break;
                }
            }

            (
                uint256 spentAmount,
                bool spentSuccess,
                uint8 spentError
            ) = tryBuyItem(
                    _buyOrders[i],
                    (_maxTotalPrice - totalSpentTokenAmount)
                );

            if (spentSuccess) {
                totalSpentTokenAmount += spentAmount;
                successAndFailCounts[0]++;
            } else {
                if (spentError == FailureActions.MAX_SPEND_ALLOWANCE_EXCEEDED) {
                    if (
                        FailureActions.checkFailure(
                            _buyOrders[i].failureAction,
                            FailureActions.MAX_SPEND_ALLOWANCE_EXCEEDED
                        )
                    ) {
                        return totalSpentTokenAmount;
                    }
                }
                successAndFailCounts[1]++;
            }
        }

        // // calculate fee
        // uint256 totalFees = calculateFee(totalSpentTokenAmount);
        // uint256 totalFees = calculateFee(totalSpentTokenAmount);

        // // transfer fee to fee recipient
        // if (totalFees > 0) {
        //     defaultPaymentToken.safeTransfer(feeRecipient, totalFees);
        // }

        // return totalSpentTokenAmount + totalFees;

        return totalSpentTokenAmount;
    }

    // function multiBuyUsingPaymentTokenAllAtomic(
    //     address[] calldata _outputAssetsAddresses,
    //     uint256[] calldata _outputAssetsTokenIds,
    //     address[] calldata _outputAssetsOwners,
    //     uint256[] calldata _outputAssetsQuantities,
    //     uint256[] calldata _outputAssetsMaxPricesPerItem
    // ) external nonReentrant {
    //     uint256 outputAssetsCount = _outputAssetsAddresses.length;

    //     if (
    //         outputAssetsCount != _outputAssetsQuantities.length &&
    //         outputAssetsCount != _outputAssetsMaxPricesPerItem.length &&
    //         outputAssetsCount != _outputAssetsTokenIds.length
    //     ) {
    //         revert("Arrays must have the same length");
    //     }

    //     uint256 totalPrice = sumTotalPrice(
    //         _outputAssetsQuantities,
    //         _outputAssetsMaxPricesPerItem
    //     );

    //     totalPrice += calculateFee(totalPrice);

    //     // transfer payment tokens to this contract
    //     defaultPaymentToken.safeTransferFrom(
    //         msg.sender,
    //         address(this),
    //         totalPrice
    //     );

    //     // approve tokens to TreasureMarketplace contract address
    //     // already done in the previous step

    //     // buy items
    //     uint256 totalSpentTokenAmount = _multiBuyUsingPaymentTokenAllAtomic(
    //         _outputAssetsAddresses,
    //         _outputAssetsTokenIds,
    //         _outputAssetsOwners,
    //         _outputAssetsQuantities,
    //         _outputAssetsMaxPricesPerItem
    //     );

    //     // if some tokens not used, transfer back to the buyer
    //     if (totalSpentTokenAmount < totalPrice) {
    //         defaultPaymentToken.safeTransfer(
    //             msg.sender,
    //             totalPrice - totalSpentTokenAmount
    //         );
    //     }
    // }

    // function _multiBuyUsingPaymentTokenAllAtomic(
    //     address[] calldata _outputAssetsAddresses,
    //     uint256[] calldata _outputAssetsTokenIds,
    //     address[] calldata _outputAssetsOwners,
    //     uint256[] calldata _outputAssetsQuantities,
    //     uint256[] calldata _outputAssetsMaxPricesPerItem
    // ) internal returns (uint256) {
    //     uint256 totalSpentTokenAmount = 0;

    //     for (uint256 i = 0; i < _outputAssetsAddresses.length; i++) {
    //         ITreasureMarketplace.Listing memory listing = getListing(
    //             _outputAssetsAddresses[i],
    //             _outputAssetsTokenIds[i],
    //             _outputAssetsOwners[i]
    //         );

    //         require(
    //             listing.pricePerItem <= _outputAssetsMaxPricesPerItem[i],
    //             "pricePerItem too high! Reverting..."
    //         );

    //         marketplace.buyItem(
    //             _outputAssetsAddresses[i],
    //             _outputAssetsTokenIds[i],
    //             _outputAssetsOwners[i],
    //             _outputAssetsQuantities[i]
    //         );

    //         emitSuccessBuyItemEvent(
    //             _outputAssetsAddresses[i],
    //             _outputAssetsTokenIds[i],
    //             _outputAssetsOwners[i],
    //             msg.sender,
    //             _outputAssetsQuantities[i],
    //             listing.pricePerItem
    //         );

    //         if (
    //             IERC165(_outputAssetsAddresses[i]).supportsInterface(
    //                 INTERFACE_ID_ERC721
    //             )
    //         ) {
    //             IERC721(_outputAssetsAddresses[i]).safeTransferFrom(
    //                 address(this),
    //                 msg.sender,
    //                 _outputAssetsTokenIds[i]
    //             );
    //         } else if (
    //             IERC165(_outputAssetsAddresses[i]).supportsInterface(
    //                 INTERFACE_ID_ERC1155
    //             )
    //         ) {
    //             IERC1155(_outputAssetsAddresses[i]).safeTransferFrom(
    //                 address(this),
    //                 msg.sender,
    //                 _outputAssetsTokenIds[i],
    //                 _outputAssetsQuantities[i],
    //                 bytes("")
    //             );
    //         } else {
    //             revert("invalid nft address");
    //         }

    //         totalSpentTokenAmount +=
    //             listing.pricePerItem *
    //             _outputAssetsQuantities[i];
    //     }

    //     // calculate fee
    //     uint256 totalFees = calculateFee(totalSpentTokenAmount);

    //     // transfer fee to fee recipient
    //     if (totalFees > 0) {
    //         defaultPaymentToken.safeTransfer(feeRecipient, totalFees);
    //     }

    //     return totalSpentTokenAmount + totalFees;
    // }

    // fallback
    fallback() external payable {
        revert("Fallback: reverting...");
    }

    receive() external payable {
        // revert("Receive: reverting...");
    }
}
