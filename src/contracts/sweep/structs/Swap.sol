// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

enum SwapType {
  NO_SWAP, // no swapping and use amountOut as amount inputted
  SWAP_ETH_TO_EXACT_TOKENS,
  SWAP_TOKENS_TO_EXACT_ETH,
  SWAP_TOKENS_TO_EXACT_TOKENS,
  SWAP_EXACT_ETH_TO_TOKENS,
  SWAP_EXACT_TOKENS_TO_ETH,
  SWAP_EXACT_TOKENS_TO_TOKENS
}

enum SwapRouterType {
  UNISWAP_V2,
  UNISWAP_V3
}

struct Swap {
  uint256 amountIn;
  uint256 amountOut;
  address router;
  SwapType swapType;
  address[] path;
  uint64 deadline;
}
