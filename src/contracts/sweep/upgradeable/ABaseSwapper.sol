// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";

import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

error UniswapV2Router02NotFound(uint256 _id);

abstract contract ABaseSwapper is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    function calculateMinETHInputForOutputTokens(
        IUniswapV2Router02 _router,
        address[] memory _path,
        uint256 _outputERC20Amount
    ) public view returns (uint256[] memory) {
        return _router.getAmountsIn(_outputERC20Amount, _path);
    }

    function calculateMinTokensInputForOutputTokens(
        IUniswapV2Router02 _router,
        address[] memory _path,
        uint256 _outputERC20Amount
    ) public view returns (uint256[] memory) {
        return _router.getAmountsOut(_outputERC20Amount, _path);
    }
}
