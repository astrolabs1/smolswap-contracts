// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

enum SwapType {
  SWAP_ETH_TO_EXACT_TOKEN,
  SWAP_TOKEN_TO_EXACT_ETH,
  SWAP_TOKEN_TO_EXACT_TOKEN
}

struct Swap {
  // address inputTokenAddress;
  uint256 maxInputTokenAmount;
  uint256 maxSpendIncFees;
  address paymentToken;
  address[] path;
  SwapType swapType;
  IUniswapV2Router02 router;
  uint64 deadline;
}
