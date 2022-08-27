// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

enum InputType {
  PAYMENT_TOKENS, // no swapping and use amountIn as amount
  SWAP_EXACT_ETH_TO_TOKENS,
  SWAP_EXACT_TOKENS_TO_ETH,
  SWAP_EXACT_TOKENS_TO_TOKENS,
  SWAP_ETH_TO_EXACT_TOKENS,
  SWAP_TOKENS_TO_EXACT_ETH,
  SWAP_TOKENS_TO_EXACT_TOKENS
}

enum SwapRouterType {
  UNISWAP_V2,
  UNISWAP_V3
}

struct InputToken {
  InputType inputType;
  uint256 amountIn;
  uint256 amountOut;
  address router;
  address[] path;
  uint64 deadline;
}
