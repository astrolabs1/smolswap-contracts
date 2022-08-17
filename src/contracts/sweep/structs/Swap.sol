// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

enum SwapType {
  NO_SWAP,
  SWAP_ETH_TO_EXACT_TOKEN,
  SWAP_TOKEN_TO_EXACT_ETH,
  SWAP_TOKEN_TO_EXACT_TOKEN
}

struct Swap {
  uint256 amountIn;
  uint256 amountOut;
  IUniswapV2Router02 router;
  SwapType swapType;
  address[] path;
  uint64 deadline;
}
