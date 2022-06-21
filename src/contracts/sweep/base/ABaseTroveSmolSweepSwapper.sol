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
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../../token/ANFTReceiver.sol";
import "../libraries/SettingsBitFlag.sol";
import "../libraries/Math.sol";
import "../../treasure/interfaces/ITroveMarketplace.sol";

import "../base/ABaseTroveSmolSweeper.sol";
import "../base/ABaseSwapper.sol";
import "../interfaces/ITroveSmolSweepSwapper.sol";

import "../libraries/ArrayUtils.sol";

struct Swap {
    address inputTokenAddress;
    uint256 maxInputTokenAmount;
    address[] path;
    IUniswapV2Router02 router;
    uint64 deadline;
}

// ITroveSmolSweepSwapper,
contract ABaseTroveSmolSweepSwapper is ABaseTroveSmolSweeper, ABaseSwapper {
    using SafeERC20 for IERC20;
    using SettingsBitFlag for uint16;
    using MemoryArrayUtilsForAddress for address[];

    constructor(
        address _troveMarketplace,
        address _defaultPaymentToken,
        address _weth,
        IUniswapV2Router02[] memory _swapRouters
    )
        ABaseTroveSmolSweeper(_troveMarketplace, _defaultPaymentToken, _weth)
        ABaseSwapper(_swapRouters)
    {}

    function buyUsingOtherToken(
        BuyItemParams[] calldata _buyOrders,
        uint16 _inputSettingsBitFlag,
        address _inputTokenAddress,
        uint256 _maxInputTokenAmount,
        address[] calldata _path,
        uint16 _routerId,
        uint64 _deadline
    ) external {
        IUniswapV2Router02 router = swapRouters[_routerId];
        uint256 maxSpendIncFees;
        {
            IERC20(_path[0]).safeTransferFrom(
                msg.sender,
                address(this),
                _maxInputTokenAmount
            );

            IERC20(_path[0]).approve(address(router), _maxInputTokenAmount);
            uint256[] memory amountsIn = router.swapExactTokensForTokens(
                _maxInputTokenAmount,
                0,
                _path,
                address(this),
                _deadline
            );
            maxSpendIncFees = amountsIn[amountsIn.length - 1];
            IERC20(_inputTokenAddress).approve(
                address(troveMarketplace),
                maxSpendIncFees
            );
        }
        (uint256 totalSpentAmount, uint256 successCount) = _buyItemsSingleToken(
            _buyOrders,
            _inputSettingsBitFlag,
            _calculateAmountWithoutFees(maxSpendIncFees)
        );

        // transfer back failed payment tokens to the buyer
        if (successCount == 0) revert AllReverted();

        uint256 feeAmount = _calculateFee(totalSpentAmount);
        uint256 refundAmount = maxSpendIncFees - (totalSpentAmount + feeAmount);
        if (
            _inputSettingsBitFlag.checkSetting(
                SettingsBitFlag.REFUND_IN_INPUT_TOKEN
            )
        ) {
            address[] memory reversePath = _path.reverse();
            IERC20(defaultPaymentToken).approve(address(router), refundAmount);
            uint256[] memory amounts = router.swapExactTokensForTokens(
                refundAmount,
                0,
                reversePath,
                address(this),
                _deadline
            );
            payable(msg.sender).transfer(amounts[amounts.length - 1]);
        } else {
            defaultPaymentToken.safeTransfer(
                msg.sender,
                maxSpendIncFees - (totalSpentAmount + feeAmount)
            );
        }
    }

    function buyUsingOtherTokenMultiTokens(
        BuyItemParams[] calldata _buyOrders,
        uint16 _inputSettingsBitFlag,
        Swap[] calldata _swaps
    ) external {
        uint256[] memory maxSpendIncFees = new uint256[](_swaps.length);
        {
            for (uint256 i = 0; i < _swaps.length; i++) {
                IERC20(_swaps[i].inputTokenAddress).approve(
                    address(_swaps[i].router),
                    _swaps[i].maxInputTokenAmount
                );
                uint256[] memory amountsIn = _swaps[i]
                    .router
                    .swapExactTokensForTokens(
                        _swaps[i].maxInputTokenAmount,
                        0,
                        _swaps[i].path,
                        address(this),
                        _swaps[i].deadline
                    );
                maxSpendIncFees[i] = amountsIn[amountsIn.length - 1];
            }
        }
        uint256[] memory totalSpentAmounts;
        {
            uint256[] memory maxSpends = _maxSpendWithoutFees(maxSpendIncFees);
            address[] memory inputTokens = new address[](_swaps.length);
            for (uint256 i = 0; i < _swaps.length; i++) {
                inputTokens[i] = _swaps[i].inputTokenAddress;
            }
            (
                uint256[] memory totalSpentAmounts2,
                uint256 successCount
            ) = _buyItemsManyTokens(
                    _buyOrders,
                    _inputSettingsBitFlag,
                    inputTokens,
                    maxSpends
                );
            totalSpentAmounts = totalSpentAmounts2;
            // transfer back failed payment tokens to the buyer
            if (successCount == 0) revert AllReverted();
        }

        for (uint256 i = 0; i < _swaps.length; i++) {
            uint256 feeAmount = _calculateFee(totalSpentAmounts[i]);
            uint256 refundAmount = maxSpendIncFees[i] -
                (totalSpentAmounts[i] + feeAmount);
            if (
                _inputSettingsBitFlag.checkSetting(
                    SettingsBitFlag.REFUND_IN_INPUT_TOKEN
                )
            ) {
                address[] memory reversePath = _swaps[i].path.reverse();
                IERC20(_swaps[i].inputTokenAddress).approve(
                    address(_swaps[i].router),
                    refundAmount
                );
                uint256[] memory amounts = _swaps[i]
                    .router
                    .swapExactTokensForTokens(
                        refundAmount,
                        0,
                        reversePath,
                        address(this),
                        _swaps[i].deadline
                    );
                payable(msg.sender).transfer(amounts[amounts.length - 1]);
            } else {
                IERC20(_swaps[i].inputTokenAddress).safeTransfer(
                    msg.sender,
                    maxSpendIncFees[i] - (totalSpentAmounts[i] + feeAmount)
                );
            }
        }
    }

    function sweepUsingOtherToken(
        BuyItemParams[] memory _buyOrders,
        uint16 _inputSettingsBitFlag,
        address _inputTokenAddress,
        uint32 _maxSuccesses,
        uint32 _maxFailures,
        uint256 _maxInputTokenAmount,
        uint256 _minSpend,
        address[] memory _path,
        uint16 _routerId,
        uint64 _deadline
    ) external {
        IUniswapV2Router02 router = swapRouters[_routerId];
        uint256 maxSpendIncFees;
        {
            IERC20(_path[0]).safeTransferFrom(
                msg.sender,
                address(this),
                _maxInputTokenAmount
            );
            IERC20(_path[0]).approve(address(router), _maxInputTokenAmount);

            uint256[] memory amountsIn = router.swapExactTokensForTokens(
                _maxInputTokenAmount,
                0,
                _path,
                address(this),
                _deadline
            );
            maxSpendIncFees = amountsIn[amountsIn.length - 1];
            IERC20(_inputTokenAddress).approve(
                address(troveMarketplace),
                maxSpendIncFees
            );
        }
        (
            uint256 totalSpentAmount,
            uint256 successCount,

        ) = _sweepItemsSingleToken(
                _buyOrders,
                _inputSettingsBitFlag,
                _calculateAmountWithoutFees(maxSpendIncFees),
                _minSpend,
                _maxSuccesses,
                _maxFailures
            );

        // transfer back failed payment tokens to the buyer
        if (successCount == 0) revert AllReverted();

        if (
            _inputSettingsBitFlag.checkSetting(
                SettingsBitFlag.REFUND_IN_INPUT_TOKEN
            )
        ) {
            uint256 refundAmount = maxSpendIncFees -
                (totalSpentAmount + _calculateFee(totalSpentAmount));
            address[] memory reversePath = _path.reverse();
            IERC20(defaultPaymentToken).approve(address(router), refundAmount);
            uint256[] memory amounts = router.swapExactTokensForTokens(
                refundAmount,
                0,
                reversePath,
                address(this),
                _deadline
            );
            payable(msg.sender).transfer(amounts[amounts.length - 1]);
        } else {
            defaultPaymentToken.safeTransfer(
                msg.sender,
                maxSpendIncFees -
                    (totalSpentAmount + _calculateFee(totalSpentAmount))
            );
        }
    }

    function sweepUsingOtherToken(
        BuyItemParams[] memory _buyOrders,
        uint16 _inputSettingsBitFlag,
        uint256[] memory _minSpends,
        uint32 _maxSuccesses,
        uint32 _maxFailures,
        Swap[] calldata _swaps
    ) external {
        uint256[] memory maxSpendIncFees = new uint256[](_swaps.length);
        {
            for (uint256 i = 0; i < _swaps.length; i++) {
                IERC20(_swaps[i].path[0]).safeTransferFrom(
                    msg.sender,
                    address(this),
                    _swaps[i].maxInputTokenAmount
                );
                IERC20(_swaps[i].inputTokenAddress).approve(
                    address(_swaps[i].router),
                    _swaps[i].maxInputTokenAmount
                );
                uint256[] memory amountsIn = _swaps[i]
                    .router
                    .swapExactTokensForTokens(
                        _swaps[i].maxInputTokenAmount,
                        0,
                        _swaps[i].path,
                        address(this),
                        _swaps[i].deadline
                    );
                maxSpendIncFees[i] = amountsIn[amountsIn.length - 1];
            }
        }
        uint256[] memory totalSpentAmounts;
        {
            uint256[] memory maxSpends = _maxSpendWithoutFees(maxSpendIncFees);
            address[] memory inputTokens = new address[](_swaps.length);
            for (uint256 i = 0; i < _swaps.length; i++) {
                inputTokens[i] = _swaps[i].inputTokenAddress;
            }
            (
                uint256[] memory totalSpentAmounts2,
                uint256 successCount,

            ) = _sweepItemsManyTokens(
                    _buyOrders,
                    _inputSettingsBitFlag,
                    inputTokens,
                    maxSpends,
                    _minSpends,
                    _maxSuccesses,
                    _maxFailures
                );
            totalSpentAmounts = totalSpentAmounts2;
            // transfer back failed payment tokens to the buyer
            if (successCount == 0) revert AllReverted();
        }
        for (uint256 i = 0; i < _swaps.length; i++) {
            uint256 feeAmount = _calculateFee(totalSpentAmounts[i]);
            uint256 refundAmount = maxSpendIncFees[i] -
                (totalSpentAmounts[i] + feeAmount);
            if (
                _inputSettingsBitFlag.checkSetting(
                    SettingsBitFlag.REFUND_IN_INPUT_TOKEN
                )
            ) {
                address[] memory reversePath = _swaps[i].path.reverse();
                IERC20(_swaps[i].inputTokenAddress).approve(
                    address(_swaps[i].router),
                    refundAmount
                );
                uint256[] memory amounts = _swaps[i]
                    .router
                    .swapExactTokensForTokens(
                        refundAmount,
                        0,
                        reversePath,
                        address(this),
                        _swaps[i].deadline
                    );
                payable(msg.sender).transfer(amounts[amounts.length - 1]);
            } else {
                IERC20(_swaps[i].inputTokenAddress).safeTransfer(
                    msg.sender,
                    maxSpendIncFees[i] - (totalSpentAmounts[i] + feeAmount)
                );
            }
        }
    }
}
