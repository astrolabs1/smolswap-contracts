// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

//           _____                    _____                   _______                   _____            _____                    _____                    _____                    _____
//          /\    \                  /\    \                 /::\    \                 /\    \          /\    \                  /\    \                  /\    \                  /\    \
//         /::\    \                /::\____\               /::::\    \               /::\____\        /::\    \                /::\____\                /::\    \                /::\    \
//        /::::\    \              /::::|   |              /::::::\    \             /:::/    /       /::::\    \              /:::/    /               /::::\    \              /::::\    \
//       /::::::\    \            /:::::|   |             /::::::::\    \           /:::/    /       /::::::\    \            /:::/   _/___            /::::::\    \            /::::::\    \
//      /:::/\:::\    \          /::::::|   |            /:::/~~\:::\    \         /:::/    /       /:::/\:::\    \          /:::/   /\    \          /:::/\:::\    \          /:::/\:::\    \
//     /:::/__\:::\    \        /:::/|::|   |           /:::/    \:::\    \       /:::/    /       /:::/__\:::\    \        /:::/   /::\____\        /:::/__\:::\    \        /:::/__\:::\    \
//     \:::\   \:::\    \      /:::/ |::|   |          /:::/    / \:::\    \     /:::/    /        \:::\   \:::\    \      /:::/   /:::/    /       /::::\   \:::\    \      /::::\   \:::\    \
//   ___\:::\   \:::\    \    /:::/  |::|___|______   /:::/____/   \:::\____\   /:::/    /       ___\:::\   \:::\    \    /:::/   /:::/   _/___    /::::::\   \:::\    \    /::::::\   \:::\    \
//  /\   \:::\   \:::\    \  /:::/   |::::::::\    \ |:::|    |     |:::|    | /:::/    /       /\   \:::\   \:::\    \  /:::/___/:::/   /\    \  /:::/\:::\   \:::\    \  /:::/\:::\   \:::\____\
// /::\   \:::\   \:::\____\/:::/    |:::::::::\____\|:::|____|     |:::|    |/:::/____/       /::\   \:::\   \:::\____\|:::|   /:::/   /::\____\/:::/  \:::\   \:::\____\/:::/  \:::\   \:::|    |
// \:::\   \:::\   \::/    /\::/    / ~~~~~/:::/    / \:::\    \   /:::/    / \:::\    \       \:::\   \:::\   \::/    /|:::|__/:::/   /:::/    /\::/    \:::\  /:::/    /\::/    \:::\  /:::|____|
//  \:::\   \:::\   \/____/  \/____/      /:::/    /   \:::\    \ /:::/    /   \:::\    \       \:::\   \:::\   \/____/  \:::\/:::/   /:::/    /  \/____/ \:::\/:::/    /  \/_____/\:::\/:::/    /
//   \:::\   \:::\    \                  /:::/    /     \:::\    /:::/    /     \:::\    \       \:::\   \:::\    \       \::::::/   /:::/    /            \::::::/    /            \::::::/    /
//    \:::\   \:::\____\                /:::/    /       \:::\__/:::/    /       \:::\    \       \:::\   \:::\____\       \::::/___/:::/    /              \::::/    /              \::::/    /
//     \:::\  /:::/    /               /:::/    /         \::::::::/    /         \:::\    \       \:::\  /:::/    /        \:::\__/:::/    /               /:::/    /                \::/____/
//      \:::\/:::/    /               /:::/    /           \::::::/    /           \:::\    \       \:::\/:::/    /          \::::::::/    /               /:::/    /                  ~~
//       \::::::/    /               /:::/    /             \::::/    /             \:::\    \       \::::::/    /            \::::::/    /               /:::/    /
//        \::::/    /               /:::/    /               \::/____/               \:::\____\       \::::/    /              \::::/    /               /:::/    /
//         \::/    /                \::/    /                 ~~                      \::/    /        \::/    /                \::/____/                \::/    /
//          \/____/                  \/____/                                           \/____/          \/____/                  ~~                       \/____/

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
import "./libraries/SettingsBitFlag.sol";
import "./libraries/Math.sol";
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
    }

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    uint256 public constant MAX_UINT256 =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    IERC20 public defaultPaymentToken;
    ITreasureMarketplace public marketplace;

    IUniswapV2Router02[] public swapRouters;

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
        IUniswapV2Router02[] memory _swapRouters
    ) {
        marketplace = _treasureMarketplace;

        defaultPaymentToken = IERC20(_defaultPaymentToken);

        swapRouters = _swapRouters;

        defaultPaymentToken.safeApprove(address(marketplace), MAX_UINT256);
    }

    // constructor() {}

    function getSwapRouterCount() public view returns (uint256) {
        return swapRouters.length;
    }

    function setMarketplaceContract(ITreasureMarketplace _treasureMarketplace)
        external
        onlyOwner
    {
        marketplace = _treasureMarketplace;
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
    ) external onlyOwner nonReentrant {
        _token.safeTransfer(address(_address), uint256(_amount));
    }

    function transferERC721To(
        IERC721 _token,
        address _to,
        uint256 _tokenId
    ) external onlyOwner nonReentrant {
        _token.safeTransferFrom(address(this), _to, _tokenId);
    }

    function transferERC1155To(
        IERC1155 _token,
        address _to,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external onlyOwner nonReentrant {
        _token.safeBatchTransferFrom(
            address(this),
            _to,
            _tokenIds,
            _amounts,
            _data
        );
    }

    function addSwapRouter(IUniswapV2Router02 _router) external onlyOwner {
        swapRouters.push(_router);
    }

    function setSwapRouter(uint256 routerId, IUniswapV2Router02 _router)
        external
        onlyOwner
    {
        require(swapRouters.length < MAX_UINT256);
        swapRouters[routerId] = _router;
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function calculateMinETHInputForOutputPaymentTokens(
        uint256 _outputPaymentTokenAmount,
        uint256 _routerId
    ) public view returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = router.WETH();
        path[1] = address(defaultPaymentToken);
        return router.getAmountsIn(_outputPaymentTokenAmount, path);
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function calculateMinTokensInputForOutputPaymentTokens(
        address _inputTokenAddress,
        uint256 _outputPaymentTokenAmount,
        uint256 _routerId
    ) public view returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = _inputTokenAddress;
        path[1] = address(defaultPaymentToken);
        return router.getAmountsIn(_outputPaymentTokenAmount, path);
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function _swapETHForExactPaymentTokens(
        uint256 _amountOut,
        uint256 _routerId,
        uint256 _deadline
    ) internal returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = router.WETH();
        path[1] = address(defaultPaymentToken);
        return
            router.swapETHForExactTokens{value: msg.value}(
                _amountOut,
                path,
                address(this),
                _deadline
            );
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function _swapTokensForExactPaymentTokens(
        uint256 _amountOut,
        uint256 _amountInMax,
        address _inputERC20,
        uint256 _routerId,
        uint256 _deadline
    ) internal returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = _inputERC20;
        path[1] = address(defaultPaymentToken);
        IERC20(_inputERC20).approve(address(router), _amountInMax);
        return
            router.swapTokensForExactTokens(
                _amountOut,
                _amountInMax,
                path,
                address(this),
                _deadline
            );
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function _swapExactETHForPaymentTokens(
        uint256 _amountOutMin,
        uint256 _routerId,
        uint256 _deadline
    ) internal returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = router.WETH();
        path[1] = address(defaultPaymentToken);
        return
            router.swapExactETHForTokens{value: msg.value}(
                _amountOutMin,
                path,
                address(this),
                _deadline
            );
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function _swapExactTokensForPaymentTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _inputERC20,
        uint256 _routerId,
        uint256 _deadline
    ) internal returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = _inputERC20;
        path[1] = address(defaultPaymentToken);
        IERC20(_inputERC20).approve(address(router), _amountIn);
        return
            router.swapExactTokensForTokens(
                _amountIn,
                _amountOutMin,
                path,
                address(this),
                _deadline
            );
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function _swapExactPaymentTokensForETH(
        uint256 _amountIn,
        uint256 _amountOutMin,
        uint256 _routerId,
        uint256 _deadline
    ) internal returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = address(defaultPaymentToken);
        path[1] = router.WETH();
        IERC20(defaultPaymentToken).approve(address(router), _amountIn);
        return
            router.swapExactTokensForETH(
                _amountIn,
                _amountOutMin,
                path,
                address(this),
                _deadline
            );
    }

    // _routerId: 0 for uniswap, 1 for sushiswap
    function _swapExactPaymentTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _outputTokenAddress,
        uint256 _routerId,
        uint256 _deadline
    ) internal returns (uint256[] memory) {
        address[] memory path = new address[](2);
        IUniswapV2Router02 router = swapRouters[_routerId];
        path[0] = address(defaultPaymentToken);
        path[1] = _outputTokenAddress;
        IERC20(defaultPaymentToken).approve(address(router), _amountIn);
        return
            router.swapExactTokensForTokens(
                _amountIn,
                _amountOutMin,
                path,
                address(this),
                _deadline
            );
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
        uint16 _inputSettingsBitFlag,
        uint256 _maxSpendAllowanceLeft
    )
        internal
        returns (
            uint256 totalPrice,
            bool success,
            uint16 failReason
        )
    {
        uint256 quantityToBuy = _buyOrder.quantity;
        // check if the listing exists
        ITreasureMarketplace.Listing memory listing = getListing(
            _buyOrder.assetAddress,
            _buyOrder.tokenId,
            _buyOrder.seller
        );

        // check if the price is correct
        if (listing.pricePerItem > _buyOrder.maxPricePerItem) {
            // skip this item
            return (0, false, SettingsBitFlag.MAX_PRICE_PER_ITEM_EXCEEDED);
        }

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
                return (
                    0,
                    false,
                    SettingsBitFlag.INSUFFICIENT_QUANTITY_ERC1155
                );
            }
        }

        // check if total price is less than max spend allowance left
        if ((listing.pricePerItem * quantityToBuy) > _maxSpendAllowanceLeft) {
            // skip this item
            return (0, false, SettingsBitFlag.MAX_SPEND_ALLOWANCE_EXCEEDED);
        }

        uint256 totalSpent = 0;
        try
            marketplace.buyItem(
                _buyOrder.assetAddress,
                _buyOrder.tokenId,
                _buyOrder.seller,
                quantityToBuy
            )
        {
            if (
                (
                    SettingsBitFlag.checkSetting(
                        _inputSettingsBitFlag,
                        SettingsBitFlag.EMIT_SUCCESS_EVENT_LOGS
                    )
                )
            ) {
                emitSuccessBuyItemEvent(
                    _buyOrder.assetAddress,
                    _buyOrder.tokenId,
                    _buyOrder.seller,
                    msg.sender,
                    quantityToBuy,
                    listing.pricePerItem
                );
            }

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
                    quantityToBuy,
                    bytes("")
                );
            } else {
                revert("invalid nft address, not ERC721 or ERC1155 (ERC165)");
            }
            totalSpent = listing.pricePerItem * quantityToBuy;
        } catch (bytes memory errorReason) {
            if (
                SettingsBitFlag.checkSetting(
                    _inputSettingsBitFlag,
                    SettingsBitFlag.EMIT_FAILURE_EVENT_LOGS
                )
            ) {
                emitCaughtFailureBuyItemEvent(
                    _buyOrder.assetAddress,
                    _buyOrder.tokenId,
                    _buyOrder.seller,
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
            ) {
                revert(
                    "Buy Item Reverted and Failure Action is set to MARKETPLACE_BUY_ITEM_REVERTED"
                );
            } else {
                // skip this item
                return (
                    0,
                    false,
                    SettingsBitFlag.MARKETPLACE_BUY_ITEM_REVERTED
                );
            }
        }

        return (totalSpent, true, SettingsBitFlag.NONE);
    }

    function multiBuyUsingPaymentToken(
        BuyOrder[] memory _buyOrders,
        uint16 _inputSettingsBitFlag,
        uint256 _maxTotalPrice
    ) external nonReentrant {
        uint256 totalPrice = sumTotalPrice(_buyOrders);

        totalPrice = Math.min(totalPrice, _maxTotalPrice);

        // transfer payment tokens to this contract
        defaultPaymentToken.safeTransferFrom(
            msg.sender,
            address(this),
            totalPrice
        );

        // buy items
        uint256 totalSpentTokenAmount = _multiBuyUsingPaymentToken(
            _buyOrders,
            _inputSettingsBitFlag,
            _maxTotalPrice
        );

        // transfer back failed payment tokens to the buyer
        if (totalSpentTokenAmount == 0) {
            if (
                SettingsBitFlag.checkSetting(
                    _inputSettingsBitFlag,
                    SettingsBitFlag.EVERY_BUY_FAILURE
                )
            ) {
                revert("All tokens failed to be bought!");
            } else {
                defaultPaymentToken.safeTransfer(msg.sender, totalPrice);
            }
        } else if (totalSpentTokenAmount < totalPrice) {
            defaultPaymentToken.safeTransfer(
                msg.sender,
                totalPrice - totalSpentTokenAmount
            );
        }
    }

    function _multiBuyUsingPaymentToken(
        BuyOrder[] memory _buyOrders,
        uint16 _inputSettingsBitFlag,
        uint256 _maxTotalPrice
    ) internal returns (uint256) {
        // buy all assets
        uint256 totalSpentTokenAmount = 0;
        for (uint256 i = 0; i < _buyOrders.length; i++) {
            uint256 maxAmountLeft = _maxTotalPrice - totalSpentTokenAmount;
            (
                uint256 spentAmount,
                bool spentSuccess,
                uint16 spentError
            ) = tryBuyItem(_buyOrders[i], _inputSettingsBitFlag, maxAmountLeft);

            if (spentSuccess) {
                totalSpentTokenAmount += spentAmount;
            } else {
                if (
                    spentError == SettingsBitFlag.MAX_SPEND_ALLOWANCE_EXCEEDED
                ) {
                    if (
                        SettingsBitFlag.checkSetting(
                            _inputSettingsBitFlag,
                            SettingsBitFlag.MAX_SPEND_ALLOWANCE_EXCEEDED
                        )
                    ) {
                        return totalSpentTokenAmount;
                    }
                }
            }
        }

        return totalSpentTokenAmount;
    }

    function sweepUsingPaymentToken(
        BuyOrder[] memory _buyOrders,
        uint16 _inputSettingsBitFlag,
        uint256[] memory _maxSuccessAndFailCounts,
        uint256 _maxTotalPrice,
        uint256 _minSpendAmount
    ) external nonReentrant {
        uint256 totalPrice = _maxTotalPrice;

        // transfer payment tokens to this contract
        defaultPaymentToken.safeTransferFrom(
            msg.sender,
            address(this),
            totalPrice
        );

        // buy items
        uint256 totalSpentTokenAmount = _sweepUsingPaymentToken(
            _buyOrders,
            _inputSettingsBitFlag,
            _maxSuccessAndFailCounts,
            _maxTotalPrice,
            _minSpendAmount
        );

        // transfer back failed payment tokens to the buyer
        if (totalSpentTokenAmount == 0) {
            if (
                SettingsBitFlag.checkSetting(
                    _inputSettingsBitFlag,
                    SettingsBitFlag.EVERY_BUY_FAILURE
                )
            ) {
                revert("All tokens failed to be bought!");
            } else {
                defaultPaymentToken.safeTransfer(msg.sender, totalPrice);
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
        uint16 _inputSettingsBitFlag,
        uint256[] memory _maxSuccessAndFailCounts,
        uint256 _maxTotalPrice,
        uint256 _minSpendAmount
    ) internal returns (uint256) {
        // buy all assets
        uint256 totalSpentTokenAmount = 0;
        uint256[] memory successAndFailCounts = new uint256[](2);
        for (uint256 i = 0; i < _buyOrders.length; i++) {
            if (
                successAndFailCounts[0] >= _maxSuccessAndFailCounts[0] ||
                successAndFailCounts[1] >= _maxSuccessAndFailCounts[1]
            ) {
                break;
            }

            if (totalSpentTokenAmount >= _minSpendAmount) {
                break;
            }

            (
                uint256 spentAmount,
                bool spentSuccess,
                uint16 spentError
            ) = tryBuyItem(
                    _buyOrders[i],
                    _inputSettingsBitFlag,
                    (_maxTotalPrice - totalSpentTokenAmount)
                );

            if (spentSuccess) {
                totalSpentTokenAmount += spentAmount;
                successAndFailCounts[0]++;
            } else {
                if (
                    spentError == SettingsBitFlag.MAX_SPEND_ALLOWANCE_EXCEEDED
                ) {
                    if (
                        SettingsBitFlag.checkSetting(
                            _inputSettingsBitFlag,
                            SettingsBitFlag.MAX_SPEND_ALLOWANCE_EXCEEDED
                        )
                    ) {
                        return totalSpentTokenAmount;
                    }
                }
                successAndFailCounts[1]++;
            }
        }

        return totalSpentTokenAmount;
    }

    function swapETHForExactAssets(
        BuyOrder[] memory _buyOrders,
        uint16 _inputSettingsBitFlag,
        uint256 _maxTotalPrice,
        uint256 _routerId,
        uint256 _deadline,
        bool _refundInETH
    ) external payable {
        uint256 totalPrice = _maxTotalPrice;

        // transfer payment tokens to this contract
        uint256[] memory amounts = _swapETHForExactPaymentTokens(
            totalPrice,
            _routerId,
            _deadline
        );

        // buy items
        uint256 totalSpentTokenAmount = _multiBuyUsingPaymentToken(
            _buyOrders,
            _inputSettingsBitFlag,
            _maxTotalPrice
        );

        // transfer back failed payment tokens to the buyer
        if (totalSpentTokenAmount == 0) {
            if (
                SettingsBitFlag.checkSetting(
                    _inputSettingsBitFlag,
                    SettingsBitFlag.EVERY_BUY_FAILURE
                )
            ) {
                revert("All tokens failed to be bought!");
            } else {
                if (_refundInETH) {
                    // refund in ETH
                    amounts = _swapExactPaymentTokensForETH(
                        (totalPrice),
                        0,
                        _routerId,
                        _deadline
                    );
                    payable(msg.sender).transfer(amounts[1]);
                } else {
                    // refund in payment tokens
                    defaultPaymentToken.safeTransfer(msg.sender, (totalPrice));
                }
            }
        } else if (totalSpentTokenAmount < totalPrice) {
            if (_refundInETH) {
                // refund in ETH
                amounts = _swapExactPaymentTokensForETH(
                    (totalPrice - totalSpentTokenAmount),
                    0,
                    _routerId,
                    _deadline
                );
                payable(msg.sender).transfer(amounts[1]);
            } else {
                // refund in payment tokens
                defaultPaymentToken.safeTransfer(
                    msg.sender,
                    (totalPrice - totalSpentTokenAmount)
                );
            }
        }
    }

    function sweepUsingExactETHForAssets(
        BuyOrder[] calldata _buyOrders,
        uint16 _inputSettingsBitFlag,
        uint256[] calldata _maxSuccessAndFailCounts,
        uint256 _amountOutMin,
        uint256 _routerId,
        uint256 _deadline,
        bool _refundInETH
    ) external payable {
        // transfer payment tokens to this contract
        uint256[] memory amounts = _swapExactETHForPaymentTokens(
            _amountOutMin,
            _routerId,
            _deadline
        );

        // uint256 amountIn = amounts[0];
        uint256 amountOut = amounts[1];

        // buy items
        uint256 totalSpentTokenAmount = _sweepUsingPaymentToken(
            _buyOrders,
            _inputSettingsBitFlag,
            _maxSuccessAndFailCounts,
            amountOut,
            amountOut
        );

        // transfer back failed payment tokens to the buyer
        if (totalSpentTokenAmount == 0) {
            if (
                SettingsBitFlag.checkSetting(
                    _inputSettingsBitFlag,
                    SettingsBitFlag.EVERY_BUY_FAILURE
                )
            ) {
                revert("All tokens failed to be bought!");
            } else {
                if (_refundInETH) {
                    // refund in ETH
                    amounts = _swapExactPaymentTokensForETH(
                        (amountOut - totalSpentTokenAmount),
                        0,
                        _routerId,
                        _deadline
                    );
                    payable(msg.sender).transfer(amounts[1]);
                } else {
                    // refund in payment tokens
                    defaultPaymentToken.safeTransfer(
                        msg.sender,
                        (amountOut - totalSpentTokenAmount)
                    );
                }
            }
        } else if (totalSpentTokenAmount < amountOut) {
            if (_refundInETH) {
                // refund in ETH
                amounts = _swapExactPaymentTokensForETH(
                    (amountOut - totalSpentTokenAmount),
                    0,
                    _routerId,
                    _deadline
                );
                payable(msg.sender).transfer(amounts[1]);
            } else {
                // refund in payment tokens
                defaultPaymentToken.safeTransfer(
                    msg.sender,
                    (amountOut - totalSpentTokenAmount)
                );
            }
        }
    }

    function swapTokensForExactAssets(
        BuyOrder[] calldata _buyOrders,
        uint16 _inputSettingsBitFlag,
        uint256 _maxTotalPrice,
        uint256 _amountInMax,
        address _inputERC20,
        uint256 _routerId,
        uint256 _deadline,
        bool _refundInInputTokens
    ) external {
        uint256 totalPrice = _maxTotalPrice;

        IERC20(_inputERC20).safeTransferFrom(
            msg.sender,
            address(this),
            _amountInMax
        );

        // transfer payment tokens to this contract
        uint256[] memory amounts = _swapTokensForExactPaymentTokens(
            totalPrice,
            _amountInMax,
            _inputERC20,
            _routerId,
            _deadline
        );

        // buy items
        uint256 totalSpentTokenAmount = _multiBuyUsingPaymentToken(
            _buyOrders,
            _inputSettingsBitFlag,
            _maxTotalPrice
        );

        // transfer back failed payment tokens to the buyer
        if (totalSpentTokenAmount == 0) {
            if (
                SettingsBitFlag.checkSetting(
                    _inputSettingsBitFlag,
                    SettingsBitFlag.EVERY_BUY_FAILURE
                )
            ) {
                revert("All tokens failed to be bought!");
            } else {
                if (_refundInInputTokens) {
                    // refund in input tokens
                    amounts = _swapExactPaymentTokensForTokens(
                        (totalPrice - totalSpentTokenAmount),
                        0,
                        _inputERC20,
                        _routerId,
                        _deadline
                    );
                    IERC20(_inputERC20).safeTransfer(msg.sender, amounts[1]);
                } else {
                    // refund in payment tokens
                    defaultPaymentToken.safeTransfer(
                        msg.sender,
                        (totalPrice - totalSpentTokenAmount)
                    );
                }
            }
        } else if (totalSpentTokenAmount < totalPrice) {
            if (_refundInInputTokens) {
                // refund in input tokens
                amounts = _swapExactPaymentTokensForTokens(
                    (totalPrice - totalSpentTokenAmount),
                    0,
                    _inputERC20,
                    _routerId,
                    _deadline
                );
                IERC20(_inputERC20).safeTransfer(msg.sender, amounts[1]);
            } else {
                // refund in payment tokens
                defaultPaymentToken.safeTransfer(
                    msg.sender,
                    (totalPrice - totalSpentTokenAmount)
                );
            }
        }
    }

    function sweepUsingExactTokensForAssets(
        BuyOrder[] memory _buyOrders,
        uint16 _inputSettingsBitFlag,
        uint256[] memory _maxSuccessAndFailCounts,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _inputERC20,
        uint256 _routerId,
        uint256 _deadline,
        bool _refundInInputTokens
    ) external {
        IERC20(_inputERC20).safeTransferFrom(
            msg.sender,
            address(this),
            _amountIn
        );

        // transfer payment tokens to this contract
        uint256[] memory amounts = _swapExactTokensForPaymentTokens(
            _amountIn,
            _amountOutMin,
            _inputERC20,
            _routerId,
            _deadline
        );

        // uint256 amountIn = amounts[0];
        uint256 amountOut = amounts[1];

        // buy items
        uint256 totalSpentTokenAmount = _sweepUsingPaymentToken(
            _buyOrders,
            _inputSettingsBitFlag,
            _maxSuccessAndFailCounts,
            amountOut,
            amountOut
        );

        // transfer back failed payment tokens to the buyer
        if (totalSpentTokenAmount == 0) {
            if (
                SettingsBitFlag.checkSetting(
                    _inputSettingsBitFlag,
                    SettingsBitFlag.EVERY_BUY_FAILURE
                )
            ) {
                revert("All tokens failed to be bought!");
            } else {
                if (_refundInInputTokens) {
                    // refund in input tokens
                    amounts = _swapExactPaymentTokensForTokens(
                        (amountOut),
                        0,
                        _inputERC20,
                        _routerId,
                        _deadline
                    );
                    IERC20(_inputERC20).safeTransfer(msg.sender, amounts[1]);
                } else {
                    // refund in payment tokens
                    defaultPaymentToken.safeTransfer(msg.sender, (amountOut));
                }
            }
        } else if (totalSpentTokenAmount < amountOut) {
            if (_refundInInputTokens) {
                // refund in input tokens
                amounts = _swapExactPaymentTokensForTokens(
                    (amountOut - totalSpentTokenAmount),
                    0,
                    _inputERC20,
                    _routerId,
                    _deadline
                );
                IERC20(_inputERC20).safeTransfer(msg.sender, amounts[1]);
            } else {
                // refund in payment tokens
                defaultPaymentToken.safeTransfer(
                    msg.sender,
                    (amountOut - totalSpentTokenAmount)
                );
            }
        }
    }

    // fallback
    fallback() external payable {
        // revert("Fallback: reverting...");
    }

    receive() external payable {
        // revert("Receive: reverting...");
    }
}
