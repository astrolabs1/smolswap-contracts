// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../../token/ANFTReceiver.sol";
import "../libraries/SettingsBitFlag.sol";
import "../libraries/Math.sol";
import "../structs/BuyOrder.sol";
import "./ABaseSmolSweeper.sol";
import "../interfaces/ITreasureTroveSmolSweeper.sol";
import "../../treasure/interfaces/ITreasureMarketplace.sol";
import "../../treasure/interfaces/ITroveMarketplace.sol";
import "../interfaces/ITroveSmolSweeper.sol";

error InvalidMsgValue();
error MsgValueShouldBeZero();

abstract contract ABaseTreasureTroveSmolSweeper is
    ReentrancyGuard,
    ABaseSmolSweeper,
    ITreasureTroveSmolSweeper
{
    using SafeERC20 for IERC20;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    IERC20 public defaultPaymentToken;
    ITreasureMarketplace public treasureMarketplace;
    ITroveMarketplace public troveMarketplace;

    constructor(
        address _treasureMarketplace,
        address _troveMarketplace,
        address _defaultPaymentToken
    ) {
        treasureMarketplace = ITreasureMarketplace(_treasureMarketplace);
        defaultPaymentToken = IERC20(_defaultPaymentToken);

        _approveERC20TokenToContract(
            IERC20(_defaultPaymentToken),
            _treasureMarketplace,
            type(uint256).max
        );

        troveMarketplace = ITroveMarketplace(_troveMarketplace);
    }

    function setTreasureMarketplace(ITreasureMarketplace _treasureMarketplace)
        external
        onlyOwner
    {
        treasureMarketplace = _treasureMarketplace;
    }

    function setTroveMarketplace(ITroveMarketplace _troveMarketplace)
        external
        onlyOwner
    {
        troveMarketplace = _troveMarketplace;
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
    {
        _approveERC20TokenToContract(
            defaultPaymentToken,
            address(treasureMarketplace),
            type(uint256).max
        );
    }

    function tryBuyItemTreasure(
        BuyItemParams memory _buyOrder,
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
        ITreasureMarketplace.Listing memory listing = treasureMarketplace
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
            return (0, false, SettingsBitFlag.EXCEEDING_MAX_SPEND);
        }

        uint256 totalSpent = 0;
        try
            treasureMarketplace.buyItem(
                _buyOrder.nftAddress,
                _buyOrder.tokenId,
                _buyOrder.owner,
                uint64(quantityToBuy),
                uint128(_buyOrder.maxPricePerItem)
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
                    INTERFACE_ID_ERC721
                )
            ) {
                IERC721(_buyOrder.nftAddress).safeTransferFrom(
                    address(this),
                    msg.sender,
                    _buyOrder.tokenId
                );
            } else if (
                IERC165(_buyOrder.nftAddress).supportsInterface(
                    INTERFACE_ID_ERC1155
                )
            ) {
                IERC1155(_buyOrder.nftAddress).safeTransferFrom(
                    address(this),
                    msg.sender,
                    _buyOrder.tokenId,
                    quantityToBuy,
                    bytes("")
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
            return (0, false, SettingsBitFlag.MARKETPLACE_BUY_ITEM_REVERTED);
        }

        return (totalSpent, true, SettingsBitFlag.NONE);
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
            uint16 failReason
        )
    {
        uint256 quantityToBuy = _buyOrder.quantity;
        // check if the listing exists
        ITroveMarketplace.ListingOrBid memory listing = troveMarketplace
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
            return (0, false, SettingsBitFlag.EXCEEDING_MAX_SPEND);
        }

        BuyItemParams[] memory buyItemParams = new BuyItemParams[](1);
        buyItemParams[0] = _buyOrder;
        // if (
        //     _buyOrder.paymentToken != address(0) ||
        //     _buyOrder.paymentToken != address(defaultPaymentToken)
        // ) {
        //     IERC20(_buyOrder.paymentToken).approve(
        //         address(troveMarketplace),
        //         _buyOrder.maxPricePerItem
        //     );
        // }
        uint256 totalSpent = 0;
        uint256 value = (_buyOrder.paymentToken == address(0))
            ? (_buyOrder.maxPricePerItem * quantityToBuy)
            : 0;

        try troveMarketplace.buyItems{value: value}(buyItemParams) {
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
                    INTERFACE_ID_ERC721
                )
            ) {
                IERC721(_buyOrder.nftAddress).safeTransferFrom(
                    address(this),
                    msg.sender,
                    _buyOrder.tokenId
                );
            } else if (
                IERC165(_buyOrder.nftAddress).supportsInterface(
                    INTERFACE_ID_ERC1155
                )
            ) {
                IERC1155(_buyOrder.nftAddress).safeTransferFrom(
                    address(this),
                    msg.sender,
                    _buyOrder.tokenId,
                    quantityToBuy,
                    bytes("")
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
            return (0, false, SettingsBitFlag.MARKETPLACE_BUY_ITEM_REVERTED);
        }

        return (totalSpent, true, SettingsBitFlag.NONE);
    }

    function buyTreasure(
        BuyItemParams[] memory _buyOrders,
        uint16 _inputSettingsBitFlag,
        uint256 _maxSpendIncFees
    ) external nonReentrant {
        // transfer payment tokens to this contract
        defaultPaymentToken.safeTransferFrom(
            msg.sender,
            address(this),
            _maxSpendIncFees
        );

        (uint256 totalSpentAmount, uint256 successCount) = _buyTreasure(
            _buyOrders,
            _inputSettingsBitFlag,
            _calculateAmountWithoutFees(_maxSpendIncFees)
        );

        // transfer back failed payment tokens to the buyer
        if (successCount == 0) revert AllReverted();

        uint256 feeAmount = _calculateFee(totalSpentAmount);
        defaultPaymentToken.safeTransfer(
            msg.sender,
            _maxSpendIncFees - (totalSpentAmount + feeAmount)
        );
    }

    function _buyTreasure(
        BuyItemParams[] memory _buyOrders,
        uint16 _inputSettingsBitFlag,
        uint256 _maxSpendIncFees
    ) internal returns (uint256 totalSpentAmount, uint256 successCount) {
        // buy all assets
        for (uint256 i = 0; i < _buyOrders.length; i++) {
            (
                uint256 spentAmount,
                bool spentSuccess,
                uint16 spentError
            ) = tryBuyItemTreasure(
                    _buyOrders[i],
                    _inputSettingsBitFlag,
                    _maxSpendIncFees - totalSpentAmount
                );

            if (spentSuccess) {
                totalSpentAmount += spentAmount;
                successCount++;
            } else {
                if (
                    spentError ==
                    SettingsBitFlag.EXCEEDING_MAX_SPEND &&
                    SettingsBitFlag.checkSetting(
                        _inputSettingsBitFlag,
                        SettingsBitFlag.EXCEEDING_MAX_SPEND
                    )
                ) break;
            }
        }
    }

    function sweepTreasure(
        BuyItemParams[] memory _buyOrders,
        uint16 _inputSettingsBitFlag,
        uint256 _maxSuccesses,
        uint256 _maxFailures,
        uint256 _maxSpendIncFees,
        uint256 _minSpend
    ) external nonReentrant {
        // transfer payment tokens to this contract
        defaultPaymentToken.safeTransferFrom(
            msg.sender,
            address(this),
            _maxSpendIncFees
        );

        (uint256 totalSpentAmount, uint256 successCount) = _sweepTreasure(
            _buyOrders,
            _inputSettingsBitFlag,
            _maxSuccesses,
            _maxFailures,
            _calculateAmountWithoutFees(_maxSpendIncFees),
            _minSpend
        );

        // transfer back failed payment tokens to the buyer
        if (successCount == 0) revert AllReverted();

        uint256 feeAmount = _calculateFee(totalSpentAmount);
        defaultPaymentToken.safeTransfer(
            msg.sender,
            _maxSpendIncFees - (totalSpentAmount + feeAmount)
        );
    }

    function _sweepTreasure(
        BuyItemParams[] memory _buyOrders,
        uint16 _inputSettingsBitFlag,
        uint256 _maxSuccesses,
        uint256 _maxFailures,
        uint256 _maxSpendIncFees,
        uint256 _minSpend
    ) internal returns (uint256 totalSpentAmount, uint256 successCount) {
        // buy all assets
        uint256 failCount = 0;
        for (uint256 i = 0; i < _buyOrders.length; i++) {
            if (successCount >= _maxSuccesses || failCount >= _maxFailures)
                break;

            if (totalSpentAmount >= _minSpend) break;

            (
                uint256 spentAmount,
                bool spentSuccess,
                uint16 spentError
            ) = tryBuyItemTreasure(
                    _buyOrders[i],
                    _inputSettingsBitFlag,
                    _maxSpendIncFees - totalSpentAmount
                );

            if (spentSuccess) {
                totalSpentAmount += spentAmount;
                successCount++;
            } else {
                if (
                    spentError ==
                    SettingsBitFlag.EXCEEDING_MAX_SPEND &&
                    SettingsBitFlag.checkSetting(
                        _inputSettingsBitFlag,
                        SettingsBitFlag.EXCEEDING_MAX_SPEND
                    )
                ) break;
                failCount++;
            }
        }
    }

    function buyItemsSingleToken(
        BuyItemParams[] calldata _buyOrders,
        Marketplace[] calldata _marketplaces,
        uint16 _inputSettingsBitFlag,
        address _inputTokenAddress,
        uint256 _maxSpendIncFees
    ) external payable {
        if (_inputTokenAddress == address(0)) {
            if (_maxSpendIncFees != msg.value) revert InvalidMsgValue();
        } else {
            if (msg.value != 0) revert MsgValueShouldBeZero();
            // transfer payment tokens to this contract
            IERC20(_inputTokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _maxSpendIncFees
            );
            IERC20(_inputTokenAddress).approve(
                address(troveMarketplace),
                _maxSpendIncFees
            );
        }

        (uint256 totalSpentAmount, uint256 successCount) = _buyItemsSingleToken(
            _buyOrders,
            _marketplaces,
            _inputSettingsBitFlag,
            _maxSpendIncFees
        );

        // transfer back failed payment tokens to the buyer
        if (successCount == 0) revert AllReverted();

        uint256 feeAmount = _calculateFee(totalSpentAmount);

        if (_inputTokenAddress == address(0)) {
            payable(msg.sender).transfer(
                _maxSpendIncFees - (totalSpentAmount + feeAmount)
            );
        } else {
            IERC20(_inputTokenAddress).safeTransfer(
                msg.sender,
                _maxSpendIncFees - (totalSpentAmount + feeAmount)
            );
        }
    }

    function _buyItemsSingleToken(
        BuyItemParams[] memory _buyOrders,
        Marketplace[] memory _marketplaces,
        uint16 _inputSettingsBitFlag,
        uint256 _maxSpendIncFees
    ) internal returns (uint256 totalSpentAmount, uint256 successCount) {
        // buy all assets
        uint256 _maxSpendIncFees = _calculateAmountWithoutFees(
            _maxSpendIncFees
        );

        uint256 i = 0;
        uint256 length = _buyOrders.length;
        for (; i < length; ) {
            (
                uint256 spentAmount,
                bool spentSuccess,
                uint16 spentError
            ) = tryBuyItemTrove(
                    _buyOrders[i],
                    _inputSettingsBitFlag,
                    _maxSpendIncFees - totalSpentAmount
                );

            if (spentSuccess) {
                totalSpentAmount += spentAmount;
                successCount++;
            } else {
                if (
                    spentError ==
                    SettingsBitFlag.EXCEEDING_MAX_SPEND &&
                    SettingsBitFlag.checkSetting(
                        _inputSettingsBitFlag,
                        SettingsBitFlag.EXCEEDING_MAX_SPEND
                    )
                ) break;
            }

            unchecked {
                ++i;
            }
        }
    }

    function buyItemsMultiTokens(
        BuyItemParams[] calldata _buyOrders,
        Marketplace[] calldata _marketplaces,
        uint16 _inputSettingsBitFlag,
        address[] calldata _inputTokenAddresses,
        uint256[] calldata _maxSpendIncFees
    ) external payable {
        // transfer payment tokens to this contract
        uint256 i = 0;
        uint256 length = _inputTokenAddresses.length;
        for (; i < length; ) {
            if (_inputTokenAddresses[i] == address(0)) {
                if (_maxSpendIncFees[i] != msg.value) revert InvalidMsgValue();
            } else {
                if (msg.value != 0) revert MsgValueShouldBeZero();
                // transfer payment tokens to this contract
                IERC20(_inputTokenAddresses[i]).safeTransferFrom(
                    msg.sender,
                    address(this),
                    _maxSpendIncFees[i]
                );
                IERC20(_inputTokenAddresses[i]).approve(
                    address(troveMarketplace),
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
                _marketplaces,
                _inputSettingsBitFlag,
                _inputTokenAddresses,
                maxSpends
            );

        // transfer back failed payment tokens to the buyer
        if (successCount == 0) revert AllReverted();

        i = 0;
        for (; i < length; ) {
            uint256 feeAmount = _calculateFee(totalSpentAmount[i]);

            if (_inputTokenAddresses[i] == address(0)) {
                payable(msg.sender).transfer(
                    _maxSpendIncFees[i] - (totalSpentAmount[i] + feeAmount)
                );
            } else {
                IERC20(_inputTokenAddresses[i]).safeTransfer(
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
        Marketplace[] calldata _marketplaces,
        uint16 _inputSettingsBitFlag,
        address[] memory _inputTokenAddresses,
        uint256[] memory _maxSpends
    )
        internal
        returns (uint256[] memory totalSpentAmounts, uint256 successCount)
    {
        totalSpentAmounts = new uint256[](_inputTokenAddresses.length);
        // buy all assets
        for (uint256 i = 0; i < _buyOrders.length; ) {
            uint256 j = _getTokenIndex(
                _inputTokenAddresses,
                _buyOrders[i].paymentToken
            );
            (
                uint256 spentAmount,
                bool spentSuccess,
                uint16 spentError
            ) = tryBuyItemTrove(
                    _buyOrders[i],
                    _inputSettingsBitFlag,
                    _maxSpends[j] - totalSpentAmounts[j]
                );

            if (spentSuccess) {
                totalSpentAmounts[j] += spentAmount;
                successCount++;
            } else {
                if (
                    spentError ==
                    SettingsBitFlag.EXCEEDING_MAX_SPEND &&
                    SettingsBitFlag.checkSetting(
                        _inputSettingsBitFlag,
                        SettingsBitFlag.EXCEEDING_MAX_SPEND
                    )
                ) break;
            }
            unchecked {
                ++i;
            }
        }
    }

    // function sweepItemsSingleToken(
    //     BuyItemParams[] calldata _buyOrders,
    //     Marketplace[] calldata _marketplaces,
    //     uint16 _inputSettingsBitFlag,
    //     address _inputTokenAddress,
    //     uint256 _maxSpendIncFees,
    //     uint256 _minSpend,
    //     uint32 _maxSuccesses,
    //     uint32 _maxFailures
    // ) external payable {
    //     if (_inputTokenAddress == address(0)) {
    //         if (_maxSpendIncFees != msg.value) revert InvalidMsgValue();
    //     } else {
    //         if (msg.value != 0) revert MsgValueShouldBeZero();
    //         // transfer payment tokens to this contract
    //         IERC20(_inputTokenAddress).safeTransferFrom(
    //             msg.sender,
    //             address(this),
    //             _maxSpendIncFees
    //         );
    //         IERC20(_inputTokenAddress).approve(
    //             address(troveMarketplace),
    //             _maxSpendIncFees
    //         );
    //     }

    //     (
    //         uint256 totalSpentAmount,
    //         uint256 successCount,

    //     ) = _sweepItemsSingleToken(
    //             _buyOrders,
    //             _marketplaces,
    //             _inputSettingsBitFlag,
    //             _maxSpendIncFees,
    //             _minSpend,
    //             _maxSuccesses,
    //             _maxFailures
    //         );

    //     // transfer back failed payment tokens to the buyer
    //     if (successCount == 0) revert AllReverted();

    //     uint256 feeAmount = _calculateFee(totalSpentAmount);
    //     if (_inputTokenAddress == address(0)) {
    //         payable(msg.sender).transfer(
    //             _maxSpendIncFees - (totalSpentAmount + feeAmount)
    //         );
    //     } else {
    //         IERC20(_inputTokenAddress).safeTransfer(
    //             msg.sender,
    //             _maxSpendIncFees - (totalSpentAmount + feeAmount)
    //         );
    //     }
    // }

    // function _sweepItemsSingleToken(
    //     BuyItemParams[] memory _buyOrders,
    //     Marketplace[] calldata _marketplaces,
    //     uint16 _inputSettingsBitFlag,
    //     uint256 _maxSpendIncFees,
    //     uint256 _minSpend,
    //     uint32 _maxSuccesses,
    //     uint32 _maxFailures
    // )
    //     internal
    //     returns (
    //         uint256 totalSpentAmount,
    //         uint256 successCount,
    //         uint256 failCount
    //     )
    // {
    //     // buy all assets
    //     for (uint256 i = 0; i < _buyOrders.length; i++) {
    //         if (successCount >= _maxSuccesses || failCount >= _maxFailures)
    //             break;

    //         if (totalSpentAmount >= _minSpend) break;

    //         (
    //             uint256 spentAmount,
    //             bool spentSuccess,
    //             uint16 spentError
    //         ) = tryBuyItemTrove(
    //                 _buyOrders[i],
    //                 _inputSettingsBitFlag,
    //                 _maxSpendIncFees - totalSpentAmount
    //             );

    //         if (spentSuccess) {
    //             totalSpentAmount += spentAmount;
    //             successCount++;
    //         } else {
    //             if (
    //                 spentError ==
    //                 SettingsBitFlag.EXCEEDING_MAX_SPEND &&
    //                 SettingsBitFlag.checkSetting(
    //                     _inputSettingsBitFlag,
    //                     SettingsBitFlag.EXCEEDING_MAX_SPEND
    //                 )
    //             ) break;
    //             failCount++;
    //         }
    //     }
    // }

    // function _before(
    //     Marketplace[] calldata _marketplaces,
    //     address[] calldata _inputTokenAddresses,
    //     uint256[] calldata _maxSpendIncFees
    // ) internal {
    //     for (uint256 i = 0; i < _maxSpendIncFees.length; ) {
    //         if (_inputTokenAddresses[i] == address(0)) {
    //             if (_maxSpendIncFees[i] != msg.value) revert InvalidMsgValue();
    //         } else {
    //             if (msg.value != 0) revert MsgValueShouldBeZero();
    //             // transfer payment tokens to this contract
    //             IERC20(_inputTokenAddresses[i]).safeTransferFrom(
    //                 msg.sender,
    //                 address(this),
    //                 _maxSpendIncFees[i]
    //             );
    //             IERC20(_inputTokenAddresses[i]).approve(
    //                 address(troveMarketplace),
    //                 _maxSpendIncFees[i]
    //             );
    //         }

    //         unchecked {
    //             ++i;
    //         }
    //     }
    // }

    // function sweepItemsMultiTokens(
    //     BuyItemParams[] calldata _buyOrders,
    //     Marketplace[] calldata _marketplaces,
    //     uint16 _inputSettingsBitFlag,
    //     address[] calldata _inputTokenAddresses,
    //     uint256[] calldata _maxSpendIncFees,
    //     uint256[] calldata _minSpends,
    //     uint32 _maxSuccesses,
    //     uint32 _maxFailures
    // ) external payable {
    //     // transfer payment tokens to this contract
    //     // for (uint256 i = 0; i < _maxSpendIncFees.length; ) {
    //     //     if (_inputTokenAddresses[i] == address(0)) {
    //     //         if (_maxSpendIncFees[i] != msg.value) revert InvalidMsgValue();
    //     //     } else {
    //     //         if (msg.value != 0) revert MsgValueShouldBeZero();
    //     //         // transfer payment tokens to this contract
    //     //         IERC20(_inputTokenAddresses[i]).safeTransferFrom(
    //     //             msg.sender,
    //     //             address(this),
    //     //             _maxSpendIncFees[i]
    //     //         );
    //     //         IERC20(_inputTokenAddresses[i]).approve(
    //     //             address(troveMarketplace),
    //     //             _maxSpendIncFees[i]
    //     //         );
    //     //     }

    //     //     unchecked {
    //     //         ++i;
    //     //     }
    //     // }

    //     _before(_marketplaces, _inputTokenAddresses, _maxSpendIncFees);

    //     uint256[] memory _maxSpendIncFeesAmount = _maxSpendWithoutFees(
    //         _maxSpendIncFees
    //     );

    //     (
    //         uint256[] memory totalSpentAmount,
    //         uint256 successCount,

    //     ) = _sweepItemsMultiTokens(
    //             _buyOrders,
    //             _marketplaces,
    //             _inputSettingsBitFlag,
    //             _inputTokenAddresses,
    //             _maxSpendIncFeesAmount,
    //             _minSpends,
    //             _maxSuccesses,
    //             _maxFailures
    //         );

    //     // transfer back failed payment tokens to the buyer
    //     if (successCount == 0) revert AllReverted();

    //     for (uint256 i = 0; i < _maxSpendIncFees.length; ) {
    //         uint256 feeAmount = _calculateFee(totalSpentAmount[i]);

    //         if (_inputTokenAddresses[i] == address(0)) {
    //             payable(msg.sender).transfer(
    //                 _maxSpendIncFees[i] - (totalSpentAmount[i] + feeAmount)
    //             );
    //         } else {
    //             IERC20(_inputTokenAddresses[i]).safeTransfer(
    //                 msg.sender,
    //                 _maxSpendIncFees[i] - (totalSpentAmount[i] + feeAmount)
    //             );
    //         }

    //         unchecked {
    //             ++i;
    //         }
    //     }
    // }

    // function _sweepItemsMultiTokens(
    //     BuyItemParams[] memory _buyOrders,
    //     Marketplace[] memory _marketplaces,
    //     uint16 _inputSettingsBitFlag,
    //     address[] memory _inputTokenAddresses,
    //     uint256[] memory _maxSpendIncFeesAmount,
    //     uint256[] memory _minSpends,
    //     uint32 _maxSuccesses,
    //     uint32 _maxFailures
    // )
    //     internal
    //     returns (
    //         uint256[] memory totalSpentAmounts,
    //         uint256 successCount,
    //         uint256 failCount
    //     )
    // {
    //     totalSpentAmounts = new uint256[](_inputTokenAddresses.length);

    //     for (uint256 i = 0; i < _buyOrders.length; ) {
    //         // BuyItemParams memory buyItemParam = _buyOrders[i];
    //         if (successCount >= _maxSuccesses || failCount >= _maxFailures)
    //             break;

    //         uint256 j = _getTokenIndex(
    //             _inputTokenAddresses,
    //             _buyOrders[i].nftAddress
    //         );
    //         if (totalSpentAmounts[j] >= _minSpends[i]) break;

    //         uint256 spentAmount;
    //         bool spentSuccess;
    //         uint16 spentError;
    //         if (_marketplaces[i] == Marketplace.TREASURE) {
    //             (spentAmount, spentSuccess, spentError) = tryBuyItemTreasure(
    //                 _buyOrders[i],
    //                 _inputSettingsBitFlag,
    //                 _maxSpendIncFeesAmount[j] - totalSpentAmounts[j]
    //             );
    //         } else if (_marketplaces[i] == Marketplace.TROVE) {
    //             (spentAmount, spentSuccess, spentError) = tryBuyItemTrove(
    //                 _buyOrders[i],
    //                 _inputSettingsBitFlag,
    //                 _maxSpendIncFeesAmount[j] - totalSpentAmounts[j]
    //             );
    //         } else {
    //             (spentAmount, spentSuccess, spentError) = tryBuyItemTrove(
    //                 _buyOrders[i],
    //                 _inputSettingsBitFlag,
    //                 _maxSpendIncFeesAmount[j] - totalSpentAmounts[j]
    //             );
    //         }

    //         if (spentSuccess) {
    //             totalSpentAmounts[j] += spentAmount;
    //             successCount++;
    //         } else {
    //             if (
    //                 spentError ==
    //                 SettingsBitFlag.EXCEEDING_MAX_SPEND &&
    //                 SettingsBitFlag.checkSetting(
    //                     _inputSettingsBitFlag,
    //                     SettingsBitFlag.EXCEEDING_MAX_SPEND
    //                 )
    //             ) break;
    //             failCount++;
    //         }
    //         unchecked {
    //             ++i;
    //         }
    //     }
    // }

    function _maxSpendWithoutFees(uint256[] memory _maxSpendIncFees)
        internal
        view
        returns (uint256[] memory maxSpendIncFeesAmount)
    {
        maxSpendIncFeesAmount = new uint256[](_maxSpendIncFees.length);

        uint256 maxSpendLength = _maxSpendIncFees.length;
        for (uint256 i = 0; i < maxSpendLength; ) {
            maxSpendIncFeesAmount[i] = _calculateAmountWithoutFees(
                _maxSpendIncFees[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    function _getTokenIndex(
        address[] memory _inputTokenAddresses,
        address _buyOrderPaymentToken
    ) internal pure returns (uint256 j) {
        for (; j < _inputTokenAddresses.length; ) {
            if (_inputTokenAddresses[j] == _buyOrderPaymentToken) {
                return j;
            }
            unchecked {
                ++j;
            }
        }
        revert("bad");
    }
}
